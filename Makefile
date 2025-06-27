.PHONY: dev build clean test migrate setup-permissions

# Get current user UID and GID
export UID := $(shell id -u)
export GID := $(shell id -g)

# Setup - Fix permissions and create required files
setup:
	@echo "Setting up project..."
	@mkdir -p backend frontend database/init scripts nginx
	@touch backend/go.mod backend/go.sum
	@touch frontend/package.json
	@touch backend/.air.toml
	@echo "Setup completed!"

# Fix permissions
fix-permissions:
	@echo "Fixing file permissions..."
	@sudo chown -R $(UID):$(GID) .
	@chmod -R 755 .
	@chmod -R 644 backend/*.go backend/*.mod backend/*.sum backend/.air.toml || true
	@chmod -R 644 frontend/package*.json || true
	@chmod +x scripts/*.sh || true
	@echo "Permissions fixed!"

# Development
dev: setup
	@echo "Starting development environment..."
	@echo "Using UID=$(UID) GID=$(GID)"
	docker-compose -f docker-compose.dev.yml up --build

dev-down:
	docker-compose -f docker-compose.dev.yml down

# Development without build cache
dev-fresh: setup
	docker-compose -f docker-compose.dev.yml up --build --force-recreate

# Production
build:
	docker-compose up --build -d

down:
	docker-compose down

# Database
migrate-up:
	docker exec go_backend_dev migrate -path ./migrations -database "postgres://$(DB_USER):$(DB_PASSWORD)@postgres:5432/$(DB_NAME)?sslmode=disable" up

migrate-down:
	docker exec go_backend_dev migrate -path ./migrations -database "postgres://$(DB_USER):$(DB_PASSWORD)@postgres:5432/$(DB_NAME)?sslmode=disable" down

# Cleanup
clean:
	docker system prune -f
	docker volume prune -f

# Reset everything
reset: clean
	docker-compose -f docker-compose.dev.yml down -v
	docker rmi $(shell docker images -q) || true

# Logs
logs-backend:
	docker logs -f go_backend_dev

logs-frontend:
	docker logs -f svelte_frontend_dev

logs-postgres:
	docker logs -f postgres_dev

# Testing
test-backend:
	cd backend && go test ./...

test-frontend:
	cd frontend && npm test

# Package management
install-go:
	@read -p "Enter Go package name: " package; \
	./scripts/install-go-package.sh $package

install-npm:
	@read -p "Enter NPM package name: " package; \
	./scripts/install-npm-package.sh $package

install-npm-dev:
	@read -p "Enter NPM dev package name: " package; \
	./scripts/install-npm-package.sh $package --dev

# Container access
backend-shell:
	docker exec -it go_backend_dev sh

frontend-shell:
	docker exec -it svelte_frontend_dev sh

postgres-shell:
	docker exec -it postgres_dev psql -U $(DB_USER) -d $(DB_NAME)

# Status
status:
	docker-compose -f docker-compose.dev.yml ps

# Help
help:
	@echo "Available commands:"
	@echo "  setup              - Create required directories and files"
	@echo "  fix-permissions    - Fix file permissions"
	@echo "  dev               - Start development environment"
	@echo "  dev-fresh         - Start development with clean build"
	@echo "  dev-down          - Stop development environment"
	@echo "  build             - Build for production"
	@echo "  clean             - Clean Docker cache"
	@echo "  reset             - Reset everything (careful!)"
	@echo "  logs-*            - View logs for specific service"
	@echo "  *-shell           - Access container shell"
	@echo "  status            - Show container status"
