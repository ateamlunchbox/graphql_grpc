lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'graphql_grpc/version'

Gem::Specification.new do |spec|
  spec.name          = 'graphql_grpc'
  spec.version       = GraphqlGrpc::VERSION
  spec.authors       = ['Zane Claes', 'Dane Avilla']
  spec.email         = ['davilla@netflix.com']
  spec.license       = 'MIT'
  spec.summary       = 'Gem for building GraphQL-to-gRPC gateways (usually using Ruby on Rails).'
  spec.description   = 'This is a gem packaging up gRPC proxy code to GraphQL from http://examinedself.com/graphql-grpc/, along with code to generate a GraphQL schema from gRPC stubs.'
  spec.homepage      = 'https://github.com/ateamlunchbox/graphql_grpc'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'graphql'
  spec.add_runtime_dependency 'grpc'
  spec.add_runtime_dependency 'sorbet-runtime'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'wirble'

  # Add ruby_robot in dev so there's a protobuf definition available
  # within bin/console env.
  spec.add_development_dependency 'guard-bundler'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'ruby_robot'
  spec.add_development_dependency 'sorbet'
end
