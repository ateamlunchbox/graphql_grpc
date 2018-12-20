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

require 'active_support/core_ext/string'
module GraphqlGrpc
  class GrpcGatewayError < StandardError; end
  class HealthError < GrpcGatewayError; end
  class ConfigurationError < GrpcGatewayError; end
  class RpcNotFoundError < GrpcGatewayError; end

  class Proxy
    include GraphqlGrpc::Schema
    attr_reader :services

    # @param stub_services [Hash] mapping of a service_name to an instance of a stub service.
    # @param error_presenter [Proc] a method that turns exceptions into a hash.
    def initialize(stub_services = {}, &block)
      @function_map = {} # func name => hash containing details
      @services = {}
      @error_presenter = block
      map_functions(stub_services)
    end

    # Return a hash of all the healthchecks from all the services.
    def healthcheck
      Hash[@services.map do |service_name, stub|
        hc = stub.send(:healthcheck, ::Google::Protobuf::Empty.new)
        raise HealthError, "#{service_name} is not healthy." unless hc && hc.processID > 0

        [service_name, hc]
      end]
    end

    def function(function_name, noisy = true)
      # function_name is a symbol; calling #to_s and #underscore calls #gsub! on it
      # and it is frozen; so #dup first.
      func = @function_map[::GRPC::GenericService.underscore(function_name.to_s.dup).to_sym]
      raise RpcNotFoundError, "#{function_name} does not exist." if noisy && !func

      func
    end

    def invoke(field, args, ctx)
      rpc(field.name, args.to_h, {})
    end

    # Execute a function with given params.
    def rpc(function_name, params = {}, metadata = {})
      function(function_name).call(params, metadata || {})
    end

    def respond_to_missing?(method, _include_private = false)
      !!function(method, false)
    end

    # Proxy methods through to the services, instead of calling rpc()
    def method_missing(method, *args, &block)
      return rpc(method, args.first, args[1]) if function(method)

      super
    end

    private

    # Add to the function_map by inspecting each service for the RPCs it provides.
    def map_functions(stub_services)
      return @function_map unless @function_map.empty?

      stub_services.keys.each do |service_name|
        stub = @services[service_name] = stub_services[service_name]
        stub.class.to_s.gsub('::Stub', '::Service').constantize.rpc_descs.values.each do |d|
          next if d.name.to_sym == :Healthcheck

          grpc_func = ::GraphqlGrpc::Function.new(service_name, stub, d)
          if @function_map.key?(grpc_func.name)
            sn = @function_map[grpc_func.name].service_name
            STDERR.puts "Skipping method #{grpc_func.name}; it was already defined on #{sn}"
            # raise ConfigurationError, "#{grpc_func.name} was already defined on #{sn}."
          end
          @function_map[grpc_func.name] = grpc_func
        end
      end
      @function_map
    end
  end
end
