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

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Start TeaSpeak Docker containers

OPTIONS:
    -u, --username USERNAME    Docker Hub username (required)
    -f, --file FILE           Docker Compose file (default: docker-compose.yml)
    -p, --profile PROFILE     Docker Compose profile
    --pull                    Pull latest images before starting
    --build                   Build images locally before starting
    -d, --detach              Run in detached mode (default)
    --logs                    Show logs after starting
    -h, --help                Show this help message

EXAMPLES:
    $0 -u myusername                      # Start with Docker Hub username
    $0 -u myusername -p web              # Start with web interface
    $0 -u myusername --pull              # Pull latest images first

EOF
}

# Default values
COMPOSE_FILE="docker-compose.yml"
DOCKER_HUB_USERNAME=""
PROFILE=""
DETACH=true
PULL=false
BUILD=false
SHOW_LOGS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            DOCKER_HUB_USERNAME="$2"
            shift 2
            ;;
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        --pull)
            PULL=true
            shift
            ;;
        --build)
            BUILD=true
            shift
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        --logs)
            SHOW_LOGS=true
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

# Validate required parameters
if [ -z "$DOCKER_HUB_USERNAME" ]; then
    log_error "Docker Hub username is required"
    log_info "Usage: $0 -u <username>"
    exit 1
fi

# Check requirements
log_info "Checking requirements..."

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check Docker Compose
COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose --version &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    log_error "Docker Compose is not available"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Docker Compose file not found: $COMPOSE_FILE"
    exit 1
fi

log_success "Requirements check passed"

# Setup environment
log_info "Setting up environment..."

# Export environment variables
export DOCKER_HUB_USERNAME
export TEASPEAK_TAG="latest"

# Create necessary directories
mkdir -p data/{logs,files,database,certs} config
chmod 755 data/{logs,files,database,certs} config 2>/dev/null || true

log_success "Environment setup completed"

# Detect architecture
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

ARCH=$(detect_architecture)
log_info "Detected architecture: $ARCH"
export TEASPEAK_ARCH="linux/$ARCH"

# Pull images if requested
if [ "$PULL" = true ]; then
    log_info "Pulling latest images..."
    
    if [ -n "$PROFILE" ]; then
        $COMPOSE_CMD -f "$COMPOSE_FILE" --profile "$PROFILE" pull
    else
        $COMPOSE_CMD -f "$COMPOSE_FILE" pull
    fi
    
    log_success "Images pulled successfully"
fi

# Build images if requested
if [ "$BUILD" = true ]; then
    log_info "Building images locally..."
    
    if [ -n "$PROFILE" ]; then
        $COMPOSE_CMD -f "$COMPOSE_FILE" --profile "$PROFILE" build
    else
        $COMPOSE_CMD -f "$COMPOSE_FILE" build
    fi
    
    log_success "Images built successfully"
fi

# Start containers
log_info "Starting TeaSpeak Docker containers..."

CMD_ARGS="-f $COMPOSE_FILE"

if [ -n "$PROFILE" ]; then
    CMD_ARGS="$CMD_ARGS --profile $PROFILE"
    log_info "Using profile: $PROFILE"
fi

if [ "$DETACH" = true ]; then
    CMD_ARGS="$CMD_ARGS up -d"
else
    CMD_ARGS="$CMD_ARGS up"
fi

log_info "Running: $COMPOSE_CMD $CMD_ARGS"

if $COMPOSE_CMD $CMD_ARGS; then
    log_success "TeaSpeak containers started successfully!"
else
    log_error "Failed to start containers"
    exit 1
fi

# Show status
log_info "Container status:"
$COMPOSE_CMD -f "$COMPOSE_FILE" ps

# Show service information
log_info "Service information:"
log_success "✅ Voice port: 9987/udp"
log_success "✅ ServerQuery port: 10011"
log_success "✅ FileTransfer port: 30033"

if [ -n "$PROFILE" ] && [ "$PROFILE" = "web" ]; then
    log_success "✅ Web interface: http://localhost:8080"
fi

log_info "Docker Hub image: $DOCKER_HUB_USERNAME/teaspeak-server:latest (multi-architecture)"
log_info "Architecture: $ARCH (auto-detected)"

# Show logs if requested
if [ "$SHOW_LOGS" = true ]; then
    log_info "Showing container logs..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" logs -f
fi

log_success "✅ TeaSpeak deployment completed successfully!"

if [ "$DETACH" = true ]; then
    log_info "Containers are running in the background"
    log_info "Use 'docker compose -f $COMPOSE_FILE logs -f' to view logs"
    log_info "Use './scripts/stop.sh' to stop containers"
fi