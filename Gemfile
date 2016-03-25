source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

group :test do
  gem 'coveralls', require: false
  gem 'ruby-prof', '~> 0.15.1'
  gem 'openstudio-analysis', github: 'NREL/OpenStudio-analysis-gem', branch: 'develop'
  gem 'rspec', '~> 3.3'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
