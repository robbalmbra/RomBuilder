#!/bin/bash

if [ -z "$PRELIMINARY_SETUP" ]; then
  echo "Error - Build script shouldn't be called directly, please run scripts/start-local.sh"
  exit 1
fi

if [ -z "$BUILD_LANG" ]; then
  export BUILD_LANG="en"
fi

if [ -z "$SKIP_API_DOCS" ]; then
  export SKIP_API_DOCS=0
fi

if [ -z "$DEBUG" ]; then
  DEBUG=false
else
  DEBUG=true
fi

run() {
        if $DEBUG; then
                v=$(exec 2>&1 && set -x && set -- "$@")
                echo "#${v#*--}"
                "$@"
        else
                "$@" >/dev/null 2>&1
        fi
}

if [ -z "$MAGISK_VERSION" ]; then
  MAGISK_VERSION="20.4"
fi

if [ -z "$MACOS" ]; then
  MACOS=0
fi

if [ -z "$SKIP_BUILD" ]; then
  SKIP_BUILD=0
fi

if [ -z "$PROCESS_OTA" ]; then
  PROCESS_OTA=0
fi

if [ -z "$TEST_BUILD" ]; then
  TEST_BUILD=0
fi

# Magisk enable within rom, default is enabled
if [ -z "$MAGISK_IN_BUILD" ]; then
  export MAGISK_IN_BUILD=1
fi

# Default is on
if [ -z "$LIBEXYNOS_CAMERA" ]; then
  export LIBEXYNOS_CAMERA=1
fi

ota_found=0

error_exit()
{
  ret="$?"
  if [ "$ret" != "0" ]; then
    echo "^^^ +++"
    if [[ $BUILD_LANG == "it" ]]; then
      echo "Errore - '$1' non riuscito ($ret) :exclamation:"
    else
      echo "Error - '$1' failed ($ret) :exclamation:"
    fi
    exit 1
  fi
}

log_setting()
{
  if [[ $BUILD_LANG == "it" ]]; then
    echo "Impostazione di $1 a '$2'"
  else
    echo "Setting $1 to '$2'"
  fi
}

# Check for local use, not using docker
if [ ! -z "$OUTPUT_DIR" ]; then
  BUILD_DIR="$OUTPUT_DIR"
else
  BUILD_DIR="/root"
fi

# Persist rom through builds with buildkite and enable ccache
if [[ ! -z "${BUILDKITE}" ]]; then

  # Output directory override
  if [ ! -z "$CUSTOM_OUTPUT_DIR" ]; then
    mkdir -p "$CUSTOM_OUTPUT_DIR/build/$UPLOAD_NAME" > /dev/null 2>&1
    BUILD_DIR="$CUSTOM_OUTPUT_DIR/build/$UPLOAD_NAME"
  else
    if [[ "$MACOS" == 1 ]]; then
      mkdir -p "/usr/local/var/buildkite-agent/build/$UPLOAD_NAME" > /dev/null 2>&1
      BUILD_DIR="/usr/local/var/buildkite-agent/build/$UPLOAD_NAME"
    else
      mkdir -p "/var/lib/buildkite-agent/build/$UPLOAD_NAME" > /dev/null 2>&1
      BUILD_DIR="/var/lib/buildkite-agent/build/$UPLOAD_NAME"
    fi
  fi

  # Create scripts directory in BUILD_DIR
  mkdir -p "$BUILD_DIR/scripts/"

  # Copy supplements to local folder
  cp -R "$SUPPLEMENTS" "$BUILD_DIR/"

  # Copy telegram bot script to local folder
  cp "$TELEGRAM_BOT" "$BUILD_DIR/scripts/SendMessage.py" > /dev/null 2>&1

  # Prompt to the user the location of the build
  log_setting "BUILD_DIR" "$BUILD_DIR"

  # Show debug setting
  if [[ $BUILD_LANG == "it" ]]; then
    log_setting "DEBUG" "falso"
  else
    log_setting "DEBUG" "$DEBUG"
  fi
  
  # Copy modifications and logger to build dir if exists
  if [ ! -z "$USER_MODS" ]; then
    if [[ $BUILD_LANG == "it" ]]; then
      echo "Copia di '$USER_MODS' in '$BUILD_DIR/scripts/user_modifications.sh'"
    else
      echo "Copying '$USER_MODS' to '$BUILD_DIR/scripts/user_modifications.sh'"
    fi

    cp "$USER_MODS" "$BUILD_DIR/scripts/user_modifications.sh" > /dev/null 2>&1
    chmod +x "$BUILD_DIR/scripts/user_modifications.sh"
    rm -rf "$USER_MODS"
  fi

  # Copy build logger to build directory
  cp "$BUILDKITE_LOGGER" "$BUILD_DIR/scripts/buildkite_logger.sh" > /dev/null 2>&1
  chmod +x "$BUILD_DIR/scripts/buildkite_logger.sh"

  # Copy magisk patcher to build directory
  cp "$ROM_PATCHER" "$BUILD_DIR/scripts/patcher.sh" > /dev/null 2>&1
  chmod +x "$BUILD_DIR/scripts/patcher.sh" 

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

