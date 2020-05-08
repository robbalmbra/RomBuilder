#!/bin/bash
# Handler for ota json generation and upload to sourceforge

# Create directory on sourceforge
function sftp_mkdir {
  sftp -q -o "StrictHostKeyChecking no robbalmbra@frs.sourceforge.net << EOF \nmkdir $1\nEOF"
}

if [ $# -lt 3 ]; then
  echo "USAGE: $0 [ROM FOLDER] [OTA FOLDER] [ROM NAME]"
  exit 1
fi

rom_folder=$1
ota_folder=$2
rom_name=$3

if [ ! -d $rom_folder ]; then
  echo "Error - '$rom_folder' doesn't exist!"
  exit 2
fi

if [ ! -d $ota_folder ]; then
  echo "Error - '$ota_folder' doesn't exist!"
  exit 3
fi

# Check if ota handler exists for specific rom
if [ ! -f "$rom_name.py" ]; then
  echo "Error - '$rom_name' isn't supported in this script."
  exit 4
fi

# Make rom directory
sftp_mkdir "/home/frs/project/evo9810ota/$rom_name/"

# Iterate over devices
for ROM in $rom_folder/out/target/product/*/*.zip; do

  # Skip if zip has -ota- in zip
  if [[ $ROM == *"-ota-"* ]]; then
    continue
  fi

  DEVICE="$(basename "$(dirname "$ROM")")"

  # Run specific build ota generation script
  python3 "$rom_name.py" "$ROM" "$rom_name" 1> "$ota_folder/$DEVICE.json" 2> /dev/null

  # Make device directory
  sftp_mkdir "/home/frs/project/evo9810ota/$rom_name/$DEVICE/"

  # Create date directory in each device
  date=$(date '+%d-%m-%y')
  sftp_mkdir "/home/frs/project/evo9810ota/$rom_name/$DEVICE/$date/"

  # Upload rom file to sourceforge
  rom_filename=$(basename $ROM)
  echo "Uploading '$rom_filename' to /home/frs/project/evo9810ota/$rom_name/$DEVICE/$date/"
  scp -o "StrictHostKeyChecking no $ROM robbalmbra@frs.sourceforge.net:/home/frs/project/evo9810ota/$rom_name/$DEVICE/$date/"
done
