.PHONY: build run stop logs shell clean restart status all help test test-validation test-password test-backend test-required test-category test-sessions test-forum test-endpoints test-comment test-status test-http test-templates test-cleanup db backup check-db download-db upload-db

IMAGE_NAME = forum-app:latest
CONTAINER_NAME = forum
PORT = 8080

help:
	@echo "Forum Application - Docker Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  make build       - Build Docker image"
	@echo "  make run         - Start container (uses local forum.db)"
	@echo "  make stop        - Stop container"
	@echo "  make logs        - View logs"
	@echo "  make shell       - Open shell in container"
	@echo "  make restart     - Restart container"
	@echo "  make clean       - Remove container and image"
	@echo "  make clean-all   - Remove everything including database"
	@echo "  make status      - Show container status"
	@echo ""
	@echo "Testing commands:"
	@echo "  make test            - Run all tests (master test runner)"
	@echo "  make test-validation - Run input validation tests"
	@echo "  make test-password   - Run password policy tests"
	@echo "  make test-backend    - Run backend validation tests"
	@echo "  make test-required   - Run required fields tests"
	@echo "  make test-category   - Run category validation tests"
	@echo "  make test-sessions   - Run session management tests"
	@echo "  make test-forum      - Run forum integration tests"
	@echo "  make test-endpoints  - Run security & endpoint tests"
	@echo "  make test-comment    - Run comment route security tests"
	@echo "  make test-status     - Run HTTP status code tests"
	@echo "  make test-http       - Run HTTP method tests"
	@echo "  make test-templates  - Run template error tests"
	@echo "  make test-cleanup    - Cleanup test users from database"
	@echo ""
	@echo "Database commands:"
	@echo "  make db          - Access database (SQLite shell)"
	@echo "  make backup      - Backup database"
	@echo "  make check-db    - Check database stats"
	@echo "  make download-db - Download DB from container"
	@echo "  make upload-db   - Upload local DB to container"

build:
	@echo "🔨 Building Docker image..."
	docker build -t $(IMAGE_NAME) .
	@echo "✅ Build complete"

run:
	@echo "🚀 Starting container with local database..."
	@if docker ps -a -f name=$(CONTAINER_NAME) | grep -q $(CONTAINER_NAME); then \
		echo "⚠️  Existing container found, removing..."; \
		docker stop $(CONTAINER_NAME) 2>/dev/null || true; \
		docker rm $(CONTAINER_NAME) 2>/dev/null || true; \
	fi
	@if [ ! -f "./forum.db" ]; then \
		echo "🆕 Creating empty forum.db file..."; \
		touch ./forum.db; \
		chmod 666 ./forum.db; \
		echo "💡 Database will be initialized on first request"; \
	else \
		echo "📊 Using existing forum.db"; \
	fi
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p $(PORT):$(PORT) \
		-v $(PWD):/app/data \
		-e PORT=$(PORT) \
		-e DATABASE_URL=/app/data/forum.db \
		-e JWT_SECRET=dev-secret \
		-e TZ=Asia/Almaty \
		$(IMAGE_NAME)
	@echo "✅ Container started: http://localhost:$(PORT)"
	@echo "💾 Database location: $(PWD)/forum.db"
	@sleep 2
	@make logs | head -n 20 || true

