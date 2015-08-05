source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

# always install these dependencies for connecting to mongo
gem 'mongoid', '~> 3.1.6'
gem 'paperclip', '~> 4.1.1'
gem 'mongoid-paperclip', require: 'mongoid_paperclip'
gem 'delayed_job_mongoid'

# Installation for reading/writing xml
group :xml do
  gem 'libxml-ruby', '~> 2.8.0'
  gem 'os', '~> 0.9.6'
end

group :test do
  gem 'simplecov', :require => false
  gem 'ruby-prof', '~> 0.15.1'
  gem 'openstudio-analysis', github: 'NREL/OpenStudio-analysis-gem', branch: 'develop'
  gem 'rspec', '~> 3.3'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
