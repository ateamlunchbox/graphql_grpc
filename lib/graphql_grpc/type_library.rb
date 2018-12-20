# MIT License
#
# Copyright (c) 2018, Dane Avilla
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module GraphqlGrpc
  module DescriptorExt
    def <=>(b)
      name <=> b.name
    end

    def types(prefix)
      # Iterate through the Google::Protobuf::FieldDescriptor list
      entries.sort.map { |fd| fd.to_gql_type(prefix) }
    end

    #
    # Return an array of all (recursive) types known within this type
    #
    def sub_types
      # Iterate through the Google::Protobuf::FieldDescriptor list
      entries.map do |fd|
        # fd.name = 'current_entity_to_update'
        # fd.number = 1
        # fd.label = :optional
        # fd.submsg_name = "com.foo.bar.Baz"
        # fd.subtype = #<Google::Protobuf::Descriptor:0x007fabb3947f08>
        if fd.subtype.class == Google::Protobuf::Descriptor
          # There is a subtype; recurse
          [name, fd.submsg_name] + fd.subtype.sub_types
        else
          [name, fd.submsg_name]
        end
      end.flatten.compact
    end

    def type_name
      name.split('::').last.split('.').last
    end

    #
    # Decide whether this is a GraphQL 'type' or 'input'
    #
    def input_or_type(prefix)
      return :input unless prefix.empty?

      :type
    end

    def to_gql_type(prefix = '')
      if entries.any?
      <<EOF
  #{input_or_type(prefix)} #{prefix}#{type_name} {
    #{types(prefix).join("\n  ")}
  }
EOF
      else
        # For now, treat empty types as scalars
        "scalar #{prefix}#{type_name}"
      end
    end
  end

  module FieldDescriptorExt
    def <=>(b)
      name <=> b.name
    end

    def to_gql_type_field(prefix)
      t = case type
          when :int64, :int32, :uint32, :uint64
            'Int'
          when :string
            'String'
          when :bool, :boolean
            'Boolean'
          when :double
            'Float'
          when :message
            prefix + submsg_name.to_s.split('.').last
          when :enum
            # Enums are interesting; for Google::Protobuf::FieldDescriptor fd
            # fd.type        = :enum
            # fd.subtype.    = Google::Protobuf::EnumDescriptor
            # fd.submsg_name = 'com.foo.bar.Baz
            # ed             = fd.subtype
            # ed.entries.    = [[:OUT, 0], [:IN, 1]]
            #
            prefix + submsg_name.to_s.split('.')[-2..-1].join('_')
          else
            type.to_s + '--Unknown'
      end
      return "[#{t}]" if repeated?
      return "#{t}!" unless optional?

      t
    end

    def optional?
      label == :optional
    end

    def repeated?
      label == :repeated
    end

    def to_gql_type(prefix)
      "#{name}: #{to_gql_type_field(prefix)}"
    end
  end

  module EnumDescriptorExt
    def type_name
      # Take the last 2
      name.split('.')[-2..-1].join('_')
    end

    def to_gql_type(prefix)
      "enum #{prefix}#{type_name} {
  #{entries.map(&:first).join("\n  ")}
}"
    end
  end
end

require 'google/protobuf'
Google::Protobuf::Descriptor.include(GraphqlGrpc::DescriptorExt)
Google::Protobuf::FieldDescriptor.include(GraphqlGrpc::FieldDescriptorExt)
Google::Protobuf::EnumDescriptor.include(GraphqlGrpc::EnumDescriptorExt)

module GraphqlGrpc
  class TypeLibrary
    def initialize(top_level_types)
      build_descriptors(top_level_types)
    end

    def build_descriptors(some_types)
      # Keep track of known types to avoid infinite loops when there
      # are circular dependencies between gRPC types
      @descriptors ||= {}
      some_types.each do |java_class_name|
        next unless @descriptors[java_class_name].nil?

        # Store a reference to this type
        descriptor = descriptor_for(java_class_name)
        @descriptors[java_class_name] ||= descriptor
        # Recurse
        build_descriptors(descriptor.sub_types) if descriptor.respond_to?(:sub_types)
      end
    end

    #
    # generated_klass - a class created by the 'proto' compiler; maps
    # to a Descriptor in the generated pool.
    #
    def self.descriptor_for(klass_str)
      klass_str = klass_str.to_s
      # If given a ruby class reference, convert to "java package" string
      # Pull the Google::Protobuf::Descriptor out of the pool and return it
      # with the name
      Google::Protobuf::DescriptorPool.generated_pool.lookup(
        ruby_class_to_underscore(klass_str)
      ) || Google::Protobuf::DescriptorPool.generated_pool.lookup(
        ruby_class_to_dotted(klass_str)
      )
    end

    def self.ruby_class_to_underscore(klass_str)
      if klass_str.to_s.include?('::')
       java_name = klass_str.to_s.split('::')
       camel_case = java_name.pop
       java_package = java_name.map(&:underscore)
       # Put the name back together
       (java_package + [camel_case]).join('.')
     else
       klass_str
      end
    end

    def self.ruby_class_to_dotted(klass_str)
      klass_str.gsub('::', '.')
    end

    def descriptor_for(klass_str)
      TypeLibrary.descriptor_for(klass_str)
    end

    def types
      @descriptors
    end

    def type_prefix
      ''
    end

    def to_schema_types
      @descriptors.values.map do |t|
        t.to_gql_type(type_prefix)
      end.compact.sort.uniq.join("\n")
    end
  end

  class InputTypeLibrary < TypeLibrary
    PREFIX = 'i_'.freeze
    def type_prefix
      PREFIX
    end

    def build_descriptors(some_types)
      super
      # Edge case: remove any input types with empty sub_types, such
      # as is the case when a google.protobuf.Empty object is declared
      # as the argument for a gRPC call that is being mapped to a
      # GraphQL query.
      @descriptors.delete_if do |_key, descriptor|
        if descriptor.name.start_with?('google.protobuf') &&
           descriptor.respond_to?(:sub_types) &&
           descriptor.sub_types.empty?
          true
        else
          false
        end
      end
    end
  end
end
