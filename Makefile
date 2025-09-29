# TeaSpeak Multi-Architecture Docker Build Makefile

# Configuration
DOCKER_HUB_USERNAME ?= your-dockerhub-username
VERSION ?= 1.4.22
PLATFORMS ?= linux/amd64,linux/arm64,linux/arm/v7

# Colors
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help build build-local build-multiarch start stop clean setup test

help: ## Show this help message
	@echo "$(BLUE)TeaSpeak Multi-Architecture Docker Build$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make <target> [DOCKER_HUB_USERNAME=username] [VERSION=version]"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Setup environment and dependencies
	@echo "$(BLUE)[INFO]$(NC) Setting up environment..."
	@cp -n .env.example .env 2>/dev/null || true
	@mkdir -p data/logs data/files data/database data/certs config
	@chmod 755 data/logs data/files data/database data/certs config
	@chmod +x scripts/*.sh
	@echo "$(GREEN)[SUCCESS]$(NC) Environment setup completed"

build: build-multiarch ## Build multi-architecture images (default)

build-local: setup ## Build images locally (current architecture only)
	@echo "$(BLUE)[INFO]$(NC) Building local images..."
	@./scripts/build.sh --local
	@echo "$(GREEN)[SUCCESS]$(NC) Local build completed"

build-multiarch: setup ## Build multi-architecture images and push to Docker Hub
	@echo "$(BLUE)[INFO]$(NC) Building multi-architecture images..."
	@if [ "$(DOCKER_HUB_USERNAME)" = "your-dockerhub-username" ]; then \
		echo "$(RED)[ERROR]$(NC) Please set DOCKER_HUB_USERNAME"; \
		exit 1; \
	fi
	@./scripts/build-multiarch.sh -u $(DOCKER_HUB_USERNAME) -v $(VERSION) -p $(PLATFORMS)
	@echo "$(GREEN)[SUCCESS]$(NC) Multi-architecture build completed"

start: setup ## Start TeaSpeak containers
	@echo "$(BLUE)[INFO]$(NC) Starting TeaSpeak containers..."
	@./scripts/start.sh -u $(DOCKER_HUB_USERNAME)
	@echo "$(GREEN)[SUCCESS]$(NC) TeaSpeak started"

stop: ## Stop TeaSpeak containers
	@echo "$(BLUE)[INFO]$(NC) Stopping TeaSpeak containers..."
	@./scripts/stop.sh
	@echo "$(GREEN)[SUCCESS]$(NC) TeaSpeak stopped"

clean: ## Clean up containers and images
	@echo "$(BLUE)[INFO]$(NC) Cleaning up..."
	@docker compose down -v --remove-orphans 2>/dev/null || true
	@docker system prune -f
	@echo "$(GREEN)[SUCCESS]$(NC) Cleanup completed"

config: ## Show current configuration
	@echo "$(BLUE)[INFO]$(NC) Current configuration:"
	@echo "  Docker Hub Username: $(YELLOW)$(DOCKER_HUB_USERNAME)$(NC)"
	@echo "  Version: $(YELLOW)$(VERSION)$(NC)"
	@echo "  Platforms: $(YELLOW)$(PLATFORMS)$(NC)"