#!/bin/bash

if [ -z "$BOOT_LOGGING" ]; then
  BOOT_LOGGING=0
fi

error_exit()
{
    ret="$?"
    if [ "$ret" != "0" ]; then
        echo "Error - '$1' failed with return code '$ret'"
        exit 1
    fi
}

# Check for local use, not using docker
if [ ! -z "$OUTPUT_DIR" ]; then
  BUILD_DIR="$OUTPUT_DIR"
else
  BUILD_DIR="/root"
fi

# Create and set CCACHE DIR if not set
if [ -z "$CCACHE_DIR" ]; then
  mkdir /root/ccache > /dev/null 2>&1
  export CCACHE_DIR=/root/ccache
fi

# Persist rom through builds with buildkite and enable ccache
if [[ ! -z "${BUILDKITE}" ]]; then
  mkdir /tmp/build > /dev/null 2>&1
  BUILD_DIR="/tmp/build"

  # Copy modifications and logger to build dir if exists
  if [ ! -z "$USER_MODS" ]; then
    cp "$USER_MODS" "$BUILD_DIR/user_modifications.sh" > /dev/null 2>&1
  fi      
  cp "$BUILDKITE_LOGGER" "$BUILD_DIR/buildkite_logger.sh" > /dev/null 2>&1

  echo "Setting CCACHE to '/tmp/build/ccache'"
  export USE_CCACHE=1
  export CCACHE_DIR=/tmp/build/ccache

  # Set logging rate if hasnt been defined within BUILDKITE
  if [[ -z "${LOGGING_RATE}" ]]; then
    # Default to 10 seconds if hasnt been set
    export LOGGING_RATE=15
  fi
  echo "Setting LOGGING_RATE to '$LOGGING_RATE'"
fi

if [[ ! -z "${CCACHE_DIR}" ]]; then
  mkdir "$CCACHE_DIR" > /dev/null 2>&1
fi

echo "Setting BUILD_DIR to '$BUILD_DIR'"

