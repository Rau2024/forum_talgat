#!/bin/bash

echo "🧪 Template Error Handling Tests"
echo "================================"
echo ""

BASE_URL="http://localhost:8080"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_page() {
    local url=$1
    local test_name=$2
    local expected=$3
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$RESPONSE" -eq "$expected" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name (HTTP $RESPONSE)"
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name (Expected $expected, got $RESPONSE)"
    fi
}

echo "Test 1: Normal Operation"
test_page "$BASE_URL/" "Homepage" 200
test_page "$BASE_URL/register" "Register page" 200
test_page "$BASE_URL/login" "Login page" 200
echo ""

echo "Test 2: Missing Template - Backup register.html"
if [ -f "web/templates/register.html" ]; then
    mv web/templates/register.html web/templates/register.html.backup
    test_page "$BASE_URL/register" "Register with missing template" 500
    mv web/templates/register.html.backup web/templates/register.html
    echo -e "${YELLOW}✓${NC} Template restored"
else
    echo -e "${RED}✗${NC} register.html not found"
fi
echo ""

echo "Test 3: Invalid URL (404 handling)"
test_page "$BASE_URL/nonexistent" "404 error page" 404
echo ""

echo "Test 4: Verify Pages After Restoration"
test_page "$BASE_URL/" "Homepage after tests" 200
test_page "$BASE_URL/register" "Register after tests" 200
test_page "$BASE_URL/login" "Login after tests" 200
echo ""

echo "================================"
echo "Testing complete!"