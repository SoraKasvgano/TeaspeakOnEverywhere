#!/bin/bash

# TeaSpeak Docker Functions Library
# Common functions used across multiple scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker installation
check_docker() {
    if ! command_exists docker; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Check Docker Compose installation
check_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command_exists docker-compose; then
        echo "docker-compose"
    else
        log_error "Docker Compose is not available"
        return 1
    fi
}

# Detect system architecture
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "arm/v7"
            ;;
        *)
            log_warning "Unknown architecture: $arch, defaulting to amd64"
            echo "amd64"
            ;;
    esac
}

# Create necessary directories
create_directories() {
    local dirs=("data/logs" "data/files" "data/database" "data/certs" "config")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chmod 755 "$dir"
            log_info "Created directory: $dir"
        fi
    done
}

# Set file permissions
set_permissions() {
    local files=("$@")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            chmod +x "$file"
            log_info "Set executable permission: $file"
        fi
    done
}

# Wait for service to be ready
wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local count=0
    
    log_info "Waiting for service at $host:$port..."
    
    while [ $count -lt $timeout ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_success "Service is ready at $host:$port"
            return 0
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    log_error "Service at $host:$port is not ready after ${timeout}s"
    return 1
}

# Cleanup function
cleanup_docker() {
    log_info "Cleaning up Docker resources..."
    
    # Remove unused networks
    docker network prune -f >/dev/null 2>&1 || true
    
    # Remove unused images (only dangling ones)
    docker image prune -f >/dev/null 2>&1 || true
    
    log_success "Docker cleanup completed"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f command_exists check_docker check_docker_compose
export -f detect_architecture create_directories set_permissions
export -f wait_for_service cleanup_docker