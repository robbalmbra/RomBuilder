#!/bin/bash

# Check if user has requirements installed
if ! [ -x "$(command -v gcloud)" ]; then
  echo '$0 - Error: gcloud is not installed. Install from https://cloud.google.com/sdk/docs'
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

token_size=${#TOKEN}

if [ $token_size -ne 50 ]; then
  echo "Error - TOKEN is invalid"
  exit 6
fi

# Change here to alter vm default attributes
VM_OS_PROJECT="ubuntu-os-cloud"
VM_OS_FAMILY="ubuntu-1804-lts"
VM_SIZE="250GB"
VM_MACHINE="n1-standard-8"
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
  exit 7
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
  exit 8
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
    exit 9
  fi
fi

# Create build startup script
cat >run.sh <<EOL
echo "Running custom startup script"
export BHOST="$VM_NAME"
export BTOKEN="$TOKEN"
wget https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh -O /opt/setup-buildtools.sh > /dev/null 2>&1
chmod 700 /opt/setup-buildtools.sh
/bin/bash /opt/setup-buildtools.sh
EOL

# Create service account for instance scope
gcloud iam service-accounts create buildkite-user --display-name "Service Account" > /dev/null 2>&1
service_account = "buildkite-user@$PROJECT_NAME.iam.gserviceaccount.com"

# Assign roles/owner to service account
gcloud projects add-iam-policy-binding $PROJECT_NAME --member serviceAccount:$service_account --role roles/owner > /dev/null 2>&1

# Create instance
gcloud compute instances create "$VM_NAME" --service-account $service_account --scopes https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform --boot-disk-type=pd-ssd --machine-type="$VM_MACHINE" --zone="$ZONE" --image-family="$VM_OS_FAMILY" --image-project="$VM_OS_PROJECT" --boot-disk-size="$VM_SIZE" --metadata-from-file startup-script=run.sh

# Remove temp files
rm -rf run.sh > /dev/null 2>&1
