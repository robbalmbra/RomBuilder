#!/bin/bash

# Script for local build V1.0

function error_message {
  echo "Error - $1"
}

function check_vars {

  count=0
  variables=$1
  variable_string=""
  for variable in "${variables[@]}"
  do
    if [[ ${!variable+x} ]]; then
      ((count=count+1))
    else
      variable_string+="$variable, "
    fi
  done

  if [ $count -gt 0 ] && [ $count -lt ${#variables[@]} ]; then
    if [ $count -eq 1 ]; then
      error_message "${variable_string:0:${#variable_string}-2} is a missing variable. Please define this."
    else
      error_message "${variable_string:0:${#variable_string}-2} are missing variables. Please define these."
    fi
    exit 1
  fi

}

error_exit()
{
    ret="$?"
    if [ "$ret" != "0" ]; then
      error_message "'$1' failed with return code '$ret'"
      exit 1
    fi
}

# Install requirements for build
CURRENT="$(pwd)"

# Requirements for buildkite
new=0

if [ ! -d "/opt/build_env" ]; then
  error_message "Build tools don't exist on machine. Please run setup-buildtools.sh in the scripts folder to install the relevant software packages."
  exit 1
fi

if [[ -z "${BUILDKITE}" ]]; then
  export USE_CCACHE=1
  # Pass other parameter to build through env vars
fi

# Check vars
variables=(
  BUILD_NAME
  UPLOAD_NAME
  DEVICES
  REPO
  BRANCH
  LOCAL_REPO
  LOCAL_BRANCH
)

# Check if required variables are set
quit=0
for variable in "${variables[@]}"
do
  if [[ -z ${!variable+x} ]]; then
    error_message "'$variable' isn't set.";
    quit=1
    break
  fi
done

# Quit if env requirements not met
if [ "$quit" -ne 0 ]; then
  exit 1
fi

# Mega/scp write credentials if local config exists, so that pipeline can be made public
if [ -f "$HOME/rom.env" ]; then
  source "$HOME/rom.env"
fi

if [ -f "/tmp/rom.env" ]; then
  source "/tmp/rom.env"
fi

# Check if telegram vars are all set if any telegram variable is set
variables=(
  TELEGRAM_TOKEN
  TELEGRAM_GROUP
  TELEGRAM_AUTHORS
  TELEGRAM_SUPPORT_LINK
)
check_vars $variables

# Check if mega vars are all set if any mega variable is set
variables=(
  MEGA_USERNAME
  MEGA_PASSWORD
)
check_vars $variables
mega_check=$count

if [ "$mega_check" -eq 2 ]; then
  export MEGA_UPLOAD=1
fi

# Check if custom upload vars all set if any custom upload variable is set
variables=(
  CUSTOM_UPLOAD_NAME
  CUSTOM_UPLOAD_SCRIPT
  CUSTOM_UPLOAD_FOLDER
  CUSTOM_UPLOAD_LINK
)

check_vars $variables
custom_upload_check=$count

if [ "$custom_upload_check" -eq 4 ]; then
  #Check if SCRIPT is url or file and test file existence
  regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

  if [[ $CUSTOM_UPLOAD_SCRIPT =~ $regex ]]; then
    wget "$CUSTOM_UPLOAD_SCRIPT" -O /tmp/custom_script > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      error_message "CUSTOM_UPLOAD_SCRIPT is an invalid url"
      exit 1
    fi
  else
    if [ ! -f "$CUSTOM_UPLOAD_SCRIPT" ]; then
      error_message "CUSTOM_UPLOAD_SCRIPT is an invalid file"
      exit 1
    else
      cp "$CUSTOM_UPLOAD_SCRIPT" /tmp/custom_script
    fi
  fi

  CUSTOM_UPLOAD_SCRIPT="/tmp/custom_script"
  chmod 775 "$CUSTOM_UPLOAD_SCRIPT"
  export CUSTOM_UPLOAD=1
fi

if [ -z "$TEST_BUILD" ]; then

  if [ $mega_check -ne 0 ]; then
    if [ -z "$MEGA_FOLDER_ID" ]; then
      error_message "MEGA_FOLDER_ID isn't set."
      exit 1
    fi

    if [ -z "$MEGA_DECRYPT_KEY" ]; then
      error_message "MEGA_DECRYPT_KEY isn't set."
      exit 1
    fi
  fi

  TEST_BUILD=0
fi

# Check if scp vars are all set if any mega variable is set
variables=(
  SCP_USERNAME
  SCP_HOST
  SCP_PATH
  SCP_LINK
  SCP_DEST
)
check_vars $variables
scp_check=$count

if [ "$scp_check" -eq 5 ]; then
  export SCP_UPLOAD=1

  # Check if private key exists for scp transfer, location is ~/.ssh/id_rsa
  if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    error_message "Private key doesn't exist for user buildkite-agent, transfer a valid private key to ~/.ssh/id_rsa"
    exit 1
  else
    # Check permissions and connection to host
    if [ ! -r "$HOME/.ssh/id_rsa" ]; then
      error_message "Private key can't be read by user buildkite-agent."
      exit 1
    fi

    # Check connection to server via public key auth
    echo 'ssh -i "$HOME/.ssh/id_rsa" -o BatchMode=yes -o ConnectTimeout=5 ${SCP_USERNAME}@${SCP_HOST}'
    ssh -i "$HOME/.ssh/id_rsa" -o BatchMode=yes -o ConnectTimeout=5 ${SCP_USERNAME}@${SCP_HOST} > /dev/null 2>&1
    ret=$?
    if [ $ret -gt 1 ]; then
      error_message "Failed to connect to '${SCP_HOST}' using username ${SCP_USERNAME}. Return code: $ret"
      exit 1
    fi

  fi
fi

if [ $new -eq 0 ]; then
  echo "--- Retrieving supplement tools and files :page_facing_up:"
fi

# Check and get user modifications either as a url or env string
cd "$CURRENT"
if [[ ! -z "$USER_MODIFICATIONS" ]]; then

  echo "Retrieving user modifications"
  regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
  if [[ $USER_MODIFICATIONS =~ $regex ]]
  then
    # Get url and save to local file
    echo "Downloading and saving $USER_MODIFICATIONS to '$CURRENT/user_modifications.sh'"
    wget $USER_MODIFICATIONS -O "$CURRENT/user_modifications.sh"
  else
    error_message "'$USER_MODIFICATIONS' isn't a valid url."
    exit 1
  fi

  chmod +x "$CURRENT/user_modifications.sh"
  chmod +x "$CURRENT/buildkite_logger.sh"
  export USER_MODS="$CURRENT/user_modifications.sh"
fi

# Override if modification file exists from buildkite stage
if [[ ! -z "$USER_MODS" ]]; then
  if [[ ! -f "$USER_MODS" ]]; then
    error_message "'$USER_MODS' doesnt exist."
    exit 1
  fi

  echo "Using '$USER_MODS' as modification script"
  chmod +x $USER_MODS
fi

# Run build
echo "--- Initializing build environment :parcel:"

# Check os
if [[ "$OSTYPE" == "darwin"* ]]; then
  export MACOS=1
fi

export BUILDKITE_LOGGER="$CURRENT/buildkite_logger.sh"
export ROM_PATCHER="$CURRENT/patcher.sh"
export TELEGRAM_BOT="$CURRENT/SendMessage.py"
export MEGA_UPLOADER="$CURRENT/upload.rb"
export SUPPLEMENTS="$CURRENT/../supplements/"
export PRELIMINARY_SETUP=1

"$(pwd)/../docker/build.sh"
error_exit "build script"
