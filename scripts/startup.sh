#!/bin/bash

# TeaSpeak Docker Startup Script
# Alternative startup script with additional features

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
WAIT_TIMEOUT=60

# Show banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    TeaSpeak Startup                         ║"
    echo "║              Multi-Architecture Docker                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Pre-startup checks
pre_startup_checks() {
    log_info "Running pre-startup checks..."
    
    # Check Docker
    if ! check_docker; then
        exit 1
    fi
    
    # Check Docker Compose
    local compose_cmd=$(check_docker_compose)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Check compose file
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    # Check TeaSpeak directory
    if [ ! -d "TeaSpeak-1.4.22" ]; then
        log_error "TeaSpeak directory not found: TeaSpeak-1.4.22"
        exit 1
    fi
    
    log_success "Pre-startup checks passed"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    # Create directories
    create_directories
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            sed -i "s/your-dockerhub-username/$DOCKER_HUB_USERNAME/g" .env 2>/dev/null || true
            log_info "Created .env file from template"
        else
            log_warning ".env.example not found, creating basic .env file"
            cat > .env << EOF
DOCKER_HUB_USERNAME=$DOCKER_HUB_USERNAME
VERSION=1.4.22
VOICE_PORT=9987
QUERY_PORT=10011
FILETRANSFER_PORT=30033
SERVER_NAME=TeaSpeak Server
EOF
        fi
    fi
    
    # Set permissions
    set_permissions scripts/*.sh *.sh
    
    # Export environment variables
    export DOCKER_HUB_USERNAME
    export TEASPEAK_ARCH="linux/$(detect_architecture)"
    
    log_success "Environment setup completed"
}

# Check port availability
check_ports() {
    log_info "Checking port availability..."
    
    local ports=("9987" "10011" "30033")
    local conflicts=()
    
    for port in "${ports[@]}"; do
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            conflicts+=("$port")
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        log_warning "The following ports are already in use: ${conflicts[*]}"
        log_warning "This may cause conflicts with TeaSpeak"
        
        read -p "Continue anyway? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            log_info "Startup cancelled"
            exit 0
        fi
    else
        log_success "All required ports are available"
    fi
}

# Pull images if needed
pull_images() {
    log_info "Checking for image updates..."
    
    local compose_cmd=$(check_docker_compose)
    
    # Try to pull images
    if $compose_cmd pull 2>/dev/null; then
        log_success "Images updated"
    else
        log_warning "Could not pull images (using local images)"
    fi
}

# Start containers
start_containers() {
    log_info "Starting TeaSpeak containers..."
    
    local compose_cmd=$(check_docker_compose)
    
    # Start containers
    if $compose_cmd up -d; then
        log_success "Containers started"
    else
        log_error "Failed to start containers"
        return 1
    fi
}

# Wait for services
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    # Wait for ServerQuery port
    if wait_for_service "localhost" "10011" "$WAIT_TIMEOUT"; then
        log_success "TeaSpeak ServerQuery is ready"
    else
        log_warning "TeaSpeak ServerQuery may not be ready"
    fi
    
    # Check if voice port is listening (UDP is harder to test)
    sleep 5
    if netstat -ln 2>/dev/null | grep -q ":9987 "; then
        log_success "TeaSpeak Voice server is ready"
    else
        log_warning "TeaSpeak Voice server may not be ready"
    fi
}

# Show startup summary
show_summary() {
    log_info "TeaSpeak startup completed!"
    echo ""
    log_success "🎉 TeaSpeak is now running!"
    echo ""
    log_info "📋 Connection Information:"
    log_success "   Voice Server: localhost:9987"
    log_success "   ServerQuery: localhost:10011"
    log_success "   File Transfer: localhost:30033"
    echo ""
    log_info "🔧 Management Commands:"
    echo "   View logs: docker compose logs -f"
    echo "   Stop server: ./scripts/stop.sh"
    echo "   Check status: docker compose ps"
    echo "   Helper tools: ./scripts/helper.sh"
    echo ""
    log_info "🐳 Docker Hub Image: $DOCKER_HUB_USERNAME/teaspeak-server:latest"
    log_info "🏗️  Architecture: $(detect_architecture)"
}

# Show usage
show_usage() {
    cat << EOF
TeaSpeak Docker Startup Script

Usage: $0 [OPTIONS]

OPTIONS:
    --username USERNAME       Docker Hub username (default: teaspeak)
    --compose-file FILE       Docker Compose file (default: docker-compose.yml)
    --no-pull                Don't pull image updates
    --no-port-check          Skip port availability check
    --timeout SECONDS        Service wait timeout (default: 60)
    -h, --help               Show this help

EXAMPLES:
    $0                                    # Start with defaults
    $0 --username myuser                  # Use custom Docker Hub username
    $0 --no-pull --no-port-check         # Quick start without checks

EOF
}

# Parse arguments
parse_arguments() {
    PULL_IMAGES=true
    CHECK_PORTS=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --username)
                DOCKER_HUB_USERNAME="$2"
                shift 2
                ;;
            --compose-file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            --no-pull)
                PULL_IMAGES=false
                shift
                ;;
            --no-port-check)
                CHECK_PORTS=false
                shift
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
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
    
    log_info "Starting TeaSpeak with configuration:"
    log_info "  Docker Hub Username: $DOCKER_HUB_USERNAME"
    log_info "  Compose File: $COMPOSE_FILE"
    log_info "  Pull Images: $PULL_IMAGES"
    log_info "  Check Ports: $CHECK_PORTS"
    log_info "  Wait Timeout: ${WAIT_TIMEOUT}s"
    
    # Run startup sequence
    pre_startup_checks
    setup_environment
    
    if [ "$CHECK_PORTS" = true ]; then
        check_ports
    fi
    
    if [ "$PULL_IMAGES" = true ]; then
        pull_images
    fi
    
    start_containers
    wait_for_services
    show_summary
}

# Run main function
main "$@"