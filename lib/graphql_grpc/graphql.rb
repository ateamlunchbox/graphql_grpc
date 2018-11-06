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
module GraphqlGrpc
  class Graphql
    OP_FIELD = ::GraphQL::Language::Nodes::OperationDefinition

    def initialize(proxy, error_presenter)
      @error_presenter = error_presenter
      @proxy = proxy
      @output = { 'data' => {} }
    end

    # Given a graphQL document, execute those OperationDefinitions which map to a RPC
    # The document will be modified to not include those fields / selections which were executed.
    def execute(document, variables = {}, metadata = {})
      @variables = variables || {}
      @metadata = metadata || {}
      document.definitions.reject! do |d|
        # Filter out fields handled by GRPC...
        d.selections.reject! { |s| graphql(s) } if d.is_a?(OP_FIELD)
        d.selections.empty? # Filter the empty operations.
      end
      @output
    end

    private

    # Execute a GraphQL field as an RPC on the proxy.
    # @param field [GraphQL::Language::Nodes::GraphqlSelection] the RPC field.
    # @param block [Proc] the presenter for the error handler.
    def graphql(field)
      return false unless @proxy.respond_to?(field.name)

      key = (field.alias || field.name).to_s
      resp = @proxy.rpc(field.name, vars_from(field), @metadata)
      @output['data'][key] = present(field, resp)
      true
    rescue StandardError => e
      @output['errors'] ||= []
      @output['errors'] << @error_presenter.call(e)
      true
    end

    # Filter the response down to the selected fields.
    # n.b., the GRPC server should not include unselected fields, but those fields will appear
    # as blank/empty in the response unless we actually filter the keys.
    def present(field, resp)
      return resp unless field.selections

      if resp.is_a?(Hash)
        return Time.at(resp[:seconds]).to_datetime if resp.keys == %i[seconds nanos] # TODO: find better way to detect timestamps...

        result = field.selections.each_with_object({}) do |s, out|
          out[(s.alias || s.name).to_s] = present(s, resp[s.name.to_sym])
        end
        result
      elsif resp.is_a?(Array)
        resp.map { |r| present(field, r) }
      else
        resp
      end
    end

    # Extract the variables from a field.
    def vars_from(field)
      vars = {}
      vars[:selections] = graphql_selections_array(field)
      field.arguments.each do |arg|
        val = if arg.value.is_a?(::GraphQL::Language::Nodes::VariableIdentifier)
                @variables[arg.value.name.to_s]
              elsif arg.value.is_a?(::GraphQL::Language::Nodes::Enum)
                arg.value.name
              else
                arg.value
              end
        vars[arg.name] = val
      end
      vars
    end

    # Turn a field into a selections object for the RPC.
    def graphql_selections_array(field)
      return nil unless field && field.selections.any?

      field.selections.map do |sel|
        {
          name: sel.name,
          selections: graphql_selections_array(sel)
        }
      end
    end
  end
end
