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
  s.license = 'BSD'

  s.required_ruby_version = '>= 2.2.4'
  
  s.files = Dir.glob('lib/**/*') + %w(README.md CHANGELOG.md Rakefile)
  s.require_path = 'lib'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'rspec', '3.7.0'

  s.add_development_dependency 'json-schema', '2.8.0'
  
  s.add_development_dependency 'ci_reporter', '2.0.0'
  s.add_development_dependency 'ci_reporter_rspec', '1.0.0'
  s.add_development_dependency 'builder', '2.1.2'
  s.add_development_dependency 'coveralls', '0.8.21'
  s.add_development_dependency 'parallel', '1.12.1'

  s.add_development_dependency 'rubocop', '0.54.0'
  s.add_development_dependency 'rubocop-checkstyle_formatter', '0.4.0'
  s.add_development_dependency 'public_suffix', '2.0.5'
  s.add_development_dependency 'rainbow', '2.2.2'

end
