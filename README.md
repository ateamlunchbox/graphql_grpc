# graphql_grpc

Generate and run a GraphQL-to-gRPC service proxy quickly and easily based on gRPC client stubs.  The graphql_grpc gem will build a GraphQL schema based on the gRPC client stub methods and types; queries and mutations can then be executed on the GraphQL schema which passes the requests on to the proxied gRPC service for processing, then returns the gRPC result as a GraphQL response.

See bin/example.rb with its comments for example usage, or https://github.com/ateamlunchbox/graphql_grpc_example
for a Ruby on Rails-based example.
