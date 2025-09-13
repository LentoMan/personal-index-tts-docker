#!/usr/bin/env bash

# Exit on fail
set -e

bash shutdown.sh

echo ""

source .env
cd $HOST_WEBUI_DIRECTORY

echo "Index-TTS v1.5 is in maintenance mode, switching to v1.5.0 tag."

git checkout v1.5.0
