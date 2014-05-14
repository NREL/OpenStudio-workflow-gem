# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'OpenStudio/workflow/version'

Gem::Specification.new do |spec|
  spec.name          = "OpenStudio-workflow"
  spec.version       = OpenStudio::Workflow::VERSION
  spec.authors       = ["Nicholas Long"]
  spec.email         = ["nicholas.long@nrel.gov"]
  spec.summary       = %q{Workflow Manager}
  spec.description   = %q{Run OpenStudio based simulations using EnergyPlus}
  spec.homepage      = ""
  spec.license       = "LGPL"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency 'aasm', '~> 3.1.1'
  spec.add_runtime_dependency 'multi_json', '~> 1.10.0'
  spec.add_runtime_dependency 'colored', '~> 1.2'
end
