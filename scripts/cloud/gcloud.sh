#!/bin/bash

function retrieve_public_key()
{
  ssh_pub_key=$(cat ~/.ssh/id_rsa.pub | awk '{$NF=""}1')
  echo "ubuntu:$ssh_pub_key ubuntu" > ssh.keys
}

# Check if user has requirements installed
if ! [ -x "$(command -v gcloud)" ]; then
  echo "$0 - Error: gcloud is not installed. Install from https://cloud.google.com/sdk/docs"
  exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
  echo "$0 - Error: jq is not installed."
  exit 2
fi

# Input checks
if [ $# -lt 5 ]; then
  echo "USAGE: $0 [TOKEN] [PROJECT NAME] [ZONE] [API_KEY] [ORG/PIPELINE ID] [[MACHINE TYPE]]"
  exit 3
fi

if [ -z $1 ]; then
  echo "$0 - Error: TOKEN is invalid"
  exit 4
fi

if [ -z $2 ]; then
  echo "$0 - Error: PROJECT NAME is invalid"
  exit 5
fi

if [ -z $3 ]; then
  echo "$0 - Error: ZONE is invalid"
  exit 6
fi

if [ -z $4 ]; then
  echo "$0 - Error: API_KEY is invalid"
  exit 7
fi

if [ -z $5 ]; then
  echo "$0 - Error: ORG/PIPELINE_ID is invalid"
  exit 8
fi

# Check API auth for buildkite
status_code=$(curl -o /dev/null -s -w "%{http_code}\n" -H "Authorization: Bearer $4" "https://api.buildkite.com/v2/user")
if [ $status_code -eq 401 ]; then
  echo "$0 - Error: Failed to connect to buildkite service, is your API_KEY correct?"
  exit 9
fi

# Check org/pipeline check for updating pipeline in program
pipeline_conf=$(curl "https://api.buildkite.com/v2/$5" -H "Authorization: Bearer $4" | jq -r '.configuration')
if [ -z "$pipeline_conf" ]; then
  echo "$0 - Error failed to access '$5', does the pipeline and organization exist? e.g. organizations/{org.name}/pipelines/{pipeline.name}"
  exit 10
fi

TOKEN=$1
PROJECT_NAME=$2
ZONE=$3
API_KEY=$4
PIPELINEORG_ID=$5
token_size=${#TOKEN}

if [ $token_size -ne 50 ]; then
  echo "Error - TOKEN is invalid"
  exit 11
fi

# Check if user has a ssh private key to import to gcloud
if [ ! -f ~/.ssh/id_rsa ]; then
  cat /dev/zero | ssh-keygen -q -N ""
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
  exit 12
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
  exit 13
fi

# Check machine types if specified
if [ ! -z $6 ]; then
  VM_MACHINE="$6"
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
    exit 14
  fi
fi

# Create build startup script
cat >run.sh <<EOL
echo "Running custom startup script"
export BHOST="$VM_NAME"
export BTOKEN="$TOKEN"
echo -e "#!/bin/bash\n/snap/bin/gcloud compute instances delete $VM_NAME --quiet --zone $ZONE" > /tmp/terminate.sh
wget "https://raw.githubusercontent.com/robbalmbra/RomBuilder/master/scripts/setup-buildtools.sh" -O /tmp/setup-buildtools.sh
chmod 700 /tmp/setup-buildtools.sh
chmod 700 /tmp/terminate.sh
/bin/bash /tmp/setup-buildtools.sh
chown buildkite-agent:buildkite-agent /tmp/terminate.sh
EOL

# Create service account for instance scope
gcloud iam service-accounts create buildkite-user --display-name "Service Account" > /dev/null 2>&1
service_account="buildkite-user@$PROJECT_NAME.iam.gserviceaccount.com"

# Assign roles/owner to service account
gcloud projects add-iam-policy-binding $PROJECT_NAME --member serviceAccount:$service_account --role roles/owner > /dev/null 2>&1

# Create instance
gcloud compute instances create "$VM_NAME" --service-account $service_account --scopes https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform --boot-disk-type=pd-ssd --machine-type="$VM_MACHINE" --zone="$ZONE" --image-family="$VM_OS_FAMILY" --image-project="$VM_OS_PROJECT" --boot-disk-size="$VM_SIZE" --metadata-from-file startup-script=run.sh

if [ $? -eq 0 ]; then
  echo "Warning - Machine has been launched"

  sleep 5

  # Add ssh keys to instance for user ubuntu
  retrieve_public_key
  gcloud compute instances add-metadata $VM_NAME --zone $ZONE --metadata-from-file ssh-keys=ssh.keys > /dev/null 2>&1
  echo "Adding ssh support for instance"

  # Wait for instance to turn on, copy over private key for any private repos
  public_ip=""
  while true
  do
    public_ip=$(gcloud compute instances list --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    if [[ "$public_ip" != "" ]]; then
      ssh-keygen -R $public_ip > /dev/null 2>&1
      scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa ubuntu@$public_ip:/tmp/ > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        break
      fi
    fi
    sleep 5
  done

  # Copy private config to instance if its exists on host
  if [ -f "$HOME/rom.env" ]; then
    scp -o StrictHostKeyChecking=no "$HOME/rom.env" ubuntu@$public_ip:/tmp/rom.env > /dev/null 2>&1
  fi

  # Update target name to VN_NAME if correctly configured within the buildkite env
  echo "Updating buildkite target name to '$VM_NAME' if configured correctly"
  //updated_conf=$(echo "$pipeline_conf" | sed -e "/agents/!b;n;c\      target=$VM_NAME")
  //todo



  echo "Complete"
else
  echo "Error - Machine failed to launch"
fi

# Remove temp files
rm -rf run.sh > /dev/null 2>&1
rm -rf ssh.keys > /dev/null 2>&1
