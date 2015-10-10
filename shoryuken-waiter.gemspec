# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "shoryuken/waiter/version"

Gem::Specification.new do |spec|
  spec.name          = "shoryuken-waiter"
  spec.version       = Shoryuken::Waiter::VERSION
  spec.authors       = ["Chris Kalafarski"]
  spec.email         = ["chris@farski.com"]

  spec.summary       = "Adds support for longer wait times to Shoryuken"
  spec.description   = "Supports scheduling jobs beyond 15 minutes when using Shoryuken with Active Job."
  spec.homepage      = "http://github.com/farski/shoryuken-waiter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "coveralls", "~> 0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "dotenv"
  spec.add_development_dependency "rubocop"

  spec.add_dependency "shoryuken", "~> 2.0.0"
  spec.add_dependency "aws-sdk", "~> 2"
end
