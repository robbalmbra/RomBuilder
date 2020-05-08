#!/bin/bash
# Handler for ota json generation and upload to sourceforge

if [ $# -lt 2 ]; then
  echo "USAGE: $0 [ROM FOLDER] [OTA FOLDER]"
  exit 1
fi

rom_folder=$1
ota_folder=$2

if [ ! -d $rom_folder ]; then
  echo "Error - '$rom_folder' doesn't exist!"
  exit 2
fi

if [ ! -d $ota_folder ]; then
  echo "Error - '$ota_folder' doesn't exist!"
  exit 2
fi

# Iterate over devices
for ROM in $rom_folder/out/target/product/*/*.zip; do
 #TODO
done
