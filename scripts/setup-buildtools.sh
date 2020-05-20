#!/bin/bash
# Setup script for build tools for buildkite

promptyn () {
    while true; do
        read -p "$1 " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

error_exit()
{
    ret="$?"
    if [ "$ret" != "0" ]; then
        echo "Error - '$1' failed with return code '$ret'"
        exit 1
    fi
}

# Checks
if [ -d "/opt/build_env" ]; then
  if promptyn "Warning - Build scripts already exist on the system. Do you want to reinstall? y/n"; then
    rm -rf /opt/build_env > /dev/null 2>&1
    apt-get purge -y buildkite-agent  > /dev/null 2>&1
    rm -rf /opt/MEGAcmd > /dev/null 2>&1
  else
    exit 0
  fi
fi

if [[ $EUID -ne 0 ]]; then
  echo "Error - Script must be run as root"
  exit 1
fi

# Get hostname for buildkite tag
if [ -z "$BHOST" ]; then
  echo "Please enter a hostname for buildkite to use:"
  read user_host
else
  user_host="$BHOST"
fi

# Get hostname for buildkite tag
if [ -z "$BTOKEN" ]; then
  echo "Please enter the buildkite token to use:"
  read user_token
else
  user_token="$BTOKEN"
fi

# Install build tools
echo "Pulling and installing build tools"
apt-get install git curl -y > /dev/null 2>&1
git config --global user.name "Robert Balmbra" > /dev/null 2>&1
git config --global user.email "robbalmbra@gmail.com" > /dev/null 2>&1
error_exit "git config"

git clone https://github.com/akhilnarang/scripts.git /opt/build_env --depth=1 > /dev/null 2>&1
sudo chmod +x /opt/build_env/setup/android_build_env.sh > /dev/null 2>&1
. /opt/build_env/setup/android_build_env.sh > /dev/null 2>&1
error_exit "environment script" 

echo "Installing apt packages"
apt-get -y upgrade > /dev/null 2>&1 && \
apt-get -y install make python3 git screen wget openjdk-8-jdk lsb-core sudo curl shellcheck \
autoconf libtool g++ libcrypto++-dev libz-dev libsqlite3-dev libssl-dev libcurl4-gnutls-dev libreadline-dev \
libpcre++-dev libsodium-dev libc-ares-dev libfreeimage-dev libavcodec-dev libavutil-dev libavformat-dev python3-pip \
libswscale-dev libmediainfo-dev libzen-dev libuv1-dev libxkbcommon-dev libxkbcommon-x11-0 zram-config > /dev/null 2>&1
error_exit "apt packages"

# Install python packages
echo "Installing python packages"
pip3 install python-telegram-bot --upgrade > /dev/null 2>&1
error_exit "pip3"

# Install mega
echo "Installing mega command line tools"
wget --quiet -O /opt/megasync.deb https://mega.nz/linux/MEGAsync/xUbuntu_$(lsb_release -rs)/amd64/megasync-xUbuntu_$(lsb_release -rs)_amd64.deb && dpkg -i /opt/megasync.deb > /dev/null 2>&1
apt update --fix-missing > /dev/null 2>&1
sudo apt install -f > /dev/null 2>&1
cd /opt/ && git clone --quiet https://github.com/meganz/MEGAcmd.git > /dev/null 2>&1
cd /opt/MEGAcmd && git submodule update --quiet --init --recursive && sh autogen.sh > /dev/null 2>&1 && ./configure --quiet > /dev/null 2>&1 && make > /dev/null 2>&1 && make install > /dev/null 2>&1
error_exit "mega"

apt --fix-broken -y install > /dev/null 2>&1

# Override python to point to python 3 on ubuntu 20.04
u_version=$(lsb_release -r | cut -f2)

if [[ "$u_version" == "20.04" ]]; then
  apt install -y python-is-python3 > /dev/null 2>&1
fi

# Install buildkite to host
sudo sh -c 'echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list'
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198
sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y buildkite-agent > /dev/null 2>&1
sudo sed -i "s/xxx/$user_token/g" /etc/buildkite-agent/buildkite-agent.cfg  > /dev/null 2>&1

echo "tags=\"target=$user_host\"" >> /etc/buildkite-agent/buildkite-agent.cfg

# Start buildkite
sudo systemctl enable buildkite-agent > /dev/null 2>&1 && sudo systemctl start buildkite-agent > /dev/null 2>&1

# Removing temp files
rm -rf /opt/MEGAcmd/ 2> /dev/null
rm -rf /opt/mega/ 2> /dev/null
rm -rf /opt/megasync.deb 2> /dev/null

# ld for libs
ldconfig > /dev/null 2>&1
