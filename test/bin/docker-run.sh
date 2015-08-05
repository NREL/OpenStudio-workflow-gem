#!/bin/bash

# Start MongoDB
/sbin/start-mongodb.sh

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# install dependencies and run default rake task
cd /var/simdata/openstudio
bundle update 
bundle exec rake