# Just process ota
if [ ! -z "$JUST_PROCESS_OTA" ]; then

  # Create git for ota folder
  rm -rf "$BUILD_DIR/ota" > /dev/null 2>&1
  mkdir "$BUILD_DIR/ota" > /dev/null 2>&1
  cd "$BUILD_DIR/ota"

  # Assign git repo
  git init > /dev/null 2>&1
  git remote add origin git@github.com:robbalmbra/OTA.git > /dev/null 2>&1
  git pull -f origin $UPLOAD_NAME > /dev/null 2>&1
  git branch --set-upstream-to=origin/$UPLOAD_NAME master

  # Run handler
  $BUILD_DIR/supplements/ota/main.sh "$BUILD_DIR/rom" "$BUILD_DIR/ota" "$UPLOAD_NAME" "$BUILD_DIR/supplements/ota"
  exit 0
fi

# Jut upload mode
if [ ! -z "$JUST_UPLOAD" ]; then
  # Upload firmware to mega
  if [[ $BUILD_LANG == "it" ]]; then
    echo "--- Caricamento su mega :rea:"
  else
    echo "--- Uploading to mega :rea:"
  fi

  mega-logout > /dev/null 2>&1
  mega-login $MEGA_USERNAME $MEGA_PASSWORD > /dev/null 2>&1
  error_exit "mega login"

  shopt -s nocaseglob
  DATE=$(date '+%d-%m-%y');
  for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do
    if [[ $BUILD_LANG == "it" ]]; then
      echo "Caricamento $(basename $ROM)"
    else
      echo "Uploading $(basename $ROM)"
    fi

    mega-put -c $ROM ROMS/$UPLOAD_NAME/$DATE/
    error_exit "mega put"
    sleep 15
  done
  if [[ $BUILD_LANG == "it" ]]; then
    echo "Caricamento completato"
  else
    echo "Upload complete"
  fi
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
    echo "Error, something went wrong in creating local image :exclamation:"
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
    if [[ $BUILD_LANG == "it" ]]; then
      echo "$0 - Errore, $variable non è impostato :exclamation:";
    else
      echo "$0 - Error, $variable isn't set :exclamation:";
    fi
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

