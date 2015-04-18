source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

# profiling should always be available
gem 'ruby-prof', '~> 0.15.1'

# always install these dependencies for connecting to mongo
gem 'mongoid', '~> 3.1.6'
gem 'paperclip', '~> 4.1.1'
gem 'mongoid-paperclip', require: 'mongoid_paperclip'
gem 'delayed_job_mongoid'

# use the openstudio-analysis gem -- for what?
gem 'openstudio-analysis', github: 'NREL/OpenStudio-analysis-gem', branch: '0.4.2'
# gem 'openstudio-analysis', path: '../OpenStudio-analysis-gem'

# Installation for reading/writing xml
group :xml do
  gem 'libxml-ruby', '~> 2.8.0'
  gem 'os', '~> 0.9.6'
end

group :test do
  gem 'rspec', '~> 3.2.0'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
