source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

gem 'uuid'
gem 'zip'

group :mongo do
  gem 'mongoid', '~> 3.1.6'
  gem 'paperclip', '~> 4.1.1'
  gem 'mongoid-paperclip', :require => 'mongoid_paperclip'
  gem 'delayed_job_mongoid'
end

group :xml do
  gem 'libxml-ruby'
  gem 'os'
end

group :test do
  gem "rspec", "~> 2.14"
  gem "ci_reporter", "~> 1.9.2"
  gem "ruby-graphviz"
  gem 'rubocop', require: false
  gem 'rubocop-checkstyle_formatter', require: false
end
