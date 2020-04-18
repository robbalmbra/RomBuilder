#!/bin/bash

BOOT_LOGGING=0

# Check for local use, not using docker
if [ ! -z "$OUTPUT_DIR" ]; then
  BUILD_DIR="$OUTPUT_DIR"
else
  BUILD_DIR="/root"
fi

# Override for kite build for ccache in standard dir
if [[ ! -z "${BUILDKITE}" ]]; then
  echo "Overriding ccache to /ccache"
  export USE_CCACHE=1
  export CCACHE_DIR=/ccache
fi

length=${#BUILD_DIR}
last_char=${BUILD_DIR:length-1:1}
[[ $last_char == "/" ]] && BUILD_DIR=${BUILD_DIR:0:length-1}; :

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
      # Check for errors
      if [ $? -ne 0 ]; then
        echo "$0 - Init failed"
        exit 1
      fi
    else
      cd "$BUILD_DIR/rom/" && repo init -u $REPO -b $BRANCH --no-clone-bundle --depth=1
    fi
    # Pulling local manifests
    echo "Pulling local manifests ..."
    if [[ ! -z "${BUILDKITE}" ]]; then
      cd "$BUILD_DIR/rom/.repo/" && git clone https://github.com/robbalmbra/local_manifests.git -b android-10.0 --depth=1 > /dev/null 2>&1 && cd ..
      if [ $? -ne 0 ]; then
        echo "$0 - Cloning local manifest failed"
        exit 1
      fi
    else
      cd "$BUILD_DIR/rom/.repo/" && git clone https://github.com/robbalmbra/local_manifests.git -b android-10.0 --depth=1 && cd ..
    fi
  else
   # Clean if reprocessing
   make clean >/dev/null 2>&1
   make clobber >/dev/null 2>&1
  fi

  # Sync sources
  cd "$BUILD_DIR/rom/"
  echo "Syncing sources ..."
  
  if [[ ! -z "${BUILDKITE}" ]]; then
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --quiet > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "$0 - Sycing sources failed"
      exit 1
    fi
  else
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags --quiet
  fi

fi

if [ ! -f "$BUILD_DIR/rom/.lm" ]; then

  echo "Local modifications ..."

if [ $BOOT_LOGGING -eq 1 ]; then
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

# Execute specific user modifications and environment specific options if avaiable
if [ -f "$BUILD_DIR/user_modifications.sh" ]; then
  $BUILD_DIR/user_modifications.sh $BUILD_DIR 2> /dev/null
elif [ -f "$BUILD_DIR/../docker/user_modifications.sh" ]; then
  $BUILD_DIR/../docker/user_modifications.sh $BUILD_DIR 2> /dev/null
fi

fi

# Mark local modifications done
touch "$BUILD_DIR/rom/.lm"

# Build
echo "Environment setup ..."
cd "$BUILD_DIR/rom/"
. build/envsetup.sh > /dev/null 2>&1
export USE_CCACHE=1
ccache -M 70G > /dev/null 2>&1

# Iterate over builds
export IFS=","
for DEVICE in $DEVICES; do
  echo "Building $BUILD_NAME for $DEVICE ..."

  build_id="${BUILD_NAME}_$DEVICE-userdebug"
  lunch $build_id

  # Check for errors for lunch command
  if [ $? -ne 0 ]; then
    echo "$0 - Error, lunch command for $build_id returned non 0 error"
    exit 1
  fi

  mkdir -p "../logs/$DEVICE/"
  mka bacon -j$(nproc --all) 2>&1 | tee "../logs/$DEVICE/make_${DEVICE}_android10.txt"
  grep -iE 'crash|error|fail|fatal|unknown' "../logs/$DEVICE/make_${DEVICE}_android10.txt" 2>&1 | tee "../logs/$DEVICE/make_${$DEVICE}_errors_android10.txt"
done
echo "Builds complete"

# Upload firmware to mega
echo "Uploading to mega ..."
mega-login $MEGA_LOGIN $MEGA_PASSWORD > /dev/null 2>&1

shopt -s nocaseglob
DATE=$(date '+%d-%m-%y');
for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do
  echo "$0 - Uploading $(basename $ROM)"
  mega-put -c $ROM $UPLOAD_NAME/$DATE/
done
echo "Upload complete"

# Sleep forever
sleep infinity
