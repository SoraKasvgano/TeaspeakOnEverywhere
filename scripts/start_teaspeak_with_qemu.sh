#!/bin/bash

set -e

# Set environment variables
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/teaspeak/libs/"
export LD_PRELOAD="/opt/teaspeak/libs/libjemalloc.so.2"

# Detect architecture and set QEMU if needed
ARCH=$(uname -m)
QEMU_CMD=""

case "$ARCH" in
    armv7*|arm32*)
        if command -v qemu-x86_64-static >/dev/null 2>&1; then
            QEMU_CMD="qemu-x86_64-static"
        fi
        ;;
    aarch64|arm64*)
        if command -v qemu-x86_64-static >/dev/null 2>&1; then
            QEMU_CMD="qemu-x86_64-static"
        fi
        ;;
    x86_64|amd64)
        # Native x86_64, no QEMU needed
        QEMU_CMD=""
        ;;
    *)
        echo "Warning: Unsupported architecture: $ARCH"
        ;;
esac

# Change to TeaSpeak directory
cd /opt/teaspeak

# Start TeaSpeak server with QEMU emulation if needed
if [ -f "/opt/teaspeak/TeaSpeakServer" ]; then
    if [ -n "$QEMU_CMD" ]; then
        echo "Starting TeaSpeakServer with QEMU emulation ($QEMU_CMD)"
        exec $QEMU_CMD /opt/teaspeak/TeaSpeakServer "$@"
    else
        echo "Starting TeaSpeakServer natively"
        exec /opt/teaspeak/TeaSpeakServer "$@"
    fi
else
    echo "Error: TeaSpeakServer not found!"
    exit 1
fi