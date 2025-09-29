#!/bin/bash

# TeaSpeak Docker Update Script
# Update TeaSpeak images and containers

set -e

# Source functions library
source "$(dirname "$0")/functions.sh" 2>/dev/null || {
    echo "Warning: functions.sh not found, using basic functions"
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
}

# Configuration
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-teaspeak}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
BACKUP_BEFORE_UPDATE=true

# Show banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    TeaSpeak Update                          ║"
    echo "║              Multi-Architecture Docker                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check for updates
check_updates() {
    log_info "Checking for updates..."
    
    local compose_cmd=$(check_docker_compose)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Get current image ID
    local current_image=$(docker images --format "{{.ID}}" "${DOCKER_HUB_USERNAME}/teaspeak-server:latest" 2>/dev/null | head -1)
    
    # Pull latest image
    log_info "Pulling latest image..."
    if $compose_cmd pull; then
        log_success "Image pull completed"
    else
        log_error "Failed to pull latest image"
        return 1
    fi
    
    # Get new image ID
    local new_image=$(docker images --format "{{.ID}}" "${DOCKER_HUB_USERNAME}/teaspeak-server:latest" 2>/dev/null | head -1)
    
    if [ "$current_image" = "$new_image" ] && [ -n "$current_image" ]; then
        log_info "No updates available"
        return 1
    else
        log_success "Updates available"
        return 0
    fi
}

# Create backup
create_backup() {
    if [ "$BACKUP_BEFORE_UPDATE" = false ]; then
        return 0
    fi
    
    log_info "Creating backup before update..."
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_dir="./backups"
    local backup_file="teaspeak_pre_update_$timestamp.tar.gz"
    
    mkdir -p "$backup_dir"
    
    if tar -czf "$backup_dir/$backup_file" data/ config/ .env 2>/dev/null; then
        log_success "Backup created: $backup_dir/$backup_file"
        echo "$backup_dir/$backup_file"
    else
        log_warning "Failed to create backup, continuing anyway..."
    fi
}

# Stop services
stop_services() {
    log_info "Stopping TeaSpeak services..."
    
    local compose_cmd=$(check_docker_compose)
    
    if $compose_cmd down --timeout 30; then
        log_success "Services stopped"
    else
        log_warning "Some services may not have stopped cleanly"
    fi
}

# Start services
start_services() {
    log_info "Starting updated TeaSpeak services..."
    
    local compose_cmd=$(check_docker_compose)
    
    if $compose_cmd up -d; then
        log_success "Services started"
    else
        log_error "Failed to start services"
        return 1
    fi
}

# Verify update
verify_update() {
    log_info "Verifying update..."
    
    # Wait for services to be ready
    if wait_for_service "localhost" "10011" 60; then
        log_success "TeaSpeak is running after update"
    else
        log_error "TeaSpeak may not be running properly after update"
        return 1
    fi
    
    # Show container status
    local compose_cmd=$(check_docker_compose)
    $compose_cmd ps
}

# Cleanup old images
cleanup_old_images() {
    log_info "Cleaning up old images..."
    
    # Remove dangling images
    local dangling=$(docker images -f "dangling=true" -q 2>/dev/null)
    if [ -n "$dangling" ]; then
        echo "$dangling" | xargs docker rmi 2>/dev/null || true
        log_info "Removed dangling images"
    fi
    
    # Remove old TeaSpeak images (keep latest 2)
    local old_images=$(docker images "${DOCKER_HUB_USERNAME}/teaspeak-server" --format "{{.ID}}" | tail -n +3 2>/dev/null)
    if [ -n "$old_images" ]; then
        echo "$old_images" | xargs docker rmi 2>/dev/null || true
        log_info "Removed old TeaSpeak images"
    fi
    
    log_success "Cleanup completed"
}

# Rollback function
rollback() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        log_error "No backup file specified or file not found"
        return 1
    fi
    
    log_warning "Rolling back to previous version..."
    
    # Stop current services
    stop_services
    
    # Restore backup
    log_info "Restoring from backup: $backup_file"
    if tar -xzf "$backup_file" 2>/dev/null; then
        log_success "Backup restored"
    else
        log_error "Failed to restore backup"
        return 1
    fi
    
    # Start services
    start_services
    
    log_success "Rollback completed"
}

# Show update summary
show_summary() {
    log_success "✅ TeaSpeak update completed!"
    echo ""
    log_info "📋 Updated Services:"
    
    local compose_cmd=$(check_docker_compose)
    $compose_cmd ps
    
    echo ""
    log_info "🔧 Post-Update Commands:"
    echo "   View logs: docker compose logs -f"
    echo "   Check status: docker compose ps"
    echo "   Helper tools: ./scripts/helper.sh"
    
    if [ -n "$BACKUP_FILE" ]; then
        echo ""
        log_info "💾 Backup Location: $BACKUP_FILE"
        echo "   Rollback: $0 rollback $BACKUP_FILE"
    fi
}

# Show usage
show_usage() {
    cat << EOF
TeaSpeak Docker Update Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    update              Update TeaSpeak to latest version (default)
    check               Check for available updates
    rollback <file>     Rollback to previous backup
    help                Show this help

Options:
    --username USERNAME     Docker Hub username (default: teaspeak)
    --compose-file FILE     Docker Compose file (default: docker-compose.yml)
    --no-backup            Skip backup creation
    --no-cleanup           Skip cleanup of old images
    --force                Force update even if no changes detected

Examples:
    $0                                    # Update with defaults
    $0 check                             # Check for updates only
    $0 --username myuser                 # Update with custom username
    $0 rollback ./backups/backup.tar.gz # Rollback to backup

EOF
}

# Parse arguments
parse_arguments() {
    COMMAND="update"
    FORCE_UPDATE=false
    CLEANUP_OLD=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            update|check|rollback)
                COMMAND="$1"
                if [ "$COMMAND" = "rollback" ]; then
                    ROLLBACK_FILE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --username)
                DOCKER_HUB_USERNAME="$2"
                shift 2
                ;;
            --compose-file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            --no-backup)
                BACKUP_BEFORE_UPDATE=false
                shift
                ;;
            --no-cleanup)
                CLEANUP_OLD=false
                shift
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            -h|--help|help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    show_banner
    
    # Parse arguments
    parse_arguments "$@"
    
    # Change to script directory
    cd "$(dirname "$0")/.."
    
    # Export environment variables
    export DOCKER_HUB_USERNAME
    
    case "$COMMAND" in
        check)
            log_info "Checking for TeaSpeak updates..."
            if check_updates; then
                log_success "Updates are available!"
                log_info "Run '$0 update' to apply updates"
            else
                log_info "TeaSpeak is up to date"
            fi
            ;;
        rollback)
            if [ -z "$ROLLBACK_FILE" ]; then
                log_error "Rollback file required"
                echo "Usage: $0 rollback <backup_file>"
                exit 1
            fi
            rollback "$ROLLBACK_FILE"
            ;;
        update)
            log_info "Starting TeaSpeak update process..."
            
            # Check for updates unless forced
            if [ "$FORCE_UPDATE" = false ]; then
                if ! check_updates; then
                    log_info "No updates needed"
                    exit 0
                fi
            fi
            
            # Create backup
            BACKUP_FILE=$(create_backup)
            
            # Update process
            stop_services
            start_services
            verify_update
            
            if [ "$CLEANUP_OLD" = true ]; then
                cleanup_old_images
            fi
            
            show_summary
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"