length=${#BUILD_DIR}
last_char=${BUILD_DIR:length-1:1}
[[ $last_char == "/" ]] && BUILD_DIR=${BUILD_DIR:0:length-1}; :

# Flush logs
rm -rf "$BUILD_DIR/logs/"

# macos specific requirements for local usage
if [ ! -f "/etc/lsb-release" ] && [ ! -f "$BUILD_DIR/android.sparseimage" ]; then
  # Create image due to macos case issues
  hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 150g "$BUILD_DIR/android.sparseimage" > /dev/null 2>&1

  # Check for errors
  if [ $? -ne 0 ]; then
    echo "$0 - Error, something went wrong in creating local image."
    exit 1
  fi
fi

# precautionary mount check for macos systems
if [ -f "$BUILD_DIR/android.sparseimage" ]; then
  hdiutil detach "$BUILD_DIR/rom/" > /dev/null 2>&1
  hdiutil attach "$BUILD_DIR/android.sparseimage" -mountpoint "$BUILD_DIR/rom/" > /dev/null 2>&1
fi

# Change to build folder
cd $BUILD_DIR

# Specify global vars
git config --global user.name robbbalmbra
git config --global user.email robbalmbra@gmail.com
git config --global color.ui true
git config --global url."https://".insteadOf git://

variables=(
  BUILD_NAME
  UPLOAD_NAME
  MEGA_USERNAME
  MEGA_PASSWORD
  DEVICES
  REPO
  BRANCH
  LOCAL_REPO
  LOCAL_BRANCH
)

# Check for required variables
quit=0
for variable in "${variables[@]}"
do
  if [[ -z ${!variable+x} ]]; then
    echo "$0 - Error, $variable isn't set.";
    quit=1
    break
  fi
done

if [ $quit -eq 1 ]; then
  exit 1
fi

# Skip this if told to, git sync in host mode
if [ -n "$SKIP_PULL" ]; then
  echo "$0 - Using host git sync for build"

  # Repo check
  if [ ! -d "$BUILD_DIR/rom/.repo/" ]; then
    echo "$0 - Error failed to find repo in /rom/"
    exit 1
  fi

else

  # Check if repo needs to be reporocessed or initialized
  if [ ! -d "$BUILD_DIR/rom/.repo/" ]; then
    # Pull latest sources
    echo "Pulling sources ..."
    mkdir "$BUILD_DIR/rom/" > /dev/null 2>&1

    if [[ ! -z "${BUILDKITE}" ]]; then
      cd "$BUILD_DIR/rom/" && repo init -u $REPO -b $BRANCH --no-clone-bundle --depth=1 > /dev/null 2>&1
      error_exit "repo init"
    else
      cd "$BUILD_DIR/rom/" && repo init -u $REPO -b $BRANCH --no-clone-bundle --depth=1
      error_exit "repo init"
    fi

    # Pulling local manifests
    echo "Pulling local manifests ..."
    if [[ ! -z "${BUILDKITE}" ]]; then
      cd "$BUILD_DIR/rom/.repo/" && git clone "$LOCAL_REPO" -b "$LOCAL_BRANCH" --depth=1 > /dev/null 2>&1
      error_exit "clone local manifest"
      cd ..
    else
      cd "$BUILD_DIR/rom/.repo/" && git clone "$LOCAL_REPO" -b "$LOCAL_BRANCH" --depth=1
      error_exit "clone local manifest"
      cd ..
    fi
  else
   # Clean if reprocessing
   echo "Cleaning build ..."
   cd "$BUILD_DIR/rom/"
   make clean >/dev/null 2>&1
   make clobber >/dev/null 2>&1
  fi

  # Sync sources
  cd "$BUILD_DIR/rom/"
  echo "Syncing sources ..."

  if [[ ! -z "${BUILDKITE}" ]]; then
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --quiet > /dev/null 2>&1
    error_exit "repo sync"
  else
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --quiet
    error_exit "repo sync"
  fi

fi

echo "Local modifications ..."

if [ $BOOT_LOGGING -eq 1 ]; then

  isLoggingInFile=$(cat "$BUILD_DIR/rom/device/samsung/universal9810-common/rootdir/etc/init.samsung.rc" | grep -c "/system/bin/logcat")
  if [ $isLoggingInFile -eq 0 ]; then

  # Enable logging via logcat
cat >> "$BUILD_DIR/rom/device/samsung/universal9810-common/rootdir/etc/init.samsung.rc" << EOL

service logger /system/bin/logcat -b all -D -f /cache/boot_log.txt
    # Initialize
    class main
    user root
    group root system
    disabled
    oneshot

on post-fs-data
    # Clear existing log and start the service
    rm /cache/boot_log.txt
    start logger

on property:sys.boot_completed=1
    # Stop the logger service
    stop logger
EOL
  fi
fi

# Execute specific user modifications and environment specific options if avaiable
if [ -f "$BUILD_DIR/user_modifications.sh" ]; then
  echo "Using user modification script"
  $BUILD_DIR/user_modifications.sh $BUILD_DIR 1> /dev/null
  error_exit "user modifications"
fi

# Build
echo "Environment setup ..."
cd "$BUILD_DIR/rom/"
. build/envsetup.sh > /dev/null 2>&1
export USE_CCACHE=1
ccache -M 50G > /dev/null 2>&1
error_exit "ccache"

# Iterate over builds
export IFS=","
for DEVICE in $DEVICES; do
  echo "Building $BUILD_NAME for $DEVICE ..."

  # Run lunch
  build_id="${BUILD_NAME}_$DEVICE-userdebug"
  if [[ ! -z "${BUILDKITE}" ]]; then
    lunch $build_id > /dev/null 2>&1
  else
    lunch $build_id
  fi
  error_exit "lunch"
  mkdir -p "../logs/$DEVICE/"

  # Flush log
  echo "" > ../logs/$DEVICE/make_${DEVICE}_android10.txt
  
  # Log to buildkite
  if [[ ! -z "${BUILDKITE}" ]]; then
    $BUILD_DIR/buildkite_logger.sh "../logs/$DEVICE/make_${DEVICE}_android10.txt" "$LOGGING_RATE" &
  fi

  # Run build
  if [[ ! -z "${BUILDKITE}" ]]; then
    mka bacon -j$(nproc --all) 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_android10.txt" > /dev/null 2>&1
  else
    mka bacon -j$(nproc --all) 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_android10.txt"
  fi
  
  echo "BUILD_COMPLETE" > ../logs/$DEVICE/make_${DEVICE}_android10.txt

  # Upload log to buildkite
  if [[ ! -z "${BUILDKITE}" ]]; then
    buildkite-agent artifact upload "../logs/$DEVICE/make_${DEVICE}_android10.txt" > /dev/null 2>&1
  fi

  # Upload error log to buildkite if any errors occur
  ret="$?"
  if [ "$ret" != "0" ]; then
    echo "Error - '$1' failed with return code '$ret'"

    # Extract any errors from log if exist
    grep -iE 'crash|error|fail|fatal|unknown' "../logs/$DEVICE/make_${DEVICE}_android10.txt" 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_errors_android10.txt"

    # Log errors if exist
    if [[ ! -z "${BUILDKITE}" ]]; then
      if [ -f "../logs/$DEVICE/make_${DEVICE}_errors_android10.txt" ]; then
        buildkite-agent artifact upload "../logs/$DEVICE/make_${DEVICE}_errors_android10.txt" > /dev/null 2>&1
      fi
    fi

    exit 1
    break
  fi
done

# Upload firmware to mega
echo "Uploading to mega ..."
mega-login $MEGA_LOGIN $MEGA_PASSWORD > /dev/null 2>&1
error_exit "mega login"

shopt -s nocaseglob
DATE=$(date '+%d-%m-%y');
for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do
  echo "$0 - Uploading $(basename $ROM)"
  mega-put -c $ROM $UPLOAD_NAME/$DATE/
  error_exit "mega put"
done
echo "Upload complete"

# Sleep forever
sleep infinity
