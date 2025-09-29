#!/bin/bash

# TeaSpeak Docker Helper Script
# Utility functions and helpers for TeaSpeak management

# Source functions library
source "$(dirname "$0")/functions.sh" 2>/dev/null || {
    echo "Warning: functions.sh not found, using basic functions"
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Show TeaSpeak status
show_status() {
    log_info "TeaSpeak Container Status:"
    
    local compose_cmd=$(check_docker_compose)
    if [ $? -eq 0 ]; then
        $compose_cmd ps
    else
        docker ps --filter "name=teaspeak"
    fi
}

# Show TeaSpeak logs
show_logs() {
    local lines="${1:-50}"
    local follow="${2:-false}"
    
    log_info "TeaSpeak Logs (last $lines lines):"
    
    local compose_cmd=$(check_docker_compose)
    if [ $? -eq 0 ]; then
        if [ "$follow" = "true" ]; then
            $compose_cmd logs -f --tail="$lines"
        else
            $compose_cmd logs --tail="$lines"
        fi
    else
        if [ "$follow" = "true" ]; then
            docker logs -f --tail="$lines" teaspeak-server
        else
            docker logs --tail="$lines" teaspeak-server
        fi
    fi
}

# Get container IP
get_container_ip() {
    local container_name="${1:-teaspeak-server}"
    
    local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name" 2>/dev/null)
    
    if [ -n "$ip" ]; then
        echo "$ip"
    else
        log_error "Could not get IP for container: $container_name"
        return 1
    fi
}

# Test TeaSpeak connectivity
test_connectivity() {
    local host="${1:-localhost}"
    local voice_port="${2:-9987}"
    local query_port="${3:-10011}"
    local ft_port="${4:-30033}"
    
    log_info "Testing TeaSpeak connectivity..."
    
    # Test voice port (UDP)
    if nc -u -z "$host" "$voice_port" 2>/dev/null; then
        log_success "Voice port ($voice_port/udp) is accessible"
    else
        log_warning "Voice port ($voice_port/udp) is not accessible"
    fi
    
    # Test ServerQuery port (TCP)
    if nc -z "$host" "$query_port" 2>/dev/null; then
        log_success "ServerQuery port ($query_port/tcp) is accessible"
    else
        log_warning "ServerQuery port ($query_port/tcp) is not accessible"
    fi
    
    # Test FileTransfer port (TCP)
    if nc -z "$host" "$ft_port" 2>/dev/null; then
        log_success "FileTransfer port ($ft_port/tcp) is accessible"
    else
        log_warning "FileTransfer port ($ft_port/tcp) is not accessible"
    fi
}

# Backup TeaSpeak data
backup_data() {
    local backup_dir="${1:-./backups}"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="teaspeak_backup_$timestamp.tar.gz"
    
    log_info "Creating backup..."
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Create backup
    if tar -czf "$backup_dir/$backup_file" data/ config/ 2>/dev/null; then
        log_success "Backup created: $backup_dir/$backup_file"
        echo "$backup_dir/$backup_file"
    else
        log_error "Failed to create backup"
        return 1
    fi
}

# Restore TeaSpeak data
restore_data() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warning "This will overwrite existing data. Continue? (y/N)"
    read -r confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    log_info "Restoring from backup: $backup_file"
    
    if tar -xzf "$backup_file" 2>/dev/null; then
        log_success "Restore completed"
    else
        log_error "Failed to restore from backup"
        return 1
    fi
}

# Show system information
show_system_info() {
    log_info "System Information:"
    echo "  OS: $(uname -s)"
    echo "  Architecture: $(uname -m)"
    echo "  Kernel: $(uname -r)"
    
    if command_exists docker; then
        echo "  Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    fi
    
    local compose_cmd=$(check_docker_compose 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "  Docker Compose: $($compose_cmd --version | cut -d' ' -f4)"
    fi
    
    echo "  Detected Architecture: $(detect_architecture)"
}

# Show usage
show_usage() {
    cat << EOF
TeaSpeak Docker Helper Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    status              Show container status
    logs [lines]        Show logs (default: 50 lines)
    logs-follow [lines] Show and follow logs
    ip                  Get container IP address
    test [host]         Test connectivity (default: localhost)
    backup [dir]        Create data backup
    restore <file>      Restore from backup
    info                Show system information
    help                Show this help

Examples:
    $0 status
    $0 logs 100
    $0 logs-follow
    $0 test localhost
    $0 backup ./my-backups
    $0 restore ./backups/teaspeak_backup_20231201_120000.tar.gz

EOF
}

# Main function
main() {
    case "${1:-help}" in
        status)
            show_status
            ;;
        logs)
            show_logs "${2:-50}" false
            ;;
        logs-follow)
            show_logs "${2:-50}" true
            ;;
        ip)
            get_container_ip "${2:-teaspeak-server}"
            ;;
        test)
            test_connectivity "${2:-localhost}"
            ;;
        backup)
            backup_data "$2"
            ;;
        restore)
            if [ -z "$2" ]; then
                log_error "Backup file required"
                echo "Usage: $0 restore <backup_file>"
                exit 1
            fi
            restore_data "$2"
            ;;
        info)
            show_system_info
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

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi