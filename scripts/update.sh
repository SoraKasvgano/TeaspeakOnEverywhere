#!/bin/bash
. /opt/teaspeak/scripts/functions.sh

echo "-----------------------------------------------------------------------"
echo "TeaSpeak updater:"
echo "-----------------------------------------------------------------------"

# Creates a backup of the teaspeak folder
create_backup() {
    echo "Creating backup..."
    
    if [ -e "/opt/teaspeak/save/backup/backup.tar.gz" ]; then
        rm -f /opt/teaspeak/save/backup/backup.tar.gz
    fi
    
    tar czf /opt/teaspeak/save/backup/backup.tar.gz \
        --exclude="save" \
        --exclude="scripts" \
        -C /opt/teaspeak . >/dev/null 2>&1
}

# Creates the version file
create_version_file() {
    echo "$1" > /opt/teaspeak/version
}

# Check internet connectivity
if ! ping -q -c 1 -W 1 repo.teaspeak.de > /dev/null 2>&1; then
    echo "Internet connectivity check failed! No update was done."
    return
fi

version=0

# Get current version
if [ -e "/opt/teaspeak/version" ]; then
    version=$(cat /opt/teaspeak/version)
fi

# For TeaSpeak, we'll use a predefined version or try to get the latest
# Since TeaSpeak doesn't have a public API like TeamSpeak, we'll use the ARG version
new_version="${TEA_VERSION:-1.4.22}"

# Same version -> no update
if [ "$new_version" = "$version" ]; then
    echo "Current version ($version) is up to date!"
    return
fi

# If you entered recovery mode, the 'broken' version got blocked
if [ -e "/opt/teaspeak/blocked" ]; then
    blocked=$(cat /opt/teaspeak/blocked)
    
    if [ "$new_version" = "$blocked" ]; then
        echo "There is a newer version available, but it's blocked!"
        return
    fi
fi

echo "Update available! $version -> $new_version"

echo "Downloading new version $new_version..."
clean_cached_folder

# Download new version
if ! download_teaspeak "$new_version"; then
    echo "Failed to download TeaSpeak $new_version"
    return
fi

echo "Download successful!"

if [ "$version" != "0" ] && [ "$TEA_UPDATE_BACKUP" != "0" ]; then
    create_backup
fi

echo "Installing new version $new_version..."

# Extract new version
if ! extract_teaspeak "$new_version"; then
    echo "Failed to extract TeaSpeak $new_version"
    return
fi

clean_cached_folder

# If blocked file exists, delete it
if [ -e "/opt/teaspeak/blocked" ]; then
    rm -f /opt/teaspeak/blocked
fi

# If version = 0, there is no TeaSpeak server installed
if [ "$version" = "0" ]; then
    create_folders
    create_files
    create_links
fi

create_minimal_runscript
create_version_file "$new_version"
chown_teaspeak_folder

echo "Version $new_version installed successfully!"