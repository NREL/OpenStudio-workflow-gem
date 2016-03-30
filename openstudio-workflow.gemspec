lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'openstudio/workflow/version'

Gem::Specification.new do |s|
  s.name = 'openstudio-workflow'
  s.version = OpenStudio::Workflow::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Nicholas Long']
  s.email = ['nicholas.long@nrel.gov']
  s.summary = 'Workflow Manager'
  s.description = 'Run OpenStudio based simulations using EnergyPlus'
  s.homepage = 'https://github.com/NREL/OpenStudio-workflow-gem'
  s.license = 'LGPL'

  s.required_ruby_version = '>= 1.9.3'

  s.files = Dir.glob('lib/**/*') + %w(README.md CHANGELOG.md Rakefile)
  # s.test_files = Dir.glob("spec/**/*")
  s.require_path = 'lib'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'json-schema'
end
