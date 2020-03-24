# OpenStudio::Workflow

[![Dependency Status](https://www.versioneye.com/user/projects/5531fb7b10e714121100102e/badge.svg?style=flat)](https://www.versioneye.com/user/projects/5531fb7b10e714121100102e)

## OpenStudio Workflow Gem

This branch is the development branch for the OpenStudio workflow gem.
## Installation

The OpenStudio Workflow Gem has the following dependencies:

* Ruby 2.5.5
* OpenStudio 3.x

[OpenStudio](https://www.openstudio.net/) needs to be installed and in your path.  On Mac/Linux it is easiest to add the following to your .bash_profile or /etc/profile.d/<file>.sh to ensure OpenStudio loads. Assuming OpenStudio 3.0.0 installed:

    export RUBYLIB=/usr/local/openstudio-3.0.0/Ruby

Add this line to your application's Gemfile:

    gem 'OpenStudio-workflow'

And then execute:

    bundle install

Or install it yourself as:

    $ gem install openstudio-workflow

## Usage

There are currently two adapters to run OpenStudio workflow. The first is a simple Local adapter allowing the user to pass in the directory to simulation. The directory must have an [analysis/problem JSON file](spec/files/local_ex1/analysis_1.json) and a [datapoint JSON file](spec/files/local_ex1/datapoint_1.json).

The workflow manager will use these data (and the measures, seed model, and weather data) to assemble and execute the standard workflow of (preflight->openstudio measures->energyplus->postprocess).

    r = OpenStudio::Workflow.load 'Local', '/home/user/a_directory', options
    r.run

There are also socket and web-based adapters that have yet to be documented.

## Testing

The preferred way for testing is to run rspec either natively or via docker.

### Locally

```
rspec spec/
```

### Docker

```
export OPENSTUDIO_VERSION=3.0.0
docker run -v $(pwd):/var/simdata/openstudio \
      nrel/openstudio:$OPENSTUDIO_VERSION \
      /var/simdata/openstudio/test/bin/docker-run.sh
```

## Contributing

1. Fork it ( https://github.com/NREL/OpenStudio-workflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
