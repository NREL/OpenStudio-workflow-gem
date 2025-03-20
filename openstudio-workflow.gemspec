# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'openstudio/workflow/version'

Gem::Specification.new do |s|
  s.name = 'openstudio-workflow'
  s.version = OpenStudio::Workflow::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Nicholas Long', 'Henry Horsey']
  s.email = ['nicholas.long@nrel.gov', 'henry.horsey@nrel.gov']
  s.summary = 'OpenStudio Workflow Manager'
  s.description = 'Run OpenStudio based measures and simulations using EnergyPlus'
  s.homepage = 'https://github.com/NREL/OpenStudio-workflow-gem'
  s.license = 'BSD'

  s.files = Dir.glob('lib/**/*') + ['README.md', 'CHANGELOG.md', 'Rakefile']
  s.require_path = 'lib'

  s.required_ruby_version = '~> 3.2.2'

  s.add_development_dependency 'builder', '~> 3.2.4'
  s.add_development_dependency 'bundler', '2.4.10'
  s.add_development_dependency 'ci_reporter', '~> 2.1.0'
  s.add_development_dependency 'ci_reporter_rspec', '~> 1.0.0'
  s.add_development_dependency 'coveralls', '~> 0.8.21'
  s.add_development_dependency 'json-schema', '~> 4'
  s.add_development_dependency 'openstudio_measure_tester', '~> 0.4.0'
  s.add_development_dependency 'parallel', '~> 1.19.1'
  s.add_development_dependency 'public_suffix', '~> 4.0.3'
  s.add_development_dependency 'rainbow', '~> 3.0.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.9'
  s.add_development_dependency 'openstudio-standards', '~> 0.7.0'
  s.add_development_dependency 'zip', '~> 2'
end
