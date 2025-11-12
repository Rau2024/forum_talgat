#!/bin/bash

# Script to clean up test users from the database
# Removes all test users created by the 12 test suites

# Get to project root (2 directories up from scripts/setup/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DB_FILE="$PROJECT_ROOT/forum.db"

# Change to project root for all operations
cd "$PROJECT_ROOT"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Cleaning up test users from database"
echo "====================================="
echo ""
echo "Database: $DB_FILE"
echo ""

if [ ! -f "$DB_FILE" ]; then
    echo -e "${RED}✗ Error: Database file not found${NC}"
    echo "   Expected location: $DB_FILE"
    echo "   Current directory: $(pwd)"
    echo ""
    echo "Make sure forum.db exists in project root"
    exit 1
fi

# Build WHERE clause for all test username patterns
# Patterns from all 12 test suites:
# - testuser* (test_forum.sh, test_forum_endpoints.sh, test_backend_validation.sh, test_comment_routes.sh)
# - validuser* (test_validation.sh)
# - pwtest* (test_password_validation.sh)
# - sessiontest* (test_sessions.sh)
# - methodtest* (test_http_methods.sh)
# - reqtest* (test_post_required_fields.sh)
# - cattest* (test_category.sh)
# - valid_user* (additional pattern from test_validation.sh)

WHERE_CLAUSE="username LIKE 'testuser%' 
    OR username LIKE 'validuser%' 
    OR username LIKE 'pwtest%' 
    OR username LIKE 'sessiontest%' 
    OR username LIKE 'methodtest%' 
    OR username LIKE 'reqtest%' 
    OR username LIKE 'cattest%'
    OR username LIKE 'valid_user%'"

# Count test users before cleanup
BEFORE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE $WHERE_CLAUSE;")
echo -e "${BLUE}Test users found: $BEFORE_COUNT${NC}"

if [ "$BEFORE_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ No test users to clean up${NC}"
    exit 0
fi

echo ""
echo "Test users to be deleted:"
echo "------------------------"
sqlite3 "$DB_FILE" -header -column "SELECT id, username, email, datetime(created_at) as created FROM users WHERE $WHERE_CLAUSE ORDER BY created_at DESC;" | head -30

if [ "$BEFORE_COUNT" -gt 25 ]; then
    echo "... and $(($BEFORE_COUNT - 25)) more"
fi

echo ""
echo -e "${YELLOW}⚠ WARNING: This will permanently delete these users and their sessions!${NC}"
echo ""
read -p "Delete these test users? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Deleting test users...${NC}"
    
    # Delete sessions first (foreign key constraint)
    sqlite3 "$DB_FILE" "DELETE FROM sessions WHERE user_id IN (SELECT id FROM users WHERE $WHERE_CLAUSE);"
    
    # Delete users
    sqlite3 "$DB_FILE" "DELETE FROM users WHERE $WHERE_CLAUSE;"
    
    AFTER_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE $WHERE_CLAUSE;")
    DELETED_COUNT=$(($BEFORE_COUNT - $AFTER_COUNT))
    
    echo -e "${GREEN}✅ Deleted $DELETED_COUNT test users${NC}"
    echo -e "${GREEN}✅ Database cleanup complete${NC}"
else
    echo -e "${YELLOW}❌ Cleanup cancelled${NC}"
fi

echo ""
echo -e "${BLUE}Current user count: $(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users;")${NC}"
echo ""
echo "Test username patterns cleaned:"
echo "  • testuser*    (test_forum, test_endpoints, test_backend, test_comment)"
echo "  • validuser*   (test_validation)"
echo "  • pwtest*      (test_password_validation)"
echo "  • sessiontest* (test_sessions)"
echo "  • methodtest*  (test_http_methods)"
echo "  • reqtest*     (test_post_required_fields)"
echo "  • cattest*     (test_category)"
echo "  • valid_user*  (test_validation alternate pattern)"