# Skip if told to
if [ "$SKIP_BUILD" -eq 0 ]; then

  # Check if repo needs to be reporocessed or initialized
  if [ ! -d "$BUILD_DIR/rom/.repo/" ]; then

    # Pull latest sources
    if [[ $BUILD_LANG == "it" ]]; then
      echo "Recuperando le fonti"
    else
      echo "Pulling sources"
    fi

    mkdir "$BUILD_DIR/rom/" > /dev/null 2>&1

    INIT_OPTIONS="--no-clone-bundle --depth=1"
    if [[ ! -z $DATE_REVERT ]]; then
      INIT_OPTIONS=""
    fi

    cd "$BUILD_DIR/rom/"
    run repo init -u $REPO -b $BRANCH $INIT_OPTIONS
    error_exit "repo init"

    # Pulling local manifests
    if [[ $BUILD_LANG == "it" ]]; then
      echo "Recuperando i manifest locali"
    else
      echo "Pulling local manifests"
    fi

    cd "$BUILD_DIR/rom/.repo/"
    run git clone "$LOCAL_REPO" -b "$LOCAL_BRANCH" --depth=1
    error_exit "clone local manifest"
    cd ..
  else

   # Clean if reprocessing
   if [[ $BUILD_LANG == "it" ]]; then
     echo "Pulizia della build e ripristino delle modifiche"
   else
     echo "Cleaning the build and reverting changes"
   fi

   cd "$BUILD_DIR/rom/"
   make clean >/dev/null 2>&1
   make clobber >/dev/null 2>&1

   # Pull original changes
   repo forall -c "git reset --hard" > /dev/null 2>&1
  fi

  # Sync sources
  cd "$BUILD_DIR/rom/"

  if [[ $BUILD_LANG == "it" ]]; then
    echo "Sincronizzazione delle fonti dal repository"
  else
    echo "Syncing sources from repo"
  fi

  # Override for date revert
  SYNC_OPTIONS="--no-clone-bundle --no-tags"
  if [[ ! -z $DATE_REVERT ]]; then
    SYNC_OPTIONS=""
  fi

  run repo sync -d -f -c -j$MAX_CPU --force-sync --quiet $SYNC_OPTIONS
  error_exit "repo sync"

  if [[ ! -z $DATE_REVERT ]]; then
    echo "Reverting repo to date '$DATE_REVERT'"
    repo forall -c 'git checkout `git rev-list -n1 --before="$DATE_REVERT" HEAD`' > /dev/null 2>&1
  fi
  
  # Run extra commands after sync if any
  if [[ ! -z "$EXTRA_COMMANDS" ]]; then
    eval $EXTRA_COMMANDS > /dev/null
  fi

  if [[ $BUILD_LANG == "it" ]]; then
    echo "Applicazione di modifiche locali"
  else
    echo "Applying local modifications"
  fi

  # Check for props environment variable to add to build props
  if [ ! -z "$ADDITIONAL_PROPS" ]; then
    export IFS=";"
    check=0
    additional_props_string=""
    for prop in $ADDITIONAL_PROPS; do

      if [[ $BUILD_LANG == "it" ]]; then
        echo "Aggiunta di ulteriore prop '$prop' a product_prop.mk"
      else
        echo "Adding additional prop '$prop' to product_prop.mk"
      fi

      if [[ $check == 0 ]]; then
        check=1
      else
        additional_props_string+=" \\\\\n"
      fi

      additional_props_string+="    ${prop}"
    done

    # Append to device props
    echo -e "\nPRODUCT_PRODUCT_PROPERTIES += \\\\\n$additional_props_string" >> $BUILD_DIR/rom/device/samsung/universal9810-common/product_prop.mk
  fi

  # Execute specific user modifications and environment specific options if avaiable
  if [ -f "$BUILD_DIR/scripts/user_modifications.sh" ]; then

    # Override path for sed if os is macOS
    if [ "$(uname)" == "Darwin" ]; then
      export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
    fi

    if [[ $BUILD_LANG == "it" ]]; then
      echo "Utilizzo dello script di modifica dell'utente"
    else
      echo "Using user modification script"
    fi

    $BUILD_DIR/scripts/user_modifications.sh "$BUILD_DIR" 1> /dev/null
    error_exit "user modifications"
  fi

  # Override ota url for each device even though build may not use the url
  if [ "$PROCESS_OTA" -eq 1 ]; then
    echo "Overriding OTA"
    export IFS=","
    for DEVICE in $DEVICES; do
      DEVICE_FILE="$BUILD_DIR/rom/device/samsung/$DEVICE/${BUILD_NAME}_$DEVICE.mk"

      # Remove any ota strings
      sed -i '/# OTA/,+2d' $DEVICE_FILE

      # Dynamically create url and save to device make file for OTA apk
      echo -e "# OTA\nPRODUCT_PROPERTY_OVERRIDES += \\\\\n    lineage.updater.uri=https://raw.githubusercontent.com/robbalmbra/OTA/$UPLOAD_NAME/$DEVICE.json" >> $DEVICE_FILE

      if [ ! -z "$ADDITIONAL_PROPS" ]; then
        echo -e "\n\nPRODUCT_PROPERTY_OVERRIDES += \\\\\n$additional_props_string" >> $DEVICE_FILE
      fi
    done
  fi

  # Only apply modifications and save device trees
  if [ ! -z "$PRODUCE_DEVICE_TREES" ]; then
    if [[ $BUILD_LANG == "it" ]]; then
      echo "Avviso - alberi dei dispositivi salvati in $BUILD_DIR/rom/device/samsung"
    else
      echo "Warning - Device trees saved to $BUILD_DIR/rom/device/samsung"
    fi
    exit 0
  fi

  if [ "$PROCESS_OTA" -eq 1 ]; then

    # Override alterntive url in string.xml in updater git repo
    fileDir=("packages/apps/Updates" "packages/apps/Updater")

    # Iterate over files
    for strFile in "${fileDir[@]}"; do

      string_file="$BUILD_DIR/rom/$strFile/res/values/strings.xml"
      constants_file="$BUILD_DIR/rom/$strFile/src/org/*/ota/misc/Constants.java"

      # Check if strings file exists
      if [ -f "$string_file" ]; then
        sed -i "s/\(<string name=\"updater_server_url\" translatable=\"false\">\)[^<]*\(<\/string>\)/\1https:\/\/raw.githubusercontent.com\/robbalmbra\/OTA\/$UPLOAD_NAME\/{device}.json\2/g" "$string_file"
        ota_found=1
      fi

      # Check if consts file exists for other builds
      if compgen -G "$constants_file" > /dev/null; then

        # Get folder name in org directory
        org_folder="$BUILD_DIR/rom/$strFile/src/org/"
        org=$(ls -lA $org_folder | awk -F':[0-9]* ' '/:/{print $2}' 2> /dev/null)
        constants_file="$BUILD_DIR/rom/$strFile/src/org/$org/ota/misc/Constants.java"

        # Remove urls for zip and changelog
        OTA_URL="https://raw.githubusercontent.com/robbalmbra/OTA/$UPLOAD_NAME/%s.json"
        CH_URL="https://raw.githubusercontent.com/robbalmbra/OTA/$UPLOAD_NAME/changelogs/%s/%s.txt"
        sed -i 's;static final String OTA_URL = .*;static final String OTA_URL = \"'"$OTA_URL\"\;"';' $constants_file
        sed -i 's;static final String DOWNLOAD_WEBPAGE_URL = .*;static final String DOWNLOAD_WEBPAGE_URL = \"'"$CH_URL\"\;"';' $constants_file
        ota_found=1
      fi

    done

  fi


  # Build
  if [[ $BUILD_LANG == "it" ]]; then
    echo "Impostazione dell'ambiente"
  else
    echo "Environment setup"
  fi

  # Set ccache and directory
  export USE_CCACHE=1

  if [ ! -z "$CUSTOM_CCACHE_DIR" ]; then
    export CCACHE_DIR="$CUSTOM_CCACHE_DIR"
  else
    export CCACHE_DIR="/var/lib/buildkite-agent/ccache"
  fi

  log_setting "CCACHE" "$CCACHE_DIR"

  # Create directory
  if [[ ! -d "$CCACHE_DIR" ]]; then
    mkdir "$CCACHE_DIR" > /dev/null 2>&1
  fi

  # Enable ccache with 50 gigabytes if not overrided
  if [ -z "$CCACHE_SIZE" ]; then
    ccache -M "50G" > /dev/null 2>&1
    error_exit "ccache"
    log_setting "CCACHE_SIZE" "50G"
  else
    ccache -M "${CCACHE_SIZE}G" > /dev/null 2>&1
    error_exit "ccache"
    log_setting "CCACHE_SIZE" "${CCACHE_SIZE}G"
  fi

  # Run env script
  cd "$BUILD_DIR/rom/"
  . build/envsetup.sh > /dev/null 2>&1
  
  # Check for any build parameters passed to script
  BUILD_PARAMETERS="bacon"
  LUNCH_DEBUG="userdebug"

  # Check for mka parameters, can be empty 
  if [ -n "${MKA_PARAMETERS+1}" ]; then
    BUILD_PARAMETERS="$MKA_PARAMETERS"
  fi

  if [ ! -z "$LUNCH_VERSION" ]; then
    LUNCH_DEBUG="$LUNCH_VERSION"
  fi

  # Iterate over builds
  export IFS=","
  runonce=0
  for DEVICE in $DEVICES; do

    cd "$BUILD_DIR/rom/"

    if [ "$runonce" -ne 0 ]; then
      # Clean between builds
      echo "Cleaning build"
      make installclean > /dev/null 2>&1
    fi
    
    if [[ $BUILD_LANG == "it" ]]; then
      echo "--- Creazione di $DEVICE ($BUILD_NAME) :building_construction:"
    else
      echo "--- Building $DEVICE ($BUILD_NAME) :building_construction:"
    fi

    # Run lunch
    build_id="${BUILD_NAME}_$DEVICE"
    build_id+="-${LUNCH_DEBUG}"
    if [[ ! -z "${CUSTOM_LUNCH_COMMAND}" ]]; then
      eval "${CUSTOM_LUNCH_COMMAND}" "$build_id" > /dev/null 2>&1
    else
      echo "lunch $build_id"
      lunch "$build_id" > /dev/null 2>&1
    fi

    error_exit "lunch"
    mkdir -p "$BUILD_DIR/logs/$DEVICE/"

    # Flush log
    echo "" > $BUILD_DIR/logs/$DEVICE/make_${DEVICE}_android10.txt

    # Log to buildkite every N seconds
    if [[ ! -z "${BUILDKITE}" ]]; then
      $BUILD_DIR/scripts/buildkite_logger.sh "$BUILD_DIR/logs/$DEVICE/make_${DEVICE}_android10.txt" "$LOGGING_RATE" &
    fi

    # Run docs build once
    if [ "$runonce" -eq 0 ]; then

      if [[ $SKIP_API_DOCS == 0 ]]; then
      
        if [[ $BUILD_LANG == "it" ]]; then
          echo "Generazione di documenti"
        else
          echo "Generating docs"
        fi

        run mka -j$MAX_CPU api-stubs-docs
        run mka -j$MAX_CPU hiddenapi-lists-docs
        run mka -j$MAX_CPU test-api-stubs-docs
      fi
      runonce=1
    fi

    # Save start time of build
    makestart=`date +%s`

    # Make sure script is running in rom directory
    cd $BUILD_DIR/rom/

    # Run build
    if [[ ! -z "${BUILDKITE}" ]]; then
      if [[ ! -z "$CUSTOM_MKA_COMMAND" ]]; then
        custom_text="$CUSTOM_MKA_COMMAND"
        custom_text=${custom_text/\{device\}/$DEVICE}
        custom_text=${custom_text/\{user_debug\}/$LUNCH_DEBUG}
        eval "$custom_text" > /dev/null 2>&1
      else
        mka $BUILD_PARAMETERS -j$MAX_CPU 2>&1 | tee "$BUILD_DIR/logs/$DEVICE/make_${DEVICE}_android10.txt" > /dev/null 2>&1
      fi
    fi

    # Upload error log to buildkite if any errors occur
    ret="$?"

    # Notify logger script to stop logging to buildkite
    touch "$BUILD_DIR/logs/$DEVICE/.finished"

    # Check for fail keyword to exit if build fails
    if grep -q "FAILED: " "$BUILD_DIR/logs/$DEVICE/make_${DEVICE}_android10.txt"; then
      ret=1
    fi

    if [ "$ret" != "0" ]; then
      echo "^^^ +++"

      if [[ $BUILD_LANG == "it" ]]; then
        echo "Errore - Creazione di $DEVICE non riuscita ($ret) :bk-status-failed:"
      else
        echo "Error - $DEVICE build failed ($ret) :bk-status-failed:"
      fi

      # Save folder for cd
      CURRENT=$(pwd)

      # Extract any errors from log if exist
      grep -iE 'crash|error|fail|fatal|unknown' "$BUILD_DIR/logs/$DEVICE/make_${DEVICE}_android10.txt" 2>&1 | tee "$BUILD_DIR/logs/$DEVICE/make_${DEVICE}_errors_android10.txt"

      # Log errors if exist
      if [[ ! -z "${BUILDKITE}" ]]; then
        if [ -f "$BUILD_DIR/logs/$DEVICE/make_${DEVICE}_errors_android10.txt" ]; then
          cd "$BUILD_DIR/logs/$DEVICE"
          buildkite-agent artifact upload "make_${DEVICE}_errors_android10.txt" > /dev/null 2>&1
          buildkite-agent artifact upload "make_${DEVICE}_android10.txt" > /dev/null 2>&1
          cd "$CURRENT"
        fi
      fi

      exit 1
      break
    else

      # Show time of build in minutes
      makeend=`date +%s`
      maketime=$(((makeend-makestart)/60))

      if [[ $BUILD_LANG == "it" ]]; then
        echo "Successo: $DEVICE è stato creato in $maketime minuti"
      else
        echo "Success - $DEVICE was built in $maketime minutes"
      fi

      # Save folder for cd
      CURRENT=$(pwd)

      # Upload log to buildkite
      if [[ ! -z "${BUILDKITE}" ]]; then
        cd "$BUILD_DIR/logs/$DEVICE"
        buildkite-agent artifact upload "make_${DEVICE}_android10.txt" > /dev/null 2>&1
        cd "$CURRENT"
      fi
    fi
  done

  # Patch magisk
  mkdir -p /tmp/rom-magisk/
  if [[ $BUILD_LANG == "it" ]]; then
    echo "--- Patch per includere extra all'interno della ROM"
  else
    echo "--- Patching to include extras within ROM"
  fi

  for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do

    # Skip if zip has -ota- in zip
    if [[ $ROM == *"-ota-"* ]]; then
      continue
    fi

    PRODUCT="$(basename "$(dirname "$ROM")")"
    $BUILD_DIR/scripts/patcher.sh $ROM /tmp/rom-magisk $MAGISK_VERSION $PRODUCT $BUILD_DIR $MAGISK_IN_BUILD
    error_exit "patches"
    file_name=$(basename "$ROM")
    mv /tmp/rom-magisk/$file_name $ROM
  done

