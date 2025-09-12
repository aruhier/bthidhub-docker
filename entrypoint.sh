#!/bin/bash

: "${BTHIDHUB_PASSWORD:=bthidhub}"
echo "pi:${BTHIDHUB_PASSWORD}" | chpasswd
unset BTHIDHUB_PASSWORD

if [ ! -e /etc/bluetooth/input.conf ]; then
    cp /bthidhub/install/on_rpi/input.conf /etc/bluetooth/input.conf
fi
if [ ! -e /etc/bluetooth/main.conf ]; then
    cp /bthidhub/install/on_rpi/main.conf /etc/bluetooth/main.conf
fi
if [ ! -e /etc/bluetooth/network.conf ]; then
    cp /etc/bluetooth.old/network.conf /etc/bluetooth/network.conf
fi
if [ ! -e /etc/bluetooth/sdp_record.xml ]; then
    cp /bthidhub/sdp_record_template.xml /etc/bluetooth/sdp_record.xml
    sed -i 's/{}//' /etc/bluetooth/sdp_record.xml
fi

if [ ! -e /config/devices_config.json ]; then
    touch /config/devices_config.json
fi
ln -s /config/devices_config.json /bthidhub/devices_config.json

/usr/bin/dbus-daemon --system --nopidfile
sleep 5
systemctl start bluetooth

cd /bthidhub
export PATH="/bthidhub/.venv/bin:$PATH"
source /bthidhub/.venv/bin/activate && /bthidhub/.venv/bin/python /bthidhub/remapper.py
