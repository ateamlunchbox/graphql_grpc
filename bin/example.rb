#!/usr/bin/env ruby
#
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

require 'bundler/setup'
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')
require 'graphql_grpc'
require 'ruby_robot'

#
# This script communicates with the gRPC service packaged up in the 'ruby_robot' gem.
# Be sure to run `ruby_robot_grpc_server` (a command included with the ruby_robot gem)
# before attempting to run this script.
#

services = {
  # See: https://grpc.io/docs/tutorials/basic/ruby.html#creating-the-client
  :ruby_robot => ::RubyRobot::RubyRobot::Stub.new('localhost:31310', :this_channel_is_insecure)
}

proxy = GraphqlGrpc::Proxy.new(services, &lambda do |error|
  STDERR.puts "Error in proxy"
  error.backtrace.each { |i| STDERR.puts i }
  STDERR.puts error
end)

STDERR.puts 'Be sure to run ruby_robot_grpc_server before attempting to use this proxy...'

# Call a method defined in :ruby_robot on the proxy
puts 'gRPC #remove result: ' + proxy.remove.to_s
puts 'gRPC #report result: ' + proxy.report.to_s

# GraphQL
gql_query_doc = <<GRAPHQL_QUERY
query {
  report {
    error {
      error
      message
    }
  }
}
GRAPHQL_QUERY

puts "GraphQL query result: " +
     proxy.graphql.execute(GraphQL::Language::Parser.parse(gql_query_doc), {}).to_s
