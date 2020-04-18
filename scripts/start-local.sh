#!/bin/bash

# Script for local build V1.0

# Install requirements for build

# Install build tools
if [ -f "/etc/lsb-release" ] && [ ! -d "/opt/build_env" ]; then
  # Linux install
  git clone https://github.com/akhilnarang/scripts.git /opt/build_env --depth=1
  sudo chmod +x /opt/build_env/setup/android_build_env.sh
  . /opt/build_env/setup/android_build_env.sh

  apt-get -y upgrade > /dev/null 2>&1 && \
  apt-get -y install make python3 git screen wget openjdk-8-jdk python-lunch lsb-core sudo curl shellcheck \
  autoconf libtool g++ libcrypto++-dev libz-dev libsqlite3-dev libssl-dev libcurl4-gnutls-dev libreadline-dev \
  libpcre++-dev libsodium-dev libc-ares-dev libfreeimage-dev libavcodec-dev libavutil-dev libavformat-dev \
  libswscale-dev libmediainfo-dev libzen-dev libuv1-dev libxkbcommon-dev libxkbcommon-x11-0 zram-config > /dev/null 2>&1   

else
  # MacOS install - todo
  echo ""
fi

# Sets vars for run script
export OUTPUT_DIR=$(pwd)/../files/;
mkdir "$OUTPUT_DIR" > /dev/null 2>&1

export BUILD_NAME=aosp
export UPLOAD_NAME=evox
export MEGA_USERNAME=robbalmbra@gmail.com
export MEGA_PASSWORD=Er1hcK0wN$PIhN4mT$K#U@5ZusH0zdcT
export DEVICES=crownlte,starlte,star2lte
export REPO=https://github.com/Evolution-X/manifest
export USE_CCACHE=1
export CUSTOM_BUILD_TYPE=UNOFFICIAL
export TARGET_BOOT_ANIMATION_RES=1080
export TARGET_GAPPS_ARCH=arm64
export TARGET_SUPPORTS_GOOGLE_RECORDER=true
export CCACHE_DIR=$OUTPUT_DIR/ccache
export BRANCH=ten
export BOOT_LOGGING=1

# Check vars
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

# Run build
$(pwd)/../docker/build.sh
