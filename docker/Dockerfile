FROM buildkite/agent:ubuntu

ENV DEBIAN_FRONTEND noninteractive
USER root
WORKDIR /root/

# Get packages
RUN echo "Installing packages"
RUN apt-get update -q --fix-missing > /dev/null 2>&1 && \
  apt-get -y upgrade > /dev/null 2>&1 && \
  apt-get -y install make python3 git screen wget openjdk-8-jdk python-lunch lsb-core sudo curl shellcheck \
  autoconf libtool g++ libcrypto++-dev libz-dev libsqlite3-dev libssl-dev libcurl4-gnutls-dev libreadline-dev \
  libpcre++-dev libsodium-dev libc-ares-dev libfreeimage-dev libavcodec-dev libavutil-dev libavformat-dev ccache python3-pip \
  libswscale-dev libmediainfo-dev libzen-dev libuv1-dev libxkbcommon-dev libxkbcommon-x11-0 zram-config > /dev/null 2>&1 && \
  rm -rf /var/lib/apt/lists/*

# Specify global vars
RUN git config --global user.name robbbalmbra
RUN git config --global user.email robbalmbra@gmail.com
RUN git config --global color.ui true
RUN git config --global url."https://".insteadOf git://

# Get mega binaries and github repo for remote upload capabilities
RUN echo "Retrieving megasync package"
RUN wget --quiet -O /opt/megasync.deb https://mega.nz/linux/MEGAsync/xUbuntu_$(lsb_release -rs)/amd64/megasync-xUbuntu_$(lsb_release -rs)_amd64.deb && ls /opt/ && dpkg -i /opt/megasync.deb

RUN echo "Cloning megacmd"
RUN cd /opt/ && git clone --quiet https://github.com/meganz/MEGAcmd.git

RUN echo "Building megacmd"
RUN cd /opt/MEGAcmd && git submodule update --quiet --init --recursive && sh autogen.sh > /dev/null 2>&1 && ./configure --quiet && make > /dev/null 2>&1 && make install > /dev/null 2>&1 && rm -rf /opt/MEGAcmd/
RUN if [ -d /usr/lib/jvm/java-8-openjdk-amd64/bin/ ]; then export PATH=/usr/lib/jvm/java-8-openjdk-amd64/bin/:$PATH; fi

# Clone and run build tool
RUN echo "Retreiving and installing build tools"
RUN git clone https://github.com/akhilnarang/scripts.git /opt/build_env --quiet --depth=1
RUN chmod +x /opt/build_env/setup/android_build_env.sh
RUN /bin/bash /opt/build_env/setup/android_build_env.sh > /dev/null 2>&1

# Copy ssh
COPY id_rsa /root/.ssh/id_rsa
