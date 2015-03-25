# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'px/service/kinesis/version'

Gem::Specification.new do |spec|
  spec.name          = "px-kinesis-client"
  spec.version       = Px::Service::Kinesis::VERSION
  spec.authors       = ["Paul Xue"]
  spec.email         = ["pxue@500px.com"]
  spec.summary       = %q{Ruby wrapper for AWS Kinesis}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "px-service-client", "1.0.1"
  spec.add_dependency "circuit_breaker", "~> 1.1"
  spec.add_dependency "aws-sdk", "~> 2.0.0"
  spec.add_dependency "msgpack"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "timecop"
end
