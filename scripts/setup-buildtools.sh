#!/bin/bash
# Setup script for build tools for buildkite

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
  echo "Warning - Build scripts already exist on the system"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Error - Script must be run as root"
  exit 1
fi

# Install build tools
echo "Pulling and installing build tools"
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

# Install buildkite to host
sudo sh -c 'echo deb https://apt.buildkite.com/buildkite-agent stable main > /etc/apt/sources.list.d/buildkite-agent.list'
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198
sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y buildkite-agent > /dev/null 2>&1
sudo sed -i "s/xxx/49847013e94f61ef546c9eaa4cd75e40f91ab3367c526e52a1/g" /etc/buildkite-agent/buildkite-agent.cfg  > /dev/null 2>&1

# Start buildkite
sudo systemctl enable buildkite-agent > /dev/null 2>&1 && sudo systemctl start buildkite-agent > /dev/null 2>&1

# Removing temp files
rm -rf /opt/MEGAcmd/ 2> /dev/null
rm -rf /opt/mega/ 2> /dev/null
rm -rf /opt/megasync.deb 2> /dev/null

# ld for libs
ldconfig > /dev/null 2>&1