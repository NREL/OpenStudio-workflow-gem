source 'http://rubygems.org'

# Specify your gem's dependencies in OpenStudio-workflow.gemspec
gemspec

group :mongo do
  gem 'mongoid', '~> 3.1.6'
  gem 'paperclip', '~> 4.1.1' # do not upgrade because breaks the after_commit
  gem 'mongoid-paperclip', :require => 'mongoid_paperclip'
  gem 'delayed_job_mongoid'
end


group :test do
  gem "rspec", "~> 2.12"
  gem "ci_reporter", "~> 1.9.2"
  gem "ruby-graphviz"
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter', require: false
end
