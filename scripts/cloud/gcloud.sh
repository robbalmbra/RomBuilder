#!/bin/bash

# Check if user has requirements installed
if ! [ -x "$(command -v gcloud)" ]; then
  echo '$0 - Error: gcloud is not installed.' >&2
  exit 1
fi

if [ $# -lt 3 ]; then
  echo "USAGE: $0 [TOKEN] [PROJECT NAME] [ZONE] [[MACHINE TYPE]]"
  exit 2
fi

if [ -z $1 ]; then
  echo "$0 - Error: TOKEN is invalid"
  exit 3
fi

if [ -z $2 ]; then
  echo "$0 - Error: PROJECT NAME is invalid"
  exit 4
fi

if [ -z $3 ]; then
  echo "$0 - Error: ZONE is invalid"
  exit 5
fi

TOKEN=$1
PROJECT_NAME=$2
ZONE=$3

# Change here to alter vm default attributes
VM_OS_PROJECT="ubuntu-os-cloud"
VM_OS_FAMILY="ubuntu-1804-lts"
VM_SIZE="300GB"
VM_MACHINE="n1-standard-2"
VM_NAME="buildkite-$((1 + RANDOM % 10000000))"

# Check projects - iterate over projects
PROJECTS=$(gcloud projects list)
found=0
while IFS= read -r line; do
  PROJECT=$(echo "$line" | awk '{print $1}')
  if [[ $PROJECT_NAME == $PROJECT ]]; then
    gcloud config set project $PROJECT_NAME > /dev/null 2>&1
    found=1
    break
  fi
done <<< "$PROJECTS"

# Error if failed to find project
if [ $found -eq 0 ]; then
  echo "Error - Failed to find project name '$PROJECT_NAME'."
  exit 6
fi

# Check zones
found=0
ZONES=($(gcloud compute zones list | tail +2 | awk '{print $1}'))
for entry in "${ZONES[@]}"
do
  if [[ $ZONE == $entry ]]; then
    found=1
    break
  fi
done

# Error if failed to find zone
if [ $found -eq 0 ]; then
  echo "Error - Failed to find zone '$ZONE'. Use 'gcloud compute zones list' to list valid configurations."
  exit 7
fi

# Check machine types if specified
if [ ! -z $4 ]; then
  VM_MACHINE="$4"
  found=0
  MACHINE_TYPES=($(gcloud compute machine-types list | tail +2 | awk '{print $1}'))
  for entry in "${MACHINE_TYPES[@]}"
  do
    if [[ $VM_MACHINE == $entry ]]; then
      found=1
      break
    fi
  done

  # Error if failed to find machine type
  if [ $found -eq 0 ]; then
    echo "Error - Failed to find machine type '$VM_MACHINE'. Use 'gcloud compute machine-types list' to list valid configurations."
    exit 8
  fi
fi

# Create build startup script
cat >run.sh <<EOL
export BHOST="$VM_NAME"
export BTOKEN="$TOKEN"
wget https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh -O /opt/setup-buildtools.sh > /dev/null 2>&1
chmod 700 /opt/setup-buildtools.sh
/opt/setup-buildtools.sh
EOL

# Create instance
gcloud compute instances create "$VM_NAME" --machine-type="$VM_MACHINE" --zone="$ZONE" --image-family="$VM_OS_FAMILY" --image-project="$VM_OS_PROJECT" --boot-disk-size="$VM_SIZE" --metadata-from-file startup-script=run.sh
