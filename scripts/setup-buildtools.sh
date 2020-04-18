#!/bin/bash
# Setup script for build tools on host

# Checks
if [ -d "/opt/build_env" ]; then
  echo "Warning - Build scripts already exist on the system"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Error - Script must be run as root" 
  exit 1
fi

# Install build tools
echo "Pulling and installing tools"
git clone https://github.com/akhilnarang/scripts.git /opt/build_env --depth=1 > /dev/null 2>&1
sudo chmod +x /opt/build_env/setup/android_build_env.sh > /dev/null 2>&1
. /opt/build_env/setup/android_build_env.sh > /dev/null 2>&1

echo "Installing apt packages"
apt-get -y upgrade > /dev/null 2>&1 && \
apt-get -y install make python3 git screen wget openjdk-8-jdk python-lunch lsb-core sudo curl shellcheck \
autoconf libtool g++ libcrypto++-dev libz-dev libsqlite3-dev libssl-dev libcurl4-gnutls-dev libreadline-dev \
libpcre++-dev libsodium-dev libc-ares-dev libfreeimage-dev libavcodec-dev libavutil-dev libavformat-dev \
libswscale-dev libmediainfo-dev libzen-dev libuv1-dev libxkbcommon-dev libxkbcommon-x11-0 zram-config > /dev/null 2>&1

# Install mega
echo "Installing mega command line tools"
wget --quiet -O /opt/megasync.deb https://mega.nz/linux/MEGAsync/xUbuntu_$(lsb_release -rs)/amd64/megasync-xUbuntu_$(lsb_release -rs)_amd64.deb && dpkg -i /opt/megasync.deb > /dev/null 2>&1
apt update --fix-missing > /dev/null 2>&1
sudo apt install -f > /dev/null 2>&1
cd /opt/ && git clone --quiet https://github.com/meganz/MEGAcmd.git > /dev/null 2>&1
cd /opt/MEGAcmd && git submodule update --quiet --init --recursive && sh autogen.sh > /dev/null 2>&1 && ./configure --quiet > /dev/null 2>&1 && make > /dev/null 2>&1 && make install > /dev/null 2>&1
