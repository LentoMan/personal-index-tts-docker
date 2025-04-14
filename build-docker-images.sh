#!/usr/bin/env bash

# Exit on fail
set -e

bash shutdown.sh

echo "Downloading ubuntu base images and building custom docker images."
echo "If this is your first run, this may take a while."

docker compose build

echo ""
echo "Docker images has been built."
echo ""

echo "You may now launch the webui with internet enabled to complete the setup:"
echo "./run-with-internet.sh"
