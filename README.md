# OpenStudio::Workflow

Run an EnergyPlus simulation using a file-based workflow that is read from a Local or MongoDB adapter.

## Installation

This applications has the following dependencies

* Ruby 2.0
* OpenStudio with Ruby 2.0 bindings
* EnergyPlus 8.1 (assuming OpenStudio ~> 1.3.1)
* MongoDB if using MongoDB Adapter (or when running rspec)

[OpenStudio](http://developer.nrel.gov/downloads/buildings/openstudio/builds/) needs to be installed
and in your path.  On Mac/Linux it is easiest to add the following to your .bash_profile or /etc/profile.d in order
to make sure that OpenStudio can be loaded.

    export OPENSTUDIO_ROOT=/usr/local
    export RUBYLIB=$OPENSTUDIO_ROOT/lib/ruby/site_ruby/2.0.0

Add this line to your application's Gemfile:

    gem 'OpenStudio-workflow'

Use this line if you want the bleeding edge:

    gem 'OpenStudio-workflow', :git => 'git@github.com:NREL/OpenStudio-workflow-gem.git'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install OpenStudio-workflow

## Usage

There are currently two adapters to run OpenStudio workflow. The first is a simple Local adapter
allowing the user to pass in the directory to simulation. The directory must have an
[analysis/problem JSON file](spec/files/local_ex1/analysis_1.json) and a [datapoint JSON file](spec/files/local_ex1/datapoint_1.json).
The workflow manager will use these data (and the measures, seed model, and weather data) to assemble and
execute the standard workflow of (preflight->openstudio measures->energyplus->postprocess).

    r = OpenStudio::Workflow.load 'Local', '/home/user/a_directory', options
    r.run

The workflow manager can also use MongoDB to receive instructions on the workflow to run and the data point values.

## Caveats and Todos

### Caveats

* There are currently several hard coded workflow options
* Must use OpenStudio with Ruby 2.0 support
* Using MongoDB as the Adapter requires a command line zip (gnuzip) utility

### Todos

* Read the analysis.json file to determine the states that are going to run instead of (or inaddition to) passing them into the constructor
* Implement better error handling with custom exception classes
* Implement a different measure directory, seed model directory, and weather file directory option
* ~Dynamically add other "states" to the workflow~
* Create and change into a unique directory when running measures
* ~~Implement Error State~~
* ~~Implement MongoDB Adapter~~
* ~~Implement remaining Adapter states (i.e. communicate success, communicate failure etc~~
* Add a results adapter to return a string as the last call based on the source of the call. (e.g. R, command line, C++, etc).
* Implement a logger in the Adapters, right now they are unable to log
* Hook up the measure groups based workflows
* ~~Add xml workflow item~~

## Testing and Development

Depending on what adapter is being tested it may be preferable to skip installing various gems.  This can be done by calling

    bundle install --without mongo

On Windows it is recommended to bundle without mongo nor ci as they may require native extensions.

    bundle install --without mongo ci

### Testing

Run `rspec` or `rake` to execute the tests.

## Contributing

1. Fork it ( https://github.com/NREL/OpenStudio-workflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Development

