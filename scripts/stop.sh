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

Stop TeaSpeak Docker containers

OPTIONS:
    -f, --file FILE           Docker Compose file (default: docker-compose.yml)
    -v, --volumes             Remove volumes as well (WARNING: Data will be lost!)
    --remove-orphans          Remove orphaned containers
    --timeout TIMEOUT         Timeout for container shutdown (default: 10s)
    -h, --help                Show this help message

EXAMPLES:
    $0                        # Stop containers
    $0 -v                     # Stop containers and remove volumes
    $0 --remove-orphans       # Stop and remove orphaned containers

EOF
}

# Default values
COMPOSE_FILE="docker-compose.yml"
REMOVE_VOLUMES=false
REMOVE_ORPHANS=false
TIMEOUT=10

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        --remove-orphans)
            REMOVE_ORPHANS=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
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

# Show current status
log_info "Current container status:"
$COMPOSE_CMD -f "$COMPOSE_FILE" ps 2>/dev/null || log_warning "No containers found or compose file issue"

# Stop containers
log_info "Stopping TeaSpeak Docker containers..."

CMD_ARGS="-f $COMPOSE_FILE down -t $TIMEOUT"

if [ "$REMOVE_VOLUMES" = true ]; then
    CMD_ARGS="$CMD_ARGS -v"
    log_warning "⚠️  Volumes will be removed (data will be lost!)"
fi

if [ "$REMOVE_ORPHANS" = true ]; then
    CMD_ARGS="$CMD_ARGS --remove-orphans"
fi

log_info "Running: $COMPOSE_CMD $CMD_ARGS"

if $COMPOSE_CMD $CMD_ARGS; then
    log_success "TeaSpeak containers stopped successfully!"
else
    log_error "Failed to stop some containers"
    exit 1
fi

# Cleanup resources
log_info "Cleaning up Docker resources..."

# Remove unused networks
if docker network prune -f &> /dev/null; then
    log_info "Cleaned up unused networks"
fi

# Remove unused images (only dangling ones)
if docker image prune -f &> /dev/null; then
    log_info "Cleaned up dangling images"
fi

log_success "Resource cleanup completed"

# Final status check
log_info "Final status check..."
RUNNING_CONTAINERS=$($COMPOSE_CMD -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)

if [ "$RUNNING_CONTAINERS" -eq 0 ]; then
    log_success "✅ All TeaSpeak containers have been stopped"
else
    log_warning "⚠️  Some containers may still be running"
    $COMPOSE_CMD -f "$COMPOSE_FILE" ps
fi

log_success "✅ TeaSpeak shutdown completed successfully!"

if [ "$REMOVE_VOLUMES" = false ]; then
    log_info "💾 Data volumes preserved"
    log_info "🔄 Use './scripts/start.sh -u <username>' to restart TeaSpeak"
else
    log_warning "🗑️  Data volumes were removed"
    log_info "🆕 Next start will create fresh installation"
fi