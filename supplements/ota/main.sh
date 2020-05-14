#!/bin/bash
# Handler for ota json generation and upload to sourceforge

if [ $# -lt 4 ]; then
  echo "USAGE: $0 [ROM FOLDER] [OTA FOLDER] [ROM NAME] [OTA BUILD DIR]"
  exit 1
fi

rom_folder=$1
ota_folder=$2
rom_name=$3
ota_build_dir=$4

if [ ! -d $rom_folder ]; then
  echo "Error - '$rom_folder' doesn't exist!"
  exit 2
fi

if [ ! -d $ota_folder ]; then
  echo "Error - '$ota_folder' doesn't exist!"
  exit 3
fi

# Check if ota handler exists for specific rom
if [ ! -f "$ota_build_dir/$rom_name.py" ]; then
  echo "Warning - '$rom_name' doesn't support ota."
  exit 0
fi

# Add sourceforge to hosts
echo "dfgdfgdfgdfgh"
cat ~/.ssh/known_hosts
if [ -z "$(ssh-keygen -F frs.sourceforge.net)" ]; then
  ssh-keyscan -H frs.sourceforge.net >> ~/.ssh/known_hosts
fi

# Make rom directory
sftp -q robbalmbra@frs.sourceforge.net <<< "mkdir /home/frs/project/evo9810ota/$rom_name/"

# Iterate over devices
for ROM in $rom_folder/out/target/product/*/*.zip; do

  # Skip if zip has -ota- in zip
  if [[ $ROM == *"-ota-"* ]]; then
    continue
  fi

  rom_filename=$(basename $ROM)
  DEVICE="$(basename "$(dirname "$ROM")")"
  
  # Make changelogs folder
  mkdir "$ota_folder/changelogs/$DEVICE/"

  # Create changelog blank file
  touch "$ota_folder/changelogs/$DEVICE/$rom_filename.txt"

  # Run specific build ota generation script
  date=$(date '+%d-%m-%y')
  python3 "$ota_build_dir/$rom_name.py" "$ROM" "$rom_name" "$date" 1> "$ota_folder/$DEVICE.json" 2> /dev/null

  # Make device directory
  sftp -q robbalmbra@frs.sourceforge.net <<< "mkdir /home/frs/project/evo9810ota/$rom_name/$DEVICE/"

  # Create date directory in each device
  sftp -q robbalmbra@frs.sourceforge.net <<< "mkdir /home/frs/project/evo9810ota/$rom_name/$DEVICE/$date/"

  # Upload rom file to sourceforge
  echo "Uploading '$rom_filename' to /home/frs/project/evo9810ota/$rom_name/$DEVICE/$date/"
  scp $ROM robbalmbra@frs.sourceforge.net:/home/frs/project/evo9810ota/$rom_name/$DEVICE/$date/  
done

# Update device git repo
cd "$ota_folder"
git add *
git commit -am "auto push"
git push -f origin HEAD:$rom_name
