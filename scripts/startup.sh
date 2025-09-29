#!/bin/bash
. /opt/teaspeak/scripts/functions.sh

chown_save(){
    chown -R tea:tea /opt/teaspeak
    chown -R tea:tea /opt/teaspeak_cached
}

# Check if every package is installed
check_installed_packages

# Add the user and group
if ! id -u tea >/dev/null 2>&1; then
    groupadd -g $GID tea
    useradd -u $UID -g $GID -d /opt/teaspeak tea
fi

# Get current timezone
CURRENT_TIME_ZONE="$(cat /etc/timezone 2>/dev/null || echo 'UTC')"

# Update timezone if necessary
if [ "$TIME_ZONE" != "$CURRENT_TIME_ZONE" ]; then
    echo "Updating timezone to $TIME_ZONE"
    ln -fs /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
    dpkg-reconfigure -f noninteractive tzdata
fi

# Only update the system, if wanted
if [ "$DIST_UPDATE" != "0" ]; then
    echo "Updating system packages..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
fi

# Check if image contains predownloaded server
if [ -e "/opt/teaspeak/predownloaded" ]; then
    echo "Setting up predownloaded TeaSpeak server..."
    rm -f /opt/teaspeak/predownloaded
    
    # Complete the installation of the server
    echo "Completing the installation of the predownloaded server..."
    clean_cached_folder
    
    create_folders
    create_files
    create_links
    
    create_minimal_runscript
    chown_teaspeak_folder
fi

# Enter recover mode if file exists
if [ -e "/opt/teaspeak/save/recover" ]; then
    echo "Entering recovery mode..."
    rm -f /opt/teaspeak/save/recover
    . /opt/teaspeak/scripts/recovery.sh
fi

# Run the updater, if env is set OR file exists OR teaspeak is not installed 
if [ "$TEA_UPDATE" != "0" ] || [ -e "/opt/teaspeak/save/update" ] || ! [ -e "/opt/teaspeak/version" ]; then
    if [ -e "/opt/teaspeak/save/update" ]; then
        rm -f /opt/teaspeak/save/update
    fi
    
    . /opt/teaspeak/scripts/update.sh
fi

# Just for safety, wait a few seconds
sleep 5

# Let's chown everything we need
chown_save

# Just create the links again if not present
create_links

# Debug switch
if [ "$DEBUG" != "0" ] || [ -e "/opt/teaspeak/save/debug" ]; then
    echo "Entering debug mode..."
    tail -f /dev/null
fi