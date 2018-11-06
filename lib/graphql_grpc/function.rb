# MIT License
#
# Copyright (c) 2018, Zane Claes
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

require 'graphql'

#
# Hmm...override the InputObject definition so it actually
# can be turned into JSON vs. a String with:
# "#<GraphQL::Language::Nodes::InputObject:0x007fc1e140d9b8>"
#
::GraphQL::Language::Nodes::InputObject.class_eval do
  def to_json(*args)
    to_h.to_json(*args)
  end
end

module GraphqlGrpc
  # Storage for an actual function definition.
  # Implements a `call` method so that it may be invoked with a simple hash of params.
  class Function
    attr_reader :service_name, :name, :rpc_desc

    def initialize(service_name, service_stub, rpc_desc)
      @service_name = service_name
      @service_stub = service_stub
      @rpc_desc = rpc_desc
      @name = ::GRPC::GenericService.underscore(rpc_desc.name.to_s).to_sym
    end

    def to_s
      "<GrpcFunction #{service_name}##{name} >"
    end

    def function_args
      result = TypeLibrary.descriptor_for(rpc_desc.input).types(InputTypeLibrary::PREFIX)
      result.any? ? "(#{result.join(', ')})" : ''
    end

    def input_type
      rpc_desc.input.to_s.split(':').last
    end

    def output_type
      rpc_desc.output.to_s.split(':').last
    end

    def to_query_type
      # Turns out the single *Request type should NOT be the single arg.
      #
      # If GrpcFunctionNameRequest has two fields:
      #
      #   foo: <type>
      #   bar: <type>
      #
      # then the schema needs to show:
      #
      # GrpcFunctionName(foo: <type>, bar: <type>): GrpcFunctionNameResponse
      #
      # instead of:
      #
      # GrpcFunctionName(input: GrpcFunctionNameRequest): GrpcFunctionNameResponse
      #
      "#{rpc_desc.name}#{function_args}: #{output_type}!"
    end

    def call(params = {}, metadata = {})
      args = [name, arg(params || {}), metadata: metadata]
      result_hash = @service_stub.send(*args).to_hash
      arrayify_hashes(result_hash)
    end

    private

    # Build arguments to a func
    def arg(params)
      rpc_desc.input.decode_json(params.reject { |k, _v| k == :selections }.to_json)
    end
  end
end