else
  echo "Skipping build phase"
  ota_found=1
fi

# Upload firmware to mega
if [ "$TEST_BUILD" -eq 0 ]; then

  if [[ $BUILD_LANG == "it" ]]; then
    echo "--- Caricamento su mega :rea:"
  else
    echo "--- Uploading to mega :rea:"
  fi

  mega-logout > /dev/null 2>&1
  mega-login $MEGA_USERNAME $MEGA_PASSWORD > /dev/null 2>&1
  error_exit "mega login"

  shopt -s nocaseglob
  DATE=$(date '+%d-%m-%y');
  rom_count=0
  for ROM in $BUILD_DIR/rom/out/target/product/*/*.zip; do

    # Skip if zip has -ota- in zip
    if [[ $ROM == *"-ota-"* ]]; then
      continue
    fi

    if [[ $BUILD_LANG == "it" ]]; then
      echo "Caricamento $(basename $ROM)"
    else
      echo "Uploading $(basename $ROM)"
    fi

    # Get rom size for telegram group
    file_size=$(ls -lh "$ROM" | awk '{print $5}')

    # Upload
    mega-put -c $ROM ROMS/$UPLOAD_NAME/$DATE/
    error_exit "mega put"

    # Create md5 of file
    file_md5=`md5sum ${ROM} | awk '{ print $1 }'`
    device_name="$(basename "$(dirname "$ROM")")"
    echo "$device_name - $file_md5" >> "$BUILD_DIR/.hashes"
    sleep 15
    ((rom_count=rom_count+1))
  done

  if [[ $BUILD_LANG == "it" ]]; then
    echo "Caricamento completato"
  else
    echo "Upload complete"
  fi

fi

# Launch OTA handler script
if [[ "$PROCESS_OTA" == 1 ]]; then
  if [[ $BUILD_LANG == "it" ]]; then
    echo "Esecuzione di script di generazione OTA"
  else
    echo "--- Running OTA generation script"
  fi

  # Create git for ota folder
  rm -rf "$BUILD_DIR/ota" > /dev/null 2>&1
  mkdir "$BUILD_DIR/ota" > /dev/null 2>&1
  cd "$BUILD_DIR/ota"

  git init > /dev/null 2>&1
  git remote add origin git@github.com:robbalmbra/OTA.git > /dev/null 2>&1
  git pull -f origin $UPLOAD_NAME > /dev/null 2>&1
  git branch --set-upstream-to=origin/$UPLOAD_NAME master > /dev/null 2>&1

  $BUILD_DIR/supplements/ota/main.sh "$BUILD_DIR/rom" "$BUILD_DIR/ota" "$UPLOAD_NAME" "$BUILD_DIR/supplements/ota"
fi

# Deploy message in broadcast group only for non test builds
if [ "$TEST_BUILD" -eq 0 ]; then
  if [ ! -z "$TELEGRAM_TOKEN" ]; then
    if [[ "$rom_count" -gt 0 ]]; then
      # Send message
      if [[ $BUILD_LANG == "it" ]]; then
        echo "Invio di un messaggio al gruppo di trasmissione"
      else
        echo "Sending message to broadcast group"
      fi
      python3 "$BUILD_DIR/scripts/SendMessage.py" "$UPLOAD_NAME" "$MEGA_FOLDER_ID" "ten" "$file_size" changelog.txt notes.txt "$MEGA_DECRYPT_KEY" "$TELEGRAM_TOKEN" "$TELEGRAM_GROUP" "$BUILD_DIR/.hashes" "$AUTHORS"
    fi
  fi
fi
