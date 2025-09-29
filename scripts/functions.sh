#!/bin/bash

# TeaSpeak Functions Library

# Check if required packages are installed
check_installed_packages() {
    echo "Checking installed packages..."
    
    if ! command -v wget >/dev/null 2>&1; then
        echo "ERROR: wget is not installed!"
        exit 1
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: curl is not installed!"
        exit 1
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is not installed!"
        exit 1
    fi
    
    echo "All required packages are installed."
}

# Create necessary folders
create_folders() {
    echo "Creating necessary folders..."
    mkdir -p /opt/teaspeak/save
    mkdir -p /opt/teaspeak/save/backup
    mkdir -p /opt/teaspeak/logs
    mkdir -p /opt/teaspeak/files
    mkdir -p /opt/teaspeak/database
    mkdir -p /opt/teaspeak/certs
}

# Create necessary files
create_files() {
    echo "Creating necessary files..."
    
    # Create default config if not exists
    if [ ! -f "/opt/teaspeak/save/config.yml" ]; then
        if [ -f "/opt/teaspeak/config.yml" ]; then
            cp /opt/teaspeak/config.yml /opt/teaspeak/save/config.yml
        fi
    fi
    
    # Create protocol key if not exists
    if [ ! -f "/opt/teaspeak/save/protocol_key.txt" ]; then
        if [ -f "/opt/teaspeak/protocol_key.txt" ]; then
            cp /opt/teaspeak/protocol_key.txt /opt/teaspeak/save/protocol_key.txt
        fi
    fi
}

# Create symbolic links
create_links() {
    echo "Creating symbolic links..."
    
    # Link config files from save directory
    if [ -f "/opt/teaspeak/save/config.yml" ]; then
        ln -sf /opt/teaspeak/save/config.yml /opt/teaspeak/config.yml
    fi
    
    if [ -f "/opt/teaspeak/save/protocol_key.txt" ]; then
        ln -sf /opt/teaspeak/save/protocol_key.txt /opt/teaspeak/protocol_key.txt
    fi
    
    # Link data directories
    ln -sf /opt/teaspeak/logs /opt/teaspeak/save/logs
    ln -sf /opt/teaspeak/files /opt/teaspeak/save/files
    ln -sf /opt/teaspeak/database /opt/teaspeak/save/database
    ln -sf /opt/teaspeak/certs /opt/teaspeak/save/certs
}

# Clean cached folder
clean_cached_folder() {
    echo "Cleaning cached folder..."
    rm -rf /opt/teaspeak_cached/*
}

# Clean teaspeak folder (keep save directory)
clean_teaspeak_folder() {
    echo "Cleaning TeaSpeak folder..."
    find /opt/teaspeak -maxdepth 1 -type f -not -name "version" -not -name "predownloaded" -delete
    find /opt/teaspeak -maxdepth 1 -type d -not -name "save" -not -name "scripts" -not -path "/opt/teaspeak" -exec rm -rf {} +
}

# Set ownership for teaspeak user
chown_teaspeak_folder() {
    echo "Setting ownership for TeaSpeak folder..."
    chown -R tea:tea /opt/teaspeak
    chown -R tea:tea /opt/teaspeak_cached
}

# Create minimal run script
create_minimal_runscript() {
    echo "Creating minimal run script..."
    
    cat > /opt/teaspeak/teastart_minimal.sh << 'EOF'
#!/bin/bash

cd /opt/teaspeak

# Use QEMU if on ARM architecture
if [ "$SYSTEM_ARCHITECTURE" = "arm64" ] || [ "$SYSTEM_ARCHITECTURE" = "arm32v7" ]; then
    echo "Starting TeaSpeak with QEMU emulation..."
    exec qemu-x86_64-static ./teastart_minimal.sh
else
    echo "Starting TeaSpeak natively..."
    exec ./teastart_minimal.sh
fi
EOF

    chmod +x /opt/teaspeak/teastart_minimal.sh
}

# Get latest TeaSpeak version info
get_latest_version_info() {
    echo "Getting latest TeaSpeak version info..."
    
    # TeaSpeak doesn't have a public API like TeamSpeak, so we'll use GitHub releases
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/TeaSpeak/TeaSpeak/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        echo "Failed to get latest version info"
        return 1
    fi
    
    echo "Latest version: $LATEST_VERSION"
    echo "$LATEST_VERSION"
}

# Download TeaSpeak
download_teaspeak() {
    local version=$1
    echo "Downloading TeaSpeak version $version..."
    
    # Since we have local files, we should use them instead of downloading
    if [ -d "/opt/teaspeak/TeaSpeak-${version}" ]; then
        echo "Using local TeaSpeak files for version $version"
        return 0
    fi
    
    # Fallback to download if local files not available
    wget -O /opt/teaspeak_cached/TeaSpeak-${version}.tar.gz \
        "https://repo.teaspeak.de/server/linux/amd64_stable/TeaSpeak-${version}.tar.gz" \
        > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "Failed to download TeaSpeak $version"
        return 1
    fi
    
    echo "TeaSpeak $version downloaded successfully"
    return 0
}

# Extract TeaSpeak
extract_teaspeak() {
    local version=$1
    echo "Extracting TeaSpeak..."
    
    # Check if we have local files first
    if [ -d "/opt/teaspeak/TeaSpeak-${version}" ]; then
        echo "Using local TeaSpeak files..."
        # Copy local files to teaspeak directory
        cp -r /opt/teaspeak/TeaSpeak-${version}/* /opt/teaspeak/
        echo "Local TeaSpeak files copied successfully"
        return 0
    fi
    
    # Fallback to extracting downloaded archive
    cd /opt/teaspeak_cached
    if [ -f "TeaSpeak-${version}.tar.gz" ]; then
        tar -xzf TeaSpeak-${version}.tar.gz
        
        if [ $? -ne 0 ]; then
            echo "Failed to extract TeaSpeak"
            return 1
        fi
        
        # Move files to teaspeak directory
        mv TeaSpeak-${version}/* /opt/teaspeak/
        rmdir TeaSpeak-${version}
        rm TeaSpeak-${version}.tar.gz
        
        echo "TeaSpeak extracted successfully"
        return 0
    else
        echo "No TeaSpeak archive found"
        return 1
    fi
}