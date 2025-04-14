#!/usr/bin/env bash

bash shutdown.sh

echo "Launching webui with internet disabled."
docker compose up
