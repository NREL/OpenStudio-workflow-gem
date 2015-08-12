# OpenStudio::Workflow
[![Circle CI](https://circleci.com/gh/NREL/OpenStudio-workflow-gem/tree/EnergyPlus-8.3.0.svg?style=svg)](https://circleci.com/gh/NREL/OpenStudio-workflow-gem/tree/EnergyPlus-8.3.0)
[![Coverage Status](https://coveralls.io/repos/NREL/OpenStudio-workflow-gem/badge.svg?branch=docker-tests&service=github)](https://coveralls.io/github/NREL/OpenStudio-workflow-gem?branch=EnergyPlus-8.3.0) [![Dependency Status](https://www.versioneye.com/user/projects/5531fb7b10e714121100102e/badge.svg?style=flat)](https://www.versioneye.com/user/projects/5531fb7b10e714121100102e)

Run an EnergyPlus simulation using a file-based workflow that is read from a Local or MongoDB adapter.

## Installation

The OpenStudio Workflow Gem has the following dependencies:

* Ruby 2.0
* OpenStudio with Ruby 2.0 bindings
* EnergyPlus 8.3 (assuming OpenStudio >= 1.7.2)
* MongoDB if using MongoDB Adapter (or when running rspec)

[OpenStudio](http://developer.nrel.gov/downloads/buildings/openstudio/builds/) needs to be installed
and in your path.  On Mac/Linux it is easiest to add the following to your .bash_profile or /etc/profile.d/<file>.sh to ensure OpenStudio can be loaded.

    export OPENSTUDIO_ROOT=/usr/local
    export RUBYLIB=$OPENSTUDIO_ROOT/lib/ruby/site_ruby/2.0.0

Add this line to your application's Gemfile:

    gem 'OpenStudio-workflow'

Use this line if you want the bleeding edge:

    gem 'OpenStudio-workflow', github: 'NREL/OpenStudio-workflow-gem', branch: 'EnergyPlus-8.2.0'

And then execute:
    
    Mac/Linux:

        $ bundle
        
    Windows (avoids native extensions):
    
        $ bundle install --without xml profile

Or install it yourself as:
    
    $ gem install OpenStudio-workflow
    
## Usage

Note that the branches of the Workflow Gem depict which version of EnergyPlus is in use. The develop branch at the
moment should not be used.

There are currently two adapters to run OpenStudio workflow. The first is a simple Local adapter
allowing the user to pass in the directory to simulation. The directory must have an
[analysis/problem JSON file](spec/files/local_ex1/analysis_1.json) and a [datapoint JSON file](spec/files/local_ex1/datapoint_1.json).
The workflow manager will use these data (and the measures, seed model, and weather data) to assemble and
execute the standard workflow of (preflight->openstudio measures->energyplus->postprocess).

    r = OpenStudio::Workflow.load 'Local', '/home/user/a_directory', options
    r.run

The workflow manager can also use MongoDB to receive instructions on the workflow to run and the data point values.

## Caveats and Todos

### Todos

* Read the analysis.json file to determine the states that are going to run instead of (or in addition to) passing them into the constructor
* Implement better error handling with custom exception classes
* Add a results adapter to return a string as the last call based on the source of the call. (e.g. R, command line, C++, etc).
* Implement a logger in the Adapters, right now they are unable to log
* Hook up the measure group based workflows

## Testing

The preferred way for testing is to run rspec either natively or via docker. The issue with natively running the tests locally is the requirement to have mongo installed and running.

### Locally

```
rake
```

### Docker

To run all the tests automatically run:
```
docker run --rm -v $(pwd):/var/simdata/openstudio nrel/docker-test-containers:openstudio-1.8.1-mongo-2.4 /var/simdata/openstudio/test/bin/docker-run.sh
```

To run the tests inside docker and enable debugging, then create a bash shell in docker with:
```
docker run -it --rm -v $(pwd):/var/simdata/openstudio nrel/docker-test-containers:openstudio-1.8.1-mongo-2.4 bash
service mongodb start
bundle update
rake 
# or
bundle exec rspec <file>:<line>
```

## Contributing

1. Fork it ( https://github.com/NREL/OpenStudio-workflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
