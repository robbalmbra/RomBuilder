#!/bin/bash

if [ -z "$BOOT_LOGGING" ]; then
  BOOT_LOGGING=0
fi

error_exit()
{
  ret="$?"
  if [ "$ret" != "0" ]; then
    echo "^^^ +++"
    echo "Error - '$1' failed ($ret) :bk-status-failed:"
    exit 1
  fi
}

log_setting()
{
  echo "Setting $1 to '$2'"
}

# Check for local use, not using docker
if [ ! -z "$OUTPUT_DIR" ]; then
  BUILD_DIR="$OUTPUT_DIR"
else
  BUILD_DIR="/root"
fi

# Persist rom through builds with buildkite and enable ccache
if [[ ! -z "${BUILDKITE}" ]]; then
  
  # Let the user choice to create unique build folders using environment vairables
  if [ ! -z "$UNIQUE_BUILDS" ]; then
    echo "Enabling unique build"
    mkdir -p "/tmp/build/$UPLOAD_NAME-$BUILDKITE_BUILD_NUMBER" > /dev/null 2>&1
    BUILD_DIR="/tmp/build/$UPLOAD_NAME-$BUILDKITE_BUILD_NUMBER"
  else
    mkdir -p "/tmp/build/$UPLOAD_NAME" > /dev/null 2>&1
    BUILD_DIR="/tmp/build/$UPLOAD_NAME"
  fi

  # Prompt to the user the location of the build
  log_setting "BUILD_DIR" "$BUILD_DIR"

  # Copy modifications and logger to build dir if exists
  if [ ! -z "$USER_MODS" ]; then
    echo "Copying '$USER_MODS' to '$BUILD_DIR/user_modifications.sh'"
    cp "$USER_MODS" "$BUILD_DIR/user_modifications.sh" > /dev/null 2>&1
    chmod +x "$BUILD_DIR/user_modifications.sh"
    rm -rf "$USER_MODS"
  fi
  
  # Copy build logger to build directory
  cp "$BUILDKITE_LOGGER" "$BUILD_DIR/buildkite_logger.sh" > /dev/null 2>&1
  chmod +x "$BUILD_DIR/buildkite_logger.sh"
  
  # Set logging rate if hasnt been defined
  if [[ -z "${LOGGING_RATE}" ]]; then
    # Default to 30 seconds if hasnt been set
    export LOGGING_RATE=30
  fi
  log_setting "LOGGING_RATE" "$LOGGING_RATE"
else
  # Prompt to the user the location of the build
  log_setting "BUILD_DIR" "$BUILD_DIR"
fi

