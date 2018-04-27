#!/bin/bash

export CI=true
export CIRCLECI=true

# Source rbenv if exists
if which rbenv > /dev/null
then
    echo "rbenv installed... initializing"
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
fi

# install dependencies and run default rake task
cd /var/simdata/openstudio
bundle update 
bundle exec rspec --format html
