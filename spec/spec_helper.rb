require 'coveralls'
Coveralls.wear!

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'openstudio-workflow'

# Read/default the environment variable for where to run the simulations in the test
ENV['SIMULATION_RUN_DIR'] ||= './spec/files/simulations'
puts "Simulations are configured to run in #{ENV['SIMULATION_RUN_DIR']}"

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate
end