length=${#BUILD_DIR}
last_char=${BUILD_DIR:length-1:1}
[[ $last_char == "/" ]] && BUILD_DIR=${BUILD_DIR:0:length-1}; :

# Jut upload mode
if [ ! -z "$JUST_UPLOAD" ]; then
  # Upload firmware to mega
  echo "--- Uploading to mega :rea:"
  mega-logout > /dev/null 2>&1
  mega-login $MEGA_USERNAME $MEGA_PASSWORD > /dev/null 2>&1
  error_exit "mega login"

  shopt -s nocaseglob
  DATE=$(date '+%d-%m-%y');
  for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do
    echo "Uploading $(basename $ROM)"
    mega-put -c $ROM ROMS/$UPLOAD_NAME/$DATE/
    error_exit "mega put"
    sleep 5
  done
  echo "Upload complete"
  exit 0
fi

# Flush logs
rm -rf "$BUILD_DIR/logs/"

# MACOS specific requirements for local usage
if [ ! -f "/etc/lsb-release" ] && [ ! -f "$BUILD_DIR/android.sparseimage" ]; then
  echo "Creating macos disk drive"
  # Create image due to macos case issues
  hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 150g "$BUILD_DIR/android.sparseimage" > /dev/null 2>&1

  # Check for errors
  if [ $? -ne 0 ]; then
    echo "^^^ +++"
    echo "Error, something went wrong in creating local image :bk-status-failed:"
    exit 1
  fi
fi

# Precautionary mount check for macos systems
if [ -f "$BUILD_DIR/android.sparseimage" ]; then
  echo "Mounting macos disk drive"
  hdiutil detach "$BUILD_DIR/rom/" > /dev/null 2>&1
  hdiutil attach "$BUILD_DIR/android.sparseimage" -mountpoint "$BUILD_DIR/rom/" > /dev/null 2>&1
fi

# Change to build folder
cd $BUILD_DIR

# Specify global vars
git config --global user.name robbbalmbra
git config --global user.email robbalmbra@gmail.com
git config --global color.ui true

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
    echo "^^^ +++"
    echo "$0 - Error, $variable isn't set :bk-status-failed:";
    quit=1
    break
  fi
done

# Exit on failure of required variables
if [ $quit -eq 1 ]; then
  exit 1
fi

# Override max cpus if asked to
if [ ! -z "$MAX_CPUS" ]; then
  log_setting "MAX_CPUS" "$MAX_CPUS"
  MAX_CPU="$MAX_CPUS"
else
  MAX_CPU="$(nproc --all)"
fi

# Use https for https repos
if [[ ! "$REPO" =~ "git://" ]]; then
  git config --global url."https://".insteadOf git://
fi

# Skip this if told to, git sync in host mode
if [ -n "$SKIP_PULL" ]; then
  echo "Using host git sync for build"

  # Repo check
  if [ ! -d "$BUILD_DIR/rom/.repo/" ]; then
    echo "^^^ +++"
    echo "Error failed to find repo in /rom/ :bk-status-failed:"
    exit 1
  fi

else

  # Check if repo needs to be reporocessed or initialized
  if [ ! -d "$BUILD_DIR/rom/.repo/" ]; then

    # Pull latest sources
    echo "Pulling sources"
    mkdir "$BUILD_DIR/rom/" > /dev/null 2>&1

    if [[ ! -z "${BUILDKITE}" ]]; then
      cd "$BUILD_DIR/rom/" && repo init -u $REPO -b $BRANCH --no-clone-bundle --depth=1 > /dev/null 2>&1
      error_exit "repo init"
    else
      cd "$BUILD_DIR/rom/" && repo init -u $REPO -b $BRANCH --no-clone-bundle --depth=1
      error_exit "repo init"
    fi

    # Pulling local manifests
    echo "Pulling local manifests"
    if [[ ! -z "${BUILDKITE}" ]]; then
      cd "$BUILD_DIR/rom/.repo/"; git clone "$LOCAL_REPO" -b "$LOCAL_BRANCH" --depth=1 > /dev/null 2>&1
      error_exit "clone local manifest"
      cd ..
    else
      cd "$BUILD_DIR/rom/.repo/"; git clone "$LOCAL_REPO" -b "$LOCAL_BRANCH" --depth=1
      error_exit "clone local manifest"
      cd ..
    fi
  else

   # Clean if reprocessing
   echo "Cleaning the build and reverting changes"
   cd "$BUILD_DIR/rom/"
   make clean >/dev/null 2>&1
   make clobber >/dev/null 2>&1
   
   # Pull original changes
   repo forall -c "git reset --hard" > /dev/null 2>&1
  fi

  # Sync sources
  cd "$BUILD_DIR/rom/"
  echo "Syncing sources to git repo"

  if [[ ! -z "${BUILDKITE}" ]]; then
    repo sync -d -f -c -j$MAX_CPU --force-sync --no-clone-bundle --no-tags --quiet > /dev/null 2>&1
    error_exit "repo sync"
  else
    repo sync -d -f -c -j$MAX_CPU --force-sync --no-clone-bundle --no-tags --quiet
    error_exit "repo sync"
  fi

fi

echo "Applying local modifications"

if [ $BOOT_LOGGING -eq 1 ]; then

  isLoggingInFile=$(cat "$BUILD_DIR/rom/device/samsung/universal9810-common/rootdir/etc/init.samsung.rc" | grep -c "/system/bin/logcat")
  if [ $isLoggingInFile -eq 0 ]; then

    echo "Enabling logging during boot"

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

  # Override path for sed if os is macOS
  if [ "$(uname)" == "Darwin" ]; then
    export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
  fi

  echo "Using user modification script"
  $BUILD_DIR/user_modifications.sh "$BUILD_DIR" 1> /dev/null
  error_exit "user modifications"
fi

# Build
echo "Environment setup"
cd "$BUILD_DIR/rom/"
. build/envsetup.sh > /dev/null 2>&1

# Set ccache and directory
log_setting "CCACHE" "$BUILD_DIR/ccache"
export CCACHE_DIR="$BUILD_DIR/ccache"
export USE_CCACHE=1

# Create directory
if [[ ! -d "$CCACHE_DIR" ]]; then
  mkdir "$CCACHE_DIR" > /dev/null 2>&1
fi

# Enable ccache with 50 gigabytes
ccache -M 50G > /dev/null 2>&1
error_exit "ccache"

# Check for any build parameters passed to script
BUILD_PARAMETERS="bacon"
LUNCH_DEBUG="userdebug"

if [ ! -z "$MKA_PARAMETERS" ]; then
  BUILD_PARAMETERS="$MKA_PARAMETERS"
fi

if [ ! -z "$LUNCH_VERSION" ]; then
  LUNCH_DEBUG="$LUNCH_VERSION"
fi

# Iterate over builds
export IFS=","
runonce=0
for DEVICE in $DEVICES; do
  echo "--- Building $DEVICE ($BUILD_NAME) :building_construction:"

  # Run lunch
  build_id="${BUILD_NAME}_$DEVICE-$LUNCH_DEBUG"
  if [[ ! -z "${BUILDKITE}" ]]; then
    lunch $build_id > /dev/null 2>&1
  else
    lunch $build_id
  fi
  error_exit "lunch"
  mkdir -p "../logs/$DEVICE/"

  # Run docs build once
  if [ "$runonce" -eq 0 ]; then
    #mka api-stubs-docs && mka hiddenapi-lists-docs && mka test-api-stubs-docs
    runonce=1
  fi

  # Flush log
  echo "" > ../logs/$DEVICE/make_${DEVICE}_android10.txt
  
  # Log to buildkite every N seconds
  if [[ ! -z "${BUILDKITE}" ]]; then
    $BUILD_DIR/buildkite_logger.sh "../logs/$DEVICE/make_${DEVICE}_android10.txt" "$LOGGING_RATE" &
  fi
  
  # Save start time of build
  makestart=`date +%s`

  # Run build
  if [[ ! -z "${BUILDKITE}" ]]; then
    mka $BUILD_PARAMETERS -j$MAX_CPU 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_android10.txt" > /dev/null 2>&1
  else
    mka $BUILD_PARAMETERS -j$MAX_CPU 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_android10.txt"
  fi
  
  # Upload error log to buildkite if any errors occur
  ret="$?"
  
  # Check for fail keyword to exit if build fails
  if grep -q "FAILED: " "../logs/$DEVICE/make_${DEVICE}_android10.txt"; then
    ret=1
  fi
  
  if [ "$ret" != "0" ]; then
    echo "^^^ +++"
    echo "Error - $DEVICE build failed ($ret) :bk-status-failed:"
    
    # Save folder for cd
    CURRENT=$(pwd)
    
    # Extract any errors from log if exist
    grep -iE 'crash|error|fail|fatal|unknown' "../logs/$DEVICE/make_${DEVICE}_android10.txt" 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_errors_android10.txt"

    # Log errors if exist
    if [[ ! -z "${BUILDKITE}" ]]; then
      if [ -f "../logs/$DEVICE/make_${DEVICE}_errors_android10.txt" ]; then
        cd "../logs/$DEVICE"
        buildkite-agent artifact upload "make_${DEVICE}_errors_android10.txt" > /dev/null 2>&1
        cd "$CURRENT"
      fi
    fi
    
    exit 1
    break
  else

    # Notify logger script to stop logging to buildkite
    touch ../logs/$DEVICE/.finished

    # Show time of build in minutes
    makeend=`date +%s`
    maketime=$(((makeend-makestart)/60))
    echo "$DEVICE was built in $maketime minutes"

    # Save folder for cd
    CURRENT=$(pwd)

    # Upload log to buildkite
    if [[ ! -z "${BUILDKITE}" ]]; then
      cd "../logs/$DEVICE"
      buildkite-agent artifact upload "make_${DEVICE}_android10.txt" > /dev/null 2>&1
      cd "$CURRENT"
    fi
  fi
done

# Upload firmware to mega
echo "--- Uploading to mega :rea:"
mega-logout > /dev/null 2>&1
mega-login $MEGA_USERNAME $MEGA_PASSWORD > /dev/null 2>&1
error_exit "mega login"

shopt -s nocaseglob
DATE=$(date '+%d-%m-%y');
for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do
  echo "Uploading $(basename $ROM)"
  mega-put -c $ROM ROMS/$UPLOAD_NAME/$DATE/
  error_exit "mega put"
  sleep 5
done
echo "Upload complete"
