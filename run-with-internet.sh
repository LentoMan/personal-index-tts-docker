#!/usr/bin/env bash

echo ""
echo "Launching internet enabled webui, press 'enter' to continue or 'ctrl + c' to abort."
read

bash shutdown.sh

echo "Launching internet enabled webui."
docker compose -f docker-compose.internet-enabled.yml -f docker-compose.internet-enabled.override.yml up
