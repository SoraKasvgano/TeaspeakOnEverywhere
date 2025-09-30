#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    TeaSpeak Quick Start                      ║"
    echo "║              Multi-Architecture Docker Setup                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Quick start script for TeaSpeak multi-architecture Docker deployment

OPTIONS:
    --build-and-push          Build images and push to Docker Hub
    --start-only              Only start existing containers
    --username USERNAME       Docker Hub username
    --interactive             Interactive mode (default)
    -h, --help               Show this help message

EXAMPLES:
    $0                                    # Interactive mode
    $0 --build-and-push --username myuser # Build and push
    $0 --start-only --username myuser     # Start only

EOF
}

interactive_setup() {
    log_info "Starting interactive setup..."
    
    # Get Docker Hub username
    read -p "🐳 Enter your Docker Hub username: " DOCKER_HUB_USERNAME
    if [ -z "$DOCKER_HUB_USERNAME" ]; then
        log_error "Docker Hub username is required"
        exit 1
    fi
    
    # Ask what to do
    echo ""
    echo "What would you like to do?"
    echo "1) Build multi-architecture images and push to Docker Hub"
    echo "2) Start TeaSpeak using existing images"
    echo "3) Build locally and start"
    read -p "Choose option (1-3): " choice
    
    case $choice in
        1)
            BUILD_AND_PUSH=true
            START_ONLY=false
            ;;
        2)
            BUILD_AND_PUSH=false
            START_ONLY=true
            ;;
        3)
            BUILD_AND_PUSH=false
            START_ONLY=false
            BUILD_LOCAL=true
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

setup_environment() {
    log_info "Setting up environment..."
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        cp .env.example .env
        sed -i "s/your-dockerhub-username/$DOCKER_HUB_USERNAME/g" .env
        log_success "Created .env file"
    fi
    
    # Create directories
    mkdir -p data/{logs,files,database,certs} config
    chmod 755 data/{logs,files,database,certs} config
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    log_success "Environment setup completed"
}

build_and_push() {
    log_info "Building and pushing multi-architecture images..."
    
    # Use the enhanced Python script with automatic parameters
    log_info "Using build_images_fixed.py for multi-architecture build..."
    
    # Create temporary input for the Python script
    {
        echo "y"  # Build pre-downloaded only
        echo "latest"  # Use latest as tag
        echo "y"  # Push to Docker Hub
        echo "$DOCKER_HUB_USERNAME"  # Docker Hub username
    } | python3 build_images_fixed.py
    
    if [ $? -ne 0 ]; then
        log_error "Build failed"
        exit 1
    fi
    
    log_success "Build and push completed"
}

build_local() {
    log_info "Building local images..."
    
    # Use the Python script for local build
    log_info "Using build_images_fixed.py for local build..."
    
    # Create temporary input for local build
    {
        echo "y"  # Build pre-downloaded only
        echo "latest"  # Use latest as tag
        echo "n"  # Don't push to Docker Hub (local build)
    } | python3 build_images_fixed.py
    
    if [ $? -ne 0 ]; then
        log_error "Local build failed"
        exit 1
    fi
    
    log_success "Local build completed"
}

start_teaspeak() {
    log_info "Starting TeaSpeak..."
    
    # Use unified latest tag that supports multi-architecture
    if ! ./scripts/start.sh -u "$DOCKER_HUB_USERNAME"; then
        log_error "Failed to start TeaSpeak"
        exit 1
    fi
    
    log_success "TeaSpeak started successfully"
    
    # Show connection info
    echo ""
    log_info "🎉 TeaSpeak is now running!"
    log_info "📋 Connection details:"
    log_success "   Voice Server: localhost:9987"
    log_success "   ServerQuery: localhost:10011"
    log_success "   File Transfer: localhost:30033"
    echo ""
    log_info "💡 Useful commands:"
    echo "   View logs: docker compose logs -f"
    echo "   Stop server: ./scripts/stop.sh"
    echo "   Check status: docker compose ps"
}

main() {
    show_banner
    
    # Parse arguments
    BUILD_AND_PUSH=false
    START_ONLY=false
    BUILD_LOCAL=false
    INTERACTIVE=true
    DOCKER_HUB_USERNAME=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-and-push)
                BUILD_AND_PUSH=true
                INTERACTIVE=false
                shift
                ;;
            --start-only)
                START_ONLY=true
                INTERACTIVE=false
                shift
                ;;
            --username)
                DOCKER_HUB_USERNAME="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE=true
                shift
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
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    # Interactive mode
    if [ "$INTERACTIVE" = true ]; then
        interactive_setup
    fi
    
    # Validate username
    if [ -z "$DOCKER_HUB_USERNAME" ]; then
        log_error "Docker Hub username is required"
        exit 1
    fi
    
    # Setup environment
    setup_environment
    
    # Execute based on options
    if [ "$BUILD_AND_PUSH" = true ]; then
        build_and_push
    elif [ "$BUILD_LOCAL" = true ]; then
        build_local
    fi
    
    if [ "$START_ONLY" = true ] || [ "$BUILD_AND_PUSH" = true ] || [ "$BUILD_LOCAL" = true ]; then
        start_teaspeak
    fi
    
    log_success "✅ Quick start completed!"
}

# Run main function
main "$@"