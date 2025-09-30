#!/bin/bash

set -e

# Set environment variables
export TEA_VERSION=${TEA_VERSION:-1.4.22}
export TIME_ZONE=${TIME_ZONE:-Asia/Shanghai}
export UID=${UID:-1000}
export GID=${GID:-1000}
export DEBUG=${DEBUG:-0}

# Create necessary directories
mkdir -p /opt/teaspeak/{logs,files,database,certs}
chown -R ${UID}:${GID} /opt/teaspeak

# Set timezone
ln -fs /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

# Start TeaSpeak server
if [ -f "/opt/teaspeak/teastart_minimal.sh" ]; then
    cd /opt/teaspeak
    exec s6-setuidgid tea /opt/teaspeak/teastart_minimal.sh
else
    echo "Error: teastart_minimal.sh not found!"
    exit 1
fi