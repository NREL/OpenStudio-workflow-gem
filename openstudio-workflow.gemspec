lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'openstudio/workflow/version'

Gem::Specification.new do |s|
  s.name = 'openstudio-workflow'
  s.version = OpenStudio::Workflow::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Nicholas Long']
  s.email = ['nicholas.long@nrel.gov']
  s.summary = %q(Workflow Manager)
  s.description = %q(Run OpenStudio based simulations using EnergyPlus)
  s.homepage = 'https://github.com/NREL/OpenStudio-workflow-gem'
  s.license = 'LGPL'

  s.required_ruby_version = '>= 1.9.3'

  s.files = Dir.glob('lib/**/*') + %w(README.md CHANGELOG.md Rakefile)
  # s.test_files = Dir.glob("spec/**/*")
  s.require_path = 'lib'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'rake'

  s.add_runtime_dependency 'aasm', '~> 3.1.1'
  s.add_runtime_dependency 'multi_json', '~> 1.10.0'
  s.add_runtime_dependency 'colored', '~> 1.2'

  # Don't require facter until we can figure out how to install this easy on windows
  # spec.add_runtime_dependency 'facter', '~> 2.0.1'
end
