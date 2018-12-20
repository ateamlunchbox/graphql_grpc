require 'grpc'
require 'graphql_grpc/version'
require 'graphql_grpc/arrayify'
require 'graphql_grpc/function'
require 'graphql_grpc/resolver'
require 'graphql_grpc/schema'
require 'graphql_grpc/proxy'
require 'graphql_grpc/type_library'

module GraphqlGrpc
  # Your code goes here...
end

GraphqlGrpc::Function.include GraphqlGrpc::Arrayify
