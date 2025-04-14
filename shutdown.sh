#!/usr/bin/env bash

echo "Shutting down any existing webui containers."
docker compose -f docker-compose.yml down
docker compose -f docker-compose.internet-enabled.yml down
