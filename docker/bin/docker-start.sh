#!/usr/bin/env bash

set -e

docker run -p 5432:5432 --network razor-db -it --name postgres -e POSTGRES_USER=razor -d postgres

# Build and run the image, using the tag `latest` and exposing ports 8150 and 8151.
docker build -t razor-server "$(realpath $(dirname $0))/../.."
# Run the instance. We need a few things:
# Port 8080 forwarded for API and SVC traffic.
# The `repo/` directory mounted, so the microkernel can live outside the container.
# Connecting to an internal network, `razor-db`, which is where our postgres instance lives.
docker run -p 8080:8080 -d --network razor-db -v "$(realpath $(dirname $0))/../../repo":/var/lib/razor/repo-store -it --name razor-server razor-server

# To ensure the service is running, let's check the API.
printf "Waiting for API to be ready"
tries=0
until $(curl --output /dev/null --silent --head --fail http://localhost:8080/api); do
    printf "."
    sleep 2
    tries=$((tries+1))
    if [ "$tries" -gt "40" ]; then
        echo; echo "Error: took too long to complete"; echo
        exit 1
    fi
done
echo "done!"
