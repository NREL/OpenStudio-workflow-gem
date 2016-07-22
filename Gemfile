source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

# always install these dependencies for connecting to mongo
gem 'mongoid', '~> 3.1.6'
gem 'paperclip', '~> 4.3'
gem 'mongoid-paperclip', require: 'mongoid_paperclip'
gem 'delayed_job_mongoid'

# OpenStudio Standards - Don't require by default for now
gem 'openstudio-standards', github: 'NREL/openstudio-standards', require: false

# Installation for reading/writing xml
group :xml do
  gem 'libxml-ruby', '~> 2.8.0'
  gem 'os', '~> 0.9.6'
end

group :test do
  gem 'coveralls', require: false
  gem 'ruby-prof', '~> 0.15.1'
  gem 'openstudio-analysis', '0.4.5'
  gem 'rspec', '~> 3.4'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
