FROM debian:12-slim as bluez

# https://github.com/Dreamsorcerer/bluez
ARG BLUEZ_COMMIT="ff0a347c5e0e340cb3fc29419b1640a58d039b6c"

RUN set -ex; \
    \
    sed -i 's/^Types: deb/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && \
    apt-get install -y build-essential dpkg-dev devscripts  && \
    apt-get install -y \
        git \
        bluez && \
    mk-build-deps --install -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" --remove bluez

RUN set -ex; \
    \
    git clone https://github.com/Dreamsorcerer/bluez.git /tmp/bluez && \
    cd /tmp/bluez && git checkout ${BLUEZ_COMMIT} && rm -rf .git

RUN set -ex; \
    \
    cd /tmp/bluez && \
    autoreconf -fvi && \
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-a2dp --disable-avrcp --disable-network --disable-manpages && \
    automake && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/bluez && cd /

# Cleanup
RUN set -ex; \
    \
    apt-get purge -y \
        bluez-build-deps build-essential dpkg-dev devscripts git && \
    apt-get autoremove -y && \
    apt-get clean

FROM bluez

# https://github.com/Dreamsorcerer/bthidhub
ARG BTHIDHUB_COMMIT="1fadec7538ba658f82dd3f71f969efd3af449094"

RUN set -ex; \
    \
    apt-get update && \
    apt-get install -y build-essential dpkg-dev && \
    apt-get install -y \
        sudo procps git python3 python3-venv \
        libcairo2-dev libdbus-1-dev libgirepository1.0-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev \
        python3-pip

# User pi is used by bthidhub, and is quite hardcoded.
RUN useradd -m -u 1000 -g 100 pi

# Generate Dbus needed files.
RUN set -ex; \
    \
    mkdir -p /run/dbus && \
    dbus-uuidgen > /var/lib/dbus/machine-id;

RUN set -ex; \
    \
    git clone https://github.com/Dreamsorcerer/bthidhub.git /bthidhub && \
    cd /bthidhub && git checkout ${BTHIDHUB_COMMIT} && rm -rf .git

WORKDIR /bthidhub

# Needed by mypyc, otherwise crash at runtime due to unknown dt objects.
# RUN set -ex; \
#     \
#     sed -i '8a from dasbus.typing import ObjPath, UInt16' agent.py

# Runs mypyc in bthidhub to compile the python modules. For testing build, setting it to false will skip this step.
RUN set -ex; \
    \
    python3 -m venv /bthidhub/.venv && \
    . /bthidhub/.venv/bin/activate && /bthidhub/.venv/bin/pip3 install -r /bthidhub/requirements.txt

# ARG BUILD_MYPYC=false
# RUN bash -c 'if [ ${BUILD_MYPYC:=true} ]; then cd /bthidhub; . .venv/bin/activate && .venv/bin/mypyc; fi'

# Cleanup
RUN set -ex; \
    \
    apt-get purge -y build-essential dpkg-dev devscripts python3-pip git && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/cache/apt /var/lib/apt

RUN set -ex; \
    \
    mv /etc/bluetooth /etc/bluetooth.old

# bthidhub uses systemctl interactions, add a dummy script that emulate some services.
ADD systemctl /usr/bin/systemctl
ADD entrypoint.sh /entrypoint.sh

VOLUME /etc/bluetooth /var/lib/bluetooth /config
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
