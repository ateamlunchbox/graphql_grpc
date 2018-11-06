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

require 'spec_helper'
require 'ruby_robot'
require 'graphql_grpc'
require 'securerandom'

RSpec.describe GraphqlGrpc, type: :model do
  describe 'When a schema is generated from a gRPC stub' do

    before :each do
      services = {
        # See: https://grpc.io/docs/tutorials/basic/ruby.html#creating-the-client
        :ruby_robot => ::RubyRobot::RubyRobot::Stub.new('localhost:31310', :this_channel_is_insecure)
      }
      @proxy = GraphqlGrpc::Proxy.new(services, &lambda do |error|
        STDERR.puts "Error in proxy"
        error.backtrace.each { |i| STDERR.puts i }
        STDERR.puts error
      end)
    end

    it 'successfully responds to schema queries' do
      response = @proxy.to_gql_schema
    end

    it 'includes a list of queries' do
      expect(@proxy.gql_queries.size).to be > 2
    end

    it 'includes a list of mutations' do
      expect(@proxy.gql_mutations.size).to be > 0
    end

    it 'produces a valid GraphQL schema that can be parsed by GraphQL::Schema#from_definition' do
      GraphQL::Schema.from_definition(@proxy.to_gql_schema)
    end

    it 'produces a schema that responds to graphiql queries' do
      graphiql_query = '{"query":"\n  query IntrospectionQuery {\n    __schema {\n      queryType { name }\n      mutationType { name }\n      subscriptionType { name }\n      types {\n        ...FullType\n      }\n      directives {\n        name\n        description\n        args {\n          ...InputValue\n        }\n        onOperation\n        onFragment\n        onField\n      }\n    }\n  }\n\n  fragment FullType on __Type {\n    kind\n    name\n    description\n    fields(includeDeprecated: true) {\n      name\n      description\n      args {\n        ...InputValue\n      }\n      type {\n        ...TypeRef\n      }\n      isDeprecated\n      deprecationReason\n    }\n    inputFields {\n      ...InputValue\n    }\n    interfaces {\n      ...TypeRef\n    }\n    enumValues(includeDeprecated: true) {\n      name\n      description\n      isDeprecated\n      deprecationReason\n    }\n    possibleTypes {\n      ...TypeRef\n    }\n  }\n\n  fragment InputValue on __InputValue {\n    name\n    description\n    type { ...TypeRef }\n    defaultValue\n  }\n\n  fragment TypeRef on __Type {\n    kind\n    name\n    ofType {\n      kind\n      name\n      ofType {\n        kind\n        name\n        ofType {\n          kind\n          name\n        }\n      }\n    }\n  }\n"}'
      params = JSON.parse(graphiql_query)
      schema = GraphQL::Schema.from_definition(@proxy.to_gql_schema)
      query = GraphQL::Language::Parser.parse(params['query'])
      response = schema.execute(params['query'], {})
      expect(response).not_to be_nil
    end
  end

  describe 'For converting hashes to arrays of hashes' do
    it 'converts nested hashes with integer keys into arrays of hashes with keys '\
       "of 'key' and 'value'" do
      test_hash = { 1 => :hello, 2 => :world }
      expected_output = [{ key: 1, value: :hello }, { key: 2, value: :world }]
      o = Object.new
      o.extend GraphqlGrpc::Arrayify
      expect(o.arrayify_hashes(test_hash)).to(
        eql(expected_output)
      )
    end

    it 'should arrayify hashes with nested arrays and hashes '\
       "of 'key' and 'value'" do
      test_hash = { 1 => :hello, 2 => [1, { 5 => :world }] }
      expected_output = [{ key: 1, value: :hello }, { key: 2, value: [1, [{ key: 5, value: :world }]] }]
      o = Object.new
      o.extend GraphqlGrpc::Arrayify
      expect(o.arrayify_hashes(test_hash)).to(
        eql(expected_output)
      )
    end
  end
end
