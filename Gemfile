source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

gem 'zip', '~> 2.0.2'
# Don't upgrade to > 2.0 as it breaks that facts. Need to figure out what the change is.
gem 'facter', '~> 2.0.2', require: false

# profiling should always be available
gem 'ruby-prof', '~> 0.15.1'

# always install these dependencies
gem 'mongoid', '~> 3.1.6'
gem 'paperclip', '~> 4.1.1'
gem 'mongoid-paperclip', require: 'mongoid_paperclip'
gem 'delayed_job_mongoid'

group :xml do
  gem 'libxml-ruby'
  gem 'os'
end

group :test do
  gem 'rspec', '~> 2.14'
end

group :ci do
  gem 'ci_reporter', '~> 1.9.2'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
