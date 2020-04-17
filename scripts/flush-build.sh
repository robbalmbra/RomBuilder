#!/bin/bash

# Delete builds, configurations and docker builds v1.0

current=$(pwd)
cd ../files/

# Delete folders and configs
echo "Flushing builds and configs"
umount rom > /dev/null 2>&1
rm -rf rom > /dev/null 2>&1
rm -rf android.sparseimage
rm -rf logs/*

docker stop evox_build > /dev/null 2>&1
docker rm evox_build > /dev/null 2>&1

cd $current
echo "Complete"