stop:
	@echo "🛑 Stopping container..."
	@docker stop $(CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(CONTAINER_NAME) 2>/dev/null || true
	@echo "✅ Container stopped"

logs:
	@echo "📋 Viewing logs (Ctrl+C to exit)..."
	@docker logs -f $(CONTAINER_NAME) || echo "❌ Container not running"

shell:
	@echo "🐚 Opening shell in container..."
	@docker exec -it $(CONTAINER_NAME) sh || echo "❌ Container not running"

restart:
	@echo "🔄 Restarting container..."
	@make stop
	@make run

clean: stop
	@echo "🧹 Cleaning up Docker resources..."
	@docker rmi $(IMAGE_NAME) 2>/dev/null || true
	@echo "✅ Cleanup complete"
	@if [ -f "./forum.db" ]; then \
		echo "💾 Local forum.db preserved at: $(PWD)/forum.db"; \
	fi

clean-all: stop
	@echo "🧹 Cleaning up everything..."
	@docker rmi $(IMAGE_NAME) 2>/dev/null || true
	@echo "⚠️  Removing database files..."
	@rm -f forum.db forum.db-shm forum.db-wal
	@echo "✅ Complete cleanup done"

status:
	@echo "📊 Container Status:"
	@echo "===================="
	@docker ps -a -f name=$(CONTAINER_NAME) || echo "❌ Container not found"
	@echo ""
	@echo "💾 Database Status:"
	@echo "===================="
	@if [ -f "./forum.db" ]; then \
		echo "✅ Local database: forum.db ($(shell du -h forum.db 2>/dev/null | cut -f1))"; \
		echo "📍 Location: $(PWD)/forum.db"; \
	else \
		echo "❌ No local database found"; \
	fi

# ======================================
# TESTING COMMANDS (All 12 Test Suites)
# ======================================

test:
	@echo "🧪 Running all tests (master test runner)..."
	@if [ -f "./scripts/test/run_all_tests.sh" ]; then \
		chmod +x ./scripts/test/run_all_tests.sh; \
		./scripts/test/run_all_tests.sh; \
	else \
		echo "❌ Test runner not found at scripts/test/run_all_tests.sh"; \
		exit 1; \
	fi

test-validation:
	@echo "🧪 Running input validation tests..."
	@chmod +x ./scripts/test/test_validation.sh
	@./scripts/test/test_validation.sh

test-password:
	@echo "🧪 Running password policy tests..."
	@chmod +x ./scripts/test/test_password_validation.sh
	@./scripts/test/test_password_validation.sh

test-backend:
	@echo "🧪 Running backend validation tests..."
	@chmod +x ./scripts/test/test_backend_validation.sh
	@./scripts/test/test_backend_validation.sh

test-required:
	@echo "🧪 Running required fields tests..."
	@chmod +x ./scripts/test/test_post_required_fields.sh
	@./scripts/test/test_post_required_fields.sh

test-category:
	@echo "🧪 Running category validation tests..."
	@chmod +x ./scripts/test/test_category.sh
	@./scripts/test/test_category.sh

test-sessions:
	@echo "🧪 Running session management tests..."
	@chmod +x ./scripts/test/test_sessions.sh
	@./scripts/test/test_sessions.sh

test-forum:
	@echo "🧪 Running forum integration tests..."
	@chmod +x ./scripts/test/test_forum.sh
	@./scripts/test/test_forum.sh

test-endpoints:
	@echo "🧪 Running security & endpoint tests..."
	@chmod +x ./scripts/test/test_forum_endpoints.sh
	@./scripts/test/test_forum_endpoints.sh

test-comment:
	@echo "🧪 Running comment route security tests..."
	@chmod +x ./scripts/test/test_comment_routes.sh
	@./scripts/test/test_comment_routes.sh

test-status:
	@echo "🧪 Running HTTP status code tests..."
	@chmod +x ./scripts/test/test_status_codes.sh
	@./scripts/test/test_status_codes.sh

test-http:
	@echo "🧪 Running HTTP method tests..."
	@chmod +x ./scripts/test/test_http_methods.sh
	@./scripts/test/test_http_methods.sh

test-templates:
	@echo "🧪 Running template error tests..."
	@chmod +x ./scripts/test/test_templates.sh
	@./scripts/test/test_templates.sh

test-cleanup:
	@echo "🧹 Cleaning up test users from database..."
	@chmod +x ./scripts/setup/cleanup_test_users.sh
	@./scripts/setup/cleanup_test_users.sh

# ======================================
# DATABASE COMMANDS
# ======================================

db:
	@echo "💾 Opening database shell..."
	@echo "💡 Tip: Use .tables, .schema, .quit commands"
	@echo ""
	@if [ -f "./forum.db" ]; then \
		sqlite3 ./forum.db; \
	else \
		echo "❌ No forum.db found. Run 'make run' first"; \
	fi

backup:
	@echo "💾 Backing up database..."
	@mkdir -p ./backups
	@if [ -f "./forum.db" ]; then \
		BACKUP_FILE="./backups/forum_backup_$$(date +%Y%m%d_%H%M%S).db"; \
		cp ./forum.db "$$BACKUP_FILE"; \
		echo "✅ Backup saved: $$BACKUP_FILE"; \
		echo "📊 Backup size: $$(du -h "$$BACKUP_FILE" | cut -f1)"; \
	else \
		echo "❌ No forum.db found to backup"; \
	fi

check-db:
	@echo "🔍 Database Statistics"
	@echo "======================"
	@if [ -f "./forum.db" ]; then \
		echo "📊 File size: $$(du -h forum.db | cut -f1)"; \
		echo "📍 Location: $(PWD)/forum.db"; \
		echo ""; \
		echo "📈 Content:"; \
		sqlite3 forum.db "SELECT '  Users: ' || COUNT(*) FROM users; \
		                  SELECT '  Posts: ' || COUNT(*) FROM posts; \
		                  SELECT '  Comments: ' || COUNT(*) FROM comments; \
		                  SELECT '  Categories: ' || COUNT(*) FROM categories; \
		                  SELECT '  Sessions: ' || COUNT(*) FROM sessions;"; \
	else \
		echo "❌ No forum.db found"; \
	fi

download-db:
	@echo "📥 Downloading database from container..."
	@if docker ps -q -f name=$(CONTAINER_NAME) > /dev/null 2>&1; then \
		docker cp $(CONTAINER_NAME):/app/data/forum.db ./forum.db; \
		echo "✅ Database downloaded to: $(PWD)/forum.db"; \
		echo "📊 Size: $$(du -h forum.db | cut -f1)"; \
	else \
		echo "❌ Container not running. Start with 'make run'"; \
	fi

upload-db:
	@echo "📤 Uploading database to container..."
	@if [ ! -f "./forum.db" ]; then \
		echo "❌ No local forum.db found"; \
		exit 1; \
	fi
	@if docker ps -q -f name=$(CONTAINER_NAME) > /dev/null 2>&1; then \
		docker cp ./forum.db $(CONTAINER_NAME):/app/data/forum.db; \
		docker exec $(CONTAINER_NAME) chown appuser:appuser /app/data/forum.db; \
		echo "✅ Database uploaded successfully"; \
		echo "🔄 Restarting container..."; \
		make restart; \
	else \
		echo "❌ Container not running. Start with 'make run'"; \
	fi

all: build run