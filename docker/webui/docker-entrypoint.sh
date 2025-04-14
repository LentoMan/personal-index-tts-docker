#!/bin/bash

# Check internet access when running in offline mode
if [[ "$OFFLINE_MODE" == "true" ]]
then
  echo "Running in offline mode, verifying that internet access is disabled."
  ping -c 1 8.8.8.8 > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo "Warning: Internet appears accessible in offline mode, aborting launch."
    exit 1
  else
    echo "Internet appears unreachable, proceeding with launch."
  fi
fi

# Exit on fail, also fail when piped || command fail
set -e -o pipefail

# Create container user if it does not exist
_=$(id ${CONTAINER_USER} 2>&1) || useradd -u ${UID} ${CONTAINER_USER}

# Launch with bind mounted home and temp directories, a few cached files may otherwise be lost on container recreation which will break offline mode.
# Current default are <stable-diffusion-webui-repo>/cache/home and <stable-diffusion-webui-repo>/cache/tmp
exec gosu ${CONTAINER_USER} env HOME=$CONTAINER_HOME TMPDIR=$CONTAINER_TMPDIR "$@"
