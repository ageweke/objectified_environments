# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'objectified_environments/version'

Gem::Specification.new do |spec|
  spec.name          = "objectified_environments"
  spec.version       = ObjectifiedEnvironments::VERSION
  spec.authors       = ["Andrew Geweke"]
  spec.email         = ["andrew@errorsea.com"]
  spec.description   = %q{Exposes your Rails.env as an object you can invoke methods on, use inheritance to structure,
and otherwise use all modern powerful programming techniques on. In large projects,
this can make an enormous difference in maintainability and reliability.}
  spec.summary       = %q{Vastly improve maintainability of your Rails.env-dependent code by using object-oriented environments.}
  spec.homepage      = ""
  spec.license       = "Proprietary"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2.14"

  spec.add_dependency "rails", ">= 3.0", "<= 4.99.99"
end
