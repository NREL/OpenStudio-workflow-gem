#!/bin/bash

# Main function to run the container.
# Copy all the files into a new test directory because they will clobber each other in parallel
function run_docker {
  echo "Running Docker container for $image"
  echo "Copying the files to a new test directory"
  mkdir -p docker_tests/$image
  rsync -a --progress . docker_tests/$image/ --exclude docker_tests --exclude .idea --exclude .git
  cd docker_tests/$image

  echo "Executing the docker command"
  docker run -e "COVERALLS_REPO_TOKEN=$COVERALLS_REPO_TOKEN" \
      -v $(pwd):/var/simdata/openstudio nrel/docker-test-containers:$image \
      /var/simdata/openstudio/test/bin/docker-run.sh

  echo "Syncing results"
}


## Script Start ##

i=0

# List any tags that you want to test of the Docker image. These must be able to be made into directories
docker_tags=(
    'openstudio-1.8.1-mongo-2.4'
    'openstudio-1.8.5-mongo-2.4'
)

# Iterate over the tags and put them into groups based on the Circle CI Node Index.
images=()
for tag in ${docker_tags[@]}
do
  if [ $(($i % $CIRCLE_NODE_TOTAL)) -eq $CIRCLE_NODE_INDEX ]
  then
    images+=${tag}
  fi
  ((i++))
done

for image in ${images[@]}
do
  run_docker
done
