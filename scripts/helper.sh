#!/bin/bash

# TeaSpeak Helper Script
# This script runs alongside the main TeaSpeak process to provide additional functionality

echo "TeaSpeak Helper started"

# Function to check if TeaSpeak is running
check_teaspeak_running() {
    pgrep -f "teastart_minimal.sh" > /dev/null
    return $?
}

# Function to perform weekly update check
weekly_update_check() {
    echo "Performing weekly update check..."
    
    if [ -e "/opt/teaspeak/version" ]; then
        current_version=$(cat /opt/teaspeak/version)
        echo "Current version: $current_version"
        
        # For now, just log the current version
        # In a real implementation, you would check against the latest version
        echo "Update check completed. Current version: $current_version"
    else
        echo "No version file found"
    fi
}

# Main loop
while true; do
    # Check if it's Sunday (day 0) and perform weekly update check
    if [ "$(date +%w)" = "0" ] && [ "$(date +%H)" = "02" ]; then
        weekly_update_check
    fi
    
    # Sleep for 1 hour
    sleep 3600
done