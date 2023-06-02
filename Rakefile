# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'bundler'
Bundler.setup

require 'rspec/core/rake_task'

# Always create spec reports
require 'ci/reporter/rake/rspec'

# Gem tasks
require 'bundler/gem_tasks'

RSpec::Core::RakeTask.new('spec:unit') do |spec|
  spec.rspec_opts = ['--format', 'progress', '--format', 'CI::Reporter::RSpec']
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task 'spec:unit' => 'ci:setup:rspec'
task default: 'spec:unit'

require 'rubocop/rake_task'
desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--no-color', '--out=rubocop-results.xml']
  task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  task.requires = ['rubocop/formatter/checkstyle_formatter']
  # don't abort rake on failure
  task.fail_on_error = false
end

require 'openstudio-workflow'
desc 'test extracting zip'
task :test_zip do
  f = File.join(File.dirname(__FILE__), 'spec/files/example_models/the_project.zip')
  puts "Trying to extract #{f}"
  OpenStudio::Workflow.extract_archive(f, 'junk_out', true)
end

desc 'Transition IDF Files'
task :transition_idf do
  lst_path = File.join(Dir.pwd, 'IdfFilesToTransition.lst')
  File.open(lst_path, 'w') do |file|
    Dir.glob('**/*.idf').each do |idf|
      file.puts(File.join(Dir.pwd, idf))
    end
  end
  puts "Use the IDFVersionUpdater and point it to #{lst_path}"
end
