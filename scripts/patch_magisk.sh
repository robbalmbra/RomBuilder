#!/bin/bash

# Patches magisk into updater-script on selected rom 

get_latest_release() {
  magisk_url=$(curl --silent "https://api.github.com/repos/topjohnwu/Magisk/tags" | jq -r '.[0].zipball_url')
}

if [ $# -lt 2 ]; then
  echo "USAGE: [ROM FILE] [ROM FOLDER OUT]"
  exit 1
fi

rom_file_in=$1
rom_folder_out=$2

# Error checking

if [[ $rom_file_in != *.zip ]]; then
  echo "Error - ROM FILE is invalid"
  exit 2
fi

if [ ! -f $rom_file_in ]; then
  echo "Error - ROM FILE doesn't exist"
  exit 3
fi

if [ ! -d $rom_folder_out ]; then
  echo "Error - ROM FOLDER OUT doesn't exist"
  exit 4
fi

file_name=$(basename $rom_file_in)
echo "Adding magisk to $file_name"
WORK_DIR=`mktemp -d`

# Extract zip to folder
unzip $rom_file_in -d $WORK_DIR > /dev/null 2>&1

# Add magisk to updater script
update_script="$WORK_DIR/META-INF/com/google/android/updater-script"

cat <<EOT >> $update_script
ui_print("-- Installing: Magisk");
package_extract_dir("META-INF/ADD-ONS/Magisk", "/tmp/Magisk");
run_program("/sbin/busybox", "unzip", "/tmp/Magisk/Magisk.zip", "META-INF/com/google/android/*", "-d", "/tmp/Magisk");
run_program("/sbin/busybox", "sh", "/tmp/Magisk/META-INF/com/google/android/update-binary", "dummy", "1", "/tmp/Magisk/Magisk.zip");
delete_recursive("/tmp/Magisk");
EOT

# Create directory structure
magisk_dir=$WORK_DIR/META-INF/ADD-ONS/Magisk
mkdir -p "$magisk_dir"

# Get latest magisk version
get_latest_release
wget $magisk_url -O $magisk_dir/Magisk.zip > /dev/null 2>&1

# Zip folder to output directory
rm -rf "$rom_folder_out/$file_name"
zip -r "$rom_folder_out/$file_name" $WORK_DIR > /dev/null 2>&1
echo "File saved to '$rom_folder_out/$file_name'"

# Delete temporary directory
rm -rf $WORK_DIR
