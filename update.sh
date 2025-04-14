#!/usr/bin/env bash

# Exit on fail
set -e

bash shutdown.sh

echo ""

source .env
cd $HOST_WEBUI_DIRECTORY

current_hash=`git rev-parse HEAD`
echo "if you run into problems and need to revert, use the following command, including parentheses:"
echo "(cd $HOST_WEBUI_DIRECTORY && git checkout $current_hash)"
echo ""
echo "If you have reverted and need to return to head, use the following command, including parentheses:"
echo "(cd $HOST_WEBUI_DIRECTORY && git checkout main)"

echo ""

echo "Updating $HOST_WEBUI_DIRECTORY."

git pull
