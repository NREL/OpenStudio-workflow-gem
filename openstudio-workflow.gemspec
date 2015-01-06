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

  s.add_runtime_dependency 'multi_json', '~> 1.10.0'
  s.add_runtime_dependency 'colored', '~> 1.2'
  s.add_runtime_dependency 'facter', '~> 2.3'
  s.add_runtime_dependency 'rubyXL', '~> 3.3.0' # install rubyXL gem to read/write excel files
  s.add_runtime_dependency 'rubyzip', '~> 1.1.6'
end
