#!/bin/bash

# TeaSpeak Docker Recovery Script
# Emergency recovery and troubleshooting tools

set -e

# Source functions library
source "$(dirname "$0")/functions.sh" 2>/dev/null || {
    echo "Warning: functions.sh not found, using basic functions"
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Emergency stop all TeaSpeak containers
emergency_stop() {
    log_warning "Emergency stop initiated..."
    
    # Stop using docker-compose if available
    local compose_cmd=$(check_docker_compose 2>/dev/null)
    if [ $? -eq 0 ]; then
        $compose_cmd down --timeout 5 2>/dev/null || true
    fi
    
    # Force stop any remaining TeaSpeak containers
    local containers=$(docker ps -q --filter "name=teaspeak" 2>/dev/null)
    if [ -n "$containers" ]; then
        log_info "Force stopping TeaSpeak containers..."
        echo "$containers" | xargs docker stop --time 5 2>/dev/null || true
        echo "$containers" | xargs docker rm -f 2>/dev/null || true
    fi
    
    log_success "Emergency stop completed"
}

# Reset TeaSpeak data (dangerous!)
reset_data() {
    log_error "WARNING: This will DELETE ALL TeaSpeak data!"
    log_warning "This includes:"
    echo "  - Server configuration"
    echo "  - User accounts and permissions"
    echo "  - Channel structure"
    echo "  - File uploads"
    echo "  - Database"
    echo ""
    
    read -p "Type 'RESET' to confirm data deletion: " confirm
    
    if [ "$confirm" != "RESET" ]; then
        log_info "Data reset cancelled"
        return 0
    fi
    
    log_warning "Stopping containers first..."
    emergency_stop
    
    log_warning "Deleting data directories..."
    rm -rf data/database/* 2>/dev/null || true
    rm -rf data/logs/* 2>/dev/null || true
    rm -rf data/files/* 2>/dev/null || true
    
    log_success "Data reset completed"
    log_info "You can now start TeaSpeak with a fresh installation"
}

# Fix permissions
fix_permissions() {
    log_info "Fixing file permissions..."
    
    # Fix data directories
    if [ -d "data" ]; then
        find data -type d -exec chmod 755 {} \; 2>/dev/null || true
        find data -type f -exec chmod 644 {} \; 2>/dev/null || true
        log_info "Fixed data directory permissions"
    fi
    
    # Fix config directory
    if [ -d "config" ]; then
        find config -type d -exec chmod 755 {} \; 2>/dev/null || true
        find config -type f -exec chmod 644 {} \; 2>/dev/null || true
        log_info "Fixed config directory permissions"
    fi
    
    # Fix scripts
    if [ -d "scripts" ]; then
        find scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        log_info "Fixed script permissions"
    fi
    
    # Fix main scripts
    chmod +x *.sh 2>/dev/null || true
    
    log_success "Permission fix completed"
}

# Clean Docker resources
clean_docker() {
    log_info "Cleaning Docker resources..."
    
    # Remove stopped containers
    local stopped_containers=$(docker ps -aq --filter "status=exited" --filter "name=teaspeak" 2>/dev/null)
    if [ -n "$stopped_containers" ]; then
        echo "$stopped_containers" | xargs docker rm 2>/dev/null || true
        log_info "Removed stopped TeaSpeak containers"
    fi
    
    # Remove unused images
    docker image prune -f >/dev/null 2>&1 || true
    log_info "Removed unused images"
    
    # Remove unused networks
    docker network prune -f >/dev/null 2>&1 || true
    log_info "Removed unused networks"
    
    # Remove unused volumes (be careful!)
    read -p "Remove unused volumes? This may delete data! (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        docker volume prune -f >/dev/null 2>&1 || true
        log_warning "Removed unused volumes"
    fi
    
    log_success "Docker cleanup completed"
}

# Diagnose issues
diagnose() {
    log_info "Running TeaSpeak diagnostics..."
    
    echo "=== System Information ==="
    echo "OS: $(uname -s)"
    echo "Architecture: $(uname -m)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    echo "=== Docker Information ==="
    if command_exists docker; then
        echo "Docker: $(docker --version)"
        echo "Docker Status: $(docker info >/dev/null 2>&1 && echo "Running" || echo "Not running")"
    else
        echo "Docker: Not installed"
    fi
    
    local compose_cmd=$(check_docker_compose 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "Docker Compose: $($compose_cmd --version)"
    else
        echo "Docker Compose: Not available"
    fi
    echo ""
    
    echo "=== Container Status ==="
    docker ps --filter "name=teaspeak" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No TeaSpeak containers found"
    echo ""
    
    echo "=== Port Status ==="
    local ports=("9987" "10011" "30033")
    for port in "${ports[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            echo "Port $port: In use"
        else
            echo "Port $port: Available"
        fi
    done
    echo ""
    
    echo "=== Directory Status ==="
    local dirs=("data" "config" "TeaSpeak-1.4.22")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "$dir: Exists ($(du -sh "$dir" 2>/dev/null | cut -f1))"
        else
            echo "$dir: Missing"
        fi
    done
    echo ""
    
    echo "=== Recent Logs ==="
    if docker ps --filter "name=teaspeak" --format "{{.Names}}" | head -1 | xargs docker logs --tail 10 2>/dev/null; then
        echo ""
    else
        echo "No recent logs available"
    fi
    
    log_success "Diagnostics completed"
}

# Rebuild containers
rebuild() {
    log_info "Rebuilding TeaSpeak containers..."
    
    # Stop existing containers
    emergency_stop
    
    # Remove existing images
    local images=$(docker images --filter "reference=*teaspeak*" -q 2>/dev/null)
    if [ -n "$images" ]; then
        log_info "Removing existing TeaSpeak images..."
        echo "$images" | xargs docker rmi -f 2>/dev/null || true
    fi
    
    # Rebuild using docker-compose
    local compose_cmd=$(check_docker_compose)
    if [ $? -eq 0 ]; then
        log_info "Rebuilding with Docker Compose..."
        $compose_cmd build --no-cache
        log_success "Rebuild completed"
    else
        log_error "Docker Compose not available for rebuild"
        return 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
TeaSpeak Docker Recovery Script

Usage: $0 [COMMAND]

Commands:
    emergency-stop      Emergency stop all TeaSpeak containers
    reset-data          Reset all TeaSpeak data (DANGEROUS!)
    fix-permissions     Fix file and directory permissions
    clean-docker        Clean unused Docker resources
    diagnose            Run system diagnostics
    rebuild             Rebuild containers from scratch
    help                Show this help

Examples:
    $0 emergency-stop
    $0 diagnose
    $0 fix-permissions
    $0 clean-docker

WARNING: Some commands are destructive and will delete data!
Always backup your data before running recovery operations.

EOF
}

# Main function
main() {
    # Change to script directory
    cd "$(dirname "$0")/.."
    
    case "${1:-help}" in
        emergency-stop)
            emergency_stop
            ;;
        reset-data)
            reset_data
            ;;
        fix-permissions)
            fix_permissions
            ;;
        clean-docker)
            clean_docker
            ;;
        diagnose)
            diagnose
            ;;
        rebuild)
            rebuild
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"