#!/bin/bash
# Intiailize script for docker within linux and macos - V1.1
# Alter settings with docker/.env for build

SKIP_PULL=0

set -a
. ../docker/.env
set +a

BUILD_FOLDER=$(pwd)/../files

variables=(
  CCACHE_DIR
  BUILD_NAME
  UPLOAD_NAME
  MEGA_USERNAME
  MEGA_PASSWORD
  DEVICES
  REPO
  BRANCH
)

# Check if required variables are set
quit=0
for variable in "${variables[@]}"
do
  if [[ -z ${!variable+x} ]]; then
    echo "$0 - Error, $variable isn't set.";
    break
  fi
done

# Create filestyle on macos based systems to avoid case issues
if [ ! -f "/etc/lsb-release" ]; then
  if [ ! -f "$BUILD_FOLDER/android.sparseimage" ]; then
    hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 125g "$BUILD_FOLDER/android.sparseimage"
  fi

  hdiutil detach "$BUILD_FOLDER/files/rom" > /dev/null 2>&1
  hdiutil attach "$BUILD_FOLDER/android.sparseimage" -mountpoint "$BUILD_FOLDER/rom/" > /dev/null 2>&1
fi

# Pull git on host rather than docker
if [ $SKIP_PULL -eq 1 ]; then
  # Check if repo needs to be reporocessed or initialized
  if [ ! -d "$BUILD_FOLDER/rom/.repo/" ]; then
    # Pull latest sources
    echo "Pulling sources ..."
    mkdir -p "$BUILD_FOLDER/rom/" > /dev/null 2>&1
    cd "$BUILD_FOLDER/rom/"; repo init -u $REPO -b $BRANCH --no-clone-bundle --depth=1

    # Pulling local manifests
    echo "Pulling local manifests ..."
    cd "$BUILD_FOLDER/rom/.repo/"; git clone https://github.com/robbalmbra/local_manifests.git -b android-10.0 --depth=1 && cd ..
  else
   # Clean if reprocessing
   make clean >/dev/null 2>&1
   make clobber >/dev/null 2>&1
  fi

  # Sync sources
  cd "$BUILD_FOLDER/rom/"
  echo "Syncing sources ..."
  repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --quiet
fi

# Run
cd "$BUILD_FOLDER/../docker/"
docker-compose down; docker-compose build; docker-compose up -d
