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
  module Schema
    def gql_mutations
      # TODO: Find better way to detect mutations
      @function_map.reject do |name_sym, _rpc_des|
        name_sym.to_s.start_with?('get') ||
          _rpc_des.rpc_desc.input == Google::Protobuf::Empty
      end
    end

    def gql_queries
      # TODO: Find better way to detect queries
      # Currently look for methods named 'get' or with no args
      @function_map.select do |name_sym, _rpc_des|
        name_sym.to_s.start_with?('get') ||
          _rpc_des.rpc_desc.input == Google::Protobuf::Empty
      end
    end

    def to_schema_types
      function_output_types = @function_map.values.map do |function|
        function.rpc_desc.output
      end.flatten.uniq
      output_types = TypeLibrary.new(function_output_types)
      function_input_types = @function_map.values.map do |function|
        function.rpc_desc.input
      end.flatten.uniq
      input_types = InputTypeLibrary.new(function_input_types)
      input_types.to_schema_types + "\nscalar Url\n" + output_types.to_schema_types
    end

    def to_function_types(ggg_function_hash)
      ggg_function_hash.values.sort_by(&:name).map(&:to_query_type).join("\n  ")
    end

    def to_schema_query
      "type Query {
  #{to_function_types(gql_queries)}
  }"
    end

    def to_schema_mutations
      return '' if gql_mutations.empty?

      "type Mutation {
  #{to_function_types(gql_mutations)}
  }"
    end

    def to_gql_schema
      <<EOF
  #{to_schema_types}
  #{to_schema_query}
  #{to_schema_mutations}
  schema {
  query: Query
  #{gql_mutations.empty? ? '' : 'mutation: Mutation'}
  }
EOF
    end
  end
end