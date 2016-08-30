lib = File.expand_path('../lib/', __FILE__)
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
  s.license = 'LGPL'

  s.required_ruby_version = '>= 2.0'

  s.files = Dir.glob('lib/**/*') + %w(README.md CHANGELOG.md Rakefile bin/openstudio_cli)
  s.executables << 'openstudio_cli'
  s.require_path = 'lib'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'json-schema', '~> 0'

  #s.add_runtime_dependency 'multi_json', '~> 1.10'
  #s.add_runtime_dependency 'colored', '~> 1.2'
  #s.add_runtime_dependency 'facter', '>= 2.0'
  #s.add_runtime_dependency 'rubyXL', '~> 3.3' # install rubyXL gem to read/write excel files
  #s.add_runtime_dependency 'rubyzip', '~> 1.2'
end
