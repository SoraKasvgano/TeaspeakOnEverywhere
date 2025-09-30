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

# Detect architecture and set QEMU if needed
ARCH=$(uname -m)
QEMU_CMD=""

case "$ARCH" in
    armv7*|arm32*)
        QEMU_CMD="qemu-x86_64-static"
        ;;
    aarch64|arm64*)
        QEMU_CMD="qemu-x86_64-static"
        ;;
esac

# Start TeaSpeak server with QEMU emulation if on ARM
if [ -f "/opt/teaspeak/TeaSpeakServer" ]; then
    cd /opt/teaspeak
    
    # If QEMU is needed and available, create a wrapper script
    if [ -n "$QEMU_CMD" ] && command -v "$QEMU_CMD" >/dev/null 2>&1; then
        # Create a wrapper script that uses QEMU
        cat > /opt/teaspeak/start_with_qemu.sh << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/teaspeak/libs/"
export LD_PRELOAD="/opt/teaspeak/libs/libjemalloc.so.2"
exec qemu-x86_64-static /opt/teaspeak/TeaSpeakServer "$@"
EOF
        chmod +x /opt/teaspeak/start_with_qemu.sh
        exec s6-setuidgid tea /opt/teaspeak/start_with_qemu.sh
    else
        exec s6-setuidgid tea /opt/teaspeak/TeaSpeakServer
    fi
else
    echo "Error: TeaSpeakServer not found!"
    exit 1
fi