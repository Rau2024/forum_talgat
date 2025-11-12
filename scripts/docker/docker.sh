#!/bin/bash

# Forum Application Docker Management Script
# This script matches the behavior of the Makefile for consistency

IMAGE_NAME="forum-app:latest"
CONTAINER_NAME="forum"
PORT=8080

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

case "$1" in
    build)
        echo -e "${BLUE}🔨 Building Docker image...${NC}"
        docker build -t $IMAGE_NAME .
        echo -e "${GREEN}✅ Build complete${NC}"
        ;;
    
    run)
        echo -e "${BLUE}🚀 Starting container with local database...${NC}"
        
        # Check for existing container and remove it (matches Makefile behavior)
        if docker ps -a -f name=$CONTAINER_NAME | grep -q $CONTAINER_NAME; then
            echo -e "${YELLOW}⚠️  Existing container found, removing...${NC}"
            docker stop $CONTAINER_NAME 2>/dev/null || true
            docker rm $CONTAINER_NAME 2>/dev/null || true
        fi
        
        # Create database file if it doesn't exist (matches Makefile behavior)
        if [ ! -f "./forum.db" ]; then
            echo -e "${BLUE}🆕 Creating empty forum.db file...${NC}"
            touch ./forum.db
            chmod 666 ./forum.db
            echo -e "${BLUE}💡 Database will be initialized on first request${NC}"
        else
            echo -e "${BLUE}📊 Using existing forum.db${NC}"
        fi
        
        # Run container with host filesystem mount (matches Makefile behavior)
        docker run -d \
            --name $CONTAINER_NAME \
            -p $PORT:$PORT \
            -v $(pwd):/app/data \
            -e PORT=$PORT \
            -e DATABASE_URL=/app/data/forum.db \
            -e JWT_SECRET=dev-secret \
            -e TZ=Asia/Almaty \
            $IMAGE_NAME
        
        echo -e "${GREEN}✅ Container started: http://localhost:$PORT${NC}"
        echo -e "${GREEN}💾 Database location: $(pwd)/forum.db${NC}"
        
        # Show initial logs (matches Makefile behavior)
        sleep 2
        echo ""
        echo -e "${BLUE}📋 Initial logs:${NC}"
        docker logs $CONTAINER_NAME 2>&1 | head -n 20
        ;;
    
    stop)
        echo -e "${BLUE}🛑 Stopping container...${NC}"
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
        echo -e "${GREEN}✅ Container stopped${NC}"
        ;;
    
    logs)
        echo -e "${BLUE}📋 Viewing logs (Ctrl+C to exit)...${NC}"
        docker logs -f $CONTAINER_NAME || echo -e "${RED}❌ Container not running${NC}"
        ;;
    
    shell)
        echo -e "${BLUE}🐚 Opening shell in container...${NC}"
        docker exec -it $CONTAINER_NAME sh || echo -e "${RED}❌ Container not running${NC}"
        ;;
    
    restart)
        echo -e "${BLUE}🔄 Restarting container...${NC}"
        $0 stop
        $0 run
        ;;
    
    clean)
        echo -e "${BLUE}🧹 Cleaning up Docker resources...${NC}"
        $0 stop
        docker rmi $IMAGE_NAME 2>/dev/null || true
        echo -e "${GREEN}✅ Cleanup complete${NC}"
        if [ -f "./forum.db" ]; then
            echo -e "${GREEN}💾 Local forum.db preserved at: $(pwd)/forum.db${NC}"
        fi
        ;;
    
    clean-all)
        echo -e "${BLUE}🧹 Cleaning up everything...${NC}"
        $0 stop
        docker rmi $IMAGE_NAME 2>/dev/null || true
        echo -e "${YELLOW}⚠️  Removing database files...${NC}"
        rm -f forum.db forum.db-shm forum.db-wal
        echo -e "${GREEN}✅ Complete cleanup done${NC}"
        ;;
    
    status)
        echo -e "${BLUE}📊 Container Status:${NC}"
        echo "===================="
        docker ps -a -f name=$CONTAINER_NAME || echo -e "${RED}❌ Container not found${NC}"
        echo ""
        echo -e "${BLUE}💾 Database Status:${NC}"
        echo "===================="
        if [ -f "./forum.db" ]; then
            DB_SIZE=$(du -h forum.db 2>/dev/null | cut -f1)
            echo -e "${GREEN}✅ Local database: forum.db ($DB_SIZE)${NC}"
            echo -e "${GREEN}📍 Location: $(pwd)/forum.db${NC}"
        else
            echo -e "${RED}❌ No local database found${NC}"
        fi
        ;;
    
    db)
        echo -e "${BLUE}💾 Opening database shell...${NC}"
        echo -e "${BLUE}💡 Tip: Use .tables, .schema, .quit commands${NC}"
        echo ""
        if [ -f "./forum.db" ]; then
            sqlite3 ./forum.db
        else
            echo -e "${RED}❌ No forum.db found. Run './docker.sh run' first${NC}"
        fi
        ;;
    
    backup)
        echo -e "${BLUE}💾 Backing up database...${NC}"
        mkdir -p ./backups
        if [ -f "./forum.db" ]; then
            BACKUP_FILE="./backups/forum_backup_$(date +%Y%m%d_%H%M%S).db"
            cp ./forum.db "$BACKUP_FILE"
            BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
            echo -e "${GREEN}✅ Backup saved: $BACKUP_FILE${NC}"
            echo -e "${GREEN}📊 Backup size: $BACKUP_SIZE${NC}"
        else
            echo -e "${RED}❌ No forum.db found to backup${NC}"
        fi
        ;;
    
    check-db)
        echo -e "${BLUE}🔍 Database Statistics${NC}"
        echo "======================"
        if [ -f "./forum.db" ]; then
            DB_SIZE=$(du -h forum.db | cut -f1)
            echo -e "${GREEN}📊 File size: $DB_SIZE${NC}"
            echo -e "${GREEN}📍 Location: $(pwd)/forum.db${NC}"
            echo ""
            echo -e "${BLUE}📈 Content:${NC}"
            sqlite3 forum.db "SELECT '  Users: ' || COUNT(*) FROM users; \
                              SELECT '  Posts: ' || COUNT(*) FROM posts; \
                              SELECT '  Comments: ' || COUNT(*) FROM comments; \
                              SELECT '  Categories: ' || COUNT(*) FROM categories; \
                              SELECT '  Sessions: ' || COUNT(*) FROM sessions;"
        else
            echo -e "${RED}❌ No forum.db found${NC}"
        fi
        ;;
    
    download-db)
        echo -e "${BLUE}📥 Downloading database from container...${NC}"
        if docker ps -q -f name=$CONTAINER_NAME > /dev/null 2>&1; then
            docker cp $CONTAINER_NAME:/app/data/forum.db ./forum.db
            DB_SIZE=$(du -h forum.db | cut -f1)
            echo -e "${GREEN}✅ Database downloaded to: $(pwd)/forum.db${NC}"
            echo -e "${GREEN}📊 Size: $DB_SIZE${NC}"
        else
            echo -e "${RED}❌ Container not running. Start with './docker.sh run'${NC}"
        fi
        ;;
    
    upload-db)
        echo -e "${BLUE}📤 Uploading database to container...${NC}"
        if [ ! -f "./forum.db" ]; then
            echo -e "${RED}❌ No local forum.db found${NC}"
            exit 1
        fi
        if docker ps -q -f name=$CONTAINER_NAME > /dev/null 2>&1; then
            docker cp ./forum.db $CONTAINER_NAME:/app/data/forum.db
            docker exec $CONTAINER_NAME chown appuser:appuser /app/data/forum.db
            echo -e "${GREEN}✅ Database uploaded successfully${NC}"
            echo -e "${BLUE}🔄 Restarting container...${NC}"
            $0 restart
        else
            echo -e "${RED}❌ Container not running. Start with './docker.sh run'${NC}"
        fi
        ;;
    
    help|--help|-h)
        echo -e "${BLUE}Forum Application - Docker Commands${NC}"
        echo ""
        echo "Available commands:"
        echo "  ./docker.sh build       - Build Docker image"
        echo "  ./docker.sh run         - Start container (uses local forum.db)"
        echo "  ./docker.sh stop        - Stop container"
        echo "  ./docker.sh logs        - View logs"
        echo "  ./docker.sh shell       - Open shell in container"
        echo "  ./docker.sh restart     - Restart container"
        echo "  ./docker.sh clean       - Remove container and image (keeps database)"
        echo "  ./docker.sh clean-all   - Remove everything including database"
        echo "  ./docker.sh status      - Show container and database status"
        echo ""
        echo "Database commands:"
        echo "  ./docker.sh db          - Access database (SQLite shell)"
        echo "  ./docker.sh backup      - Backup database"
        echo "  ./docker.sh check-db    - Check database stats"
        echo "  ./docker.sh download-db - Download DB from container"
        echo "  ./docker.sh upload-db   - Upload local DB to container"
        echo ""
        echo -e "${YELLOW}Note: This script now matches Makefile behavior${NC}"
        echo -e "${YELLOW}Database is stored on host filesystem at ./forum.db${NC}"
        ;;
    
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        echo "Usage: $0 {build|run|stop|logs|shell|restart|clean|clean-all|status|db|backup|check-db|download-db|upload-db|help}"
        echo ""
        echo "Run '$0 help' for more information"
        exit 1
        ;;
esac