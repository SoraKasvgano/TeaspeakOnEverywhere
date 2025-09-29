#!/bin/bash
. /opt/teaspeak/scripts/functions.sh

echo "-----------------------------------------------------------------------"
echo "TeaSpeak recovery:"
echo "-----------------------------------------------------------------------"

# Check if backup exists
if [ ! -e "/opt/teaspeak/save/backup/backup.tar.gz" ]; then
    echo "No backup found! Recovery not possible."
    return
fi

echo "Backup found. Starting recovery..."

# Get current version
current_version="unknown"
if [ -e "/opt/teaspeak/version" ]; then
    current_version=$(cat /opt/teaspeak/version)
fi

echo "Current version: $current_version"

# Block current version
echo "$current_version" > /opt/teaspeak/blocked
echo "Version $current_version has been blocked."

# Clean current installation
clean_teaspeak_folder

# Restore from backup
echo "Restoring from backup..."
cd /opt/teaspeak
tar xzf /opt/teaspeak/save/backup/backup.tar.gz

# Set permissions
chown_teaspeak_folder

# Create links
create_links

echo "Recovery completed successfully!"
echo "The problematic version ($current_version) has been blocked."
echo "To unblock it, delete the file: /opt/teaspeak/blocked"