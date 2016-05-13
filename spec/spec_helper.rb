require 'simplecov'
require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'spec/files'
end

# for testing with OpenStudio 1.X
$LOAD_PATH.unshift('E:\openstudio\build\OSCore-prefix\src\OSCore-build\ruby\Debug')

# for testing with OpenStudio 2.X
#$LOAD_PATH.unshift('E:\openstudio-2-0\build\OSCore-prefix\src\OSCore-build\ruby\Debug')

# for all testing
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'openstudio-workflow'

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate
end
