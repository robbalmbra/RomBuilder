#!/bin/bash

# Script for local build V1.0

# Install requirements for build
CURRENT="$(pwd)"

# Make sure user is in root to reduce permission issues
#if [[ $EUID -ne 0 ]]; then
#  echo "$0 - Error, please elevate permissions to root" 
#  exit 1
#fi

# Install build tools
if [ -f "/etc/lsb-release" ] && [ ! -d "/opt/build_env" ]; then
  # Linux install
  echo "Pulling and installing tools"
  git clone https://github.com/akhilnarang/scripts.git /opt/build_env --depth=1
  sudo chmod +x /opt/build_env/setup/android_build_env.sh
  . /opt/build_env/setup/android_build_env.sh

  apt-get -y upgrade > /dev/null 2>&1 && \
  apt-get -y install make python3 git screen wget openjdk-8-jdk python-lunch lsb-core sudo curl shellcheck \
  autoconf libtool g++ libcrypto++-dev libz-dev libsqlite3-dev libssl-dev libcurl4-gnutls-dev libreadline-dev \
  libpcre++-dev libsodium-dev libc-ares-dev libfreeimage-dev libavcodec-dev libavutil-dev libavformat-dev \
  libswscale-dev libmediainfo-dev libzen-dev libuv1-dev libxkbcommon-dev libxkbcommon-x11-0 zram-config > /dev/null 2>&1   

  # Download and build mega
  if [ ! -d "/opt/MEGAcmd/" ]; then
    wget --quiet -O /opt/megasync.deb https://mega.nz/linux/MEGAsync/xUbuntu_$(lsb_release -rs)/amd64/megasync-xUbuntu_$(lsb_release -rs)_amd64.deb && ls /opt/ && dpkg -i /opt/megasync.deb
    cd /opt/ && git clone --quiet https://github.com/meganz/MEGAcmd.git
    cd /opt/MEGAcmd && git submodule update --quiet --init --recursive && sh autogen.sh > /dev/null 2>&1 && ./configure --quiet && make > /dev/null 2>&1 && make install > /dev/null 2>&1
  fi

  apt update --fix-missing
  sudo apt install -f

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
cd "$CURRENT"
echo "Running build script"
"$(pwd)/../docker/build.sh"
