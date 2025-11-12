#!/bin/bash

# Test script for forum application endpoints: like, dislike, comment
# Tests behavior for non-existent post (expect 404) and non-existent user (expect 303)

# Configuration
BASE_URL="http://localhost:8080"

# Generate unique username for this test run
TIMESTAMP=$(date +%s)
RANDOM_ID="$$"
TEST_USERNAME="testuser_${TIMESTAMP}_${RANDOM_ID}"
TEST_PASSWORD="TestPass123!"
NON_EXISTENT_POST_ID=999            # Post ID that doesn't exist in DB
VALID_POST_ID=1                     # Valid post ID (replace with a real one from your DB)
TEST_COMMENT_CONTENT="This is a test comment for the forum application with enough characters"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_TOTAL=0

# Function to check if response matches expected status code
check_status() {
    local test_name="$1"
    local response_code="$2"
    local expected_code="$3"
    local response_body="$4"
    ((TESTS_TOTAL++))
    
    if [ -z "$response_code" ]; then
        echo -e "${RED}FAIL: $test_name (No response code received)${NC}"
        echo "Response body: $response_body"
        return
    fi
    
    if [ "$response_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}PASS: $test_name (Status: $response_code)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAIL: $test_name (Expected: $expected_code, Got: $response_code)${NC}"
        if [ ! -z "$response_body" ]; then
            # Show error message if it's an error page
            ERROR_MSG=$(echo "$response_body" | grep -o '<h1 class="error-title">[^<]*</h1>' | sed 's/<[^>]*>//g')
            if [ ! -z "$ERROR_MSG" ]; then
                echo "  Error: $ERROR_MSG"
            fi
        fi
    fi
}

echo "========================================="
echo "Forum Endpoints Test (Fixed)"
echo "========================================="
echo ""

# Step 0: Register test user
echo "Registering test user..."
REGISTER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/register" \
    -d "username=$TEST_USERNAME&email=${TEST_USERNAME}@test.com&password=$TEST_PASSWORD&confirm_password=$TEST_PASSWORD" \
    -H "Content-Type: application/x-www-form-urlencoded")
echo "Registration response: $REGISTER_RESPONSE (303 = success)"

# Step 1: Check server availability
echo "Checking server availability..."
SERVER_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL")
if [ "$SERVER_CHECK" -eq 0 ]; then
    echo -e "${RED}ERROR: Server not reachable at $BASE_URL${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Server is reachable (Status: $SERVER_CHECK)"
echo ""

# Step 2: Login to get session_token
echo "Logging in to obtain session_token..."

LOGIN_RESPONSE=$(curl -s -i -L -X POST "$BASE_URL/login" \
    -d "username=$TEST_USERNAME&password=$TEST_PASSWORD" \
    -H "Content-Type: application/x-www-form-urlencoded")

LOGIN_STATUS=$(echo "$LOGIN_RESPONSE" | grep -i "^HTTP" | tail -1 | awk '{print $2}')

SESSION_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -i "Set-Cookie:.*session_token" | sed -n 's/.*session_token=\([^;[:space:]]*\).*/\1/p' | head -n 1)

if [ -z "$SESSION_TOKEN" ]; then
    # Alternative extraction method
    SESSION_TOKEN=$(echo "$LOGIN_RESPONSE" | tr -d '\r' | grep "Set-Cookie" | grep "session_token" | cut -d'=' -f2 | cut -d';' -f1)
    
    if [ -z "$SESSION_TOKEN" ]; then
        echo -e "${RED}ERROR: Failed to obtain session_token${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓${NC} Logged in (Session: ${SESSION_TOKEN:0:20}...)"
echo ""

# Step 3: Test Like Endpoint
echo "========================================="
echo "Testing Like Endpoint"
echo "========================================="
echo ""

# Test 1: Like non-existent post
LIKE_RESPONSE=$(curl -s -i -X POST "$BASE_URL/post/$NON_EXISTENT_POST_ID/like" \
    -H "Cookie: session_token=$SESSION_TOKEN")
LIKE_STATUS=$(echo "$LIKE_RESPONSE" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
LIKE_BODY=$(echo "$LIKE_RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
check_status "Like non-existent post (postID=$NON_EXISTENT_POST_ID)" "$LIKE_STATUS" 404 "$LIKE_BODY"

# Test 2: Like with invalid auth
LIKE_NO_AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/post/$VALID_POST_ID/like")
check_status "Like with invalid auth (postID=$VALID_POST_ID)" "$LIKE_NO_AUTH_RESPONSE" 303 ""

# Test 3: Like valid post
LIKE_VALID_RESPONSE=$(curl -s -i -X POST "$BASE_URL/post/$VALID_POST_ID/like" \
    -H "Cookie: session_token=$SESSION_TOKEN")
LIKE_VALID_STATUS=$(echo "$LIKE_VALID_RESPONSE" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
LIKE_VALID_BODY=$(echo "$LIKE_VALID_RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
check_status "Like valid post (postID=$VALID_POST_ID)" "$LIKE_VALID_STATUS" 303 "$LIKE_VALID_BODY"

echo ""

# Step 4: Test Dislike Endpoint
echo "========================================="
echo "Testing Dislike Endpoint"
echo "========================================="
echo ""

# Test 4: Dislike non-existent post
DISLIKE_RESPONSE=$(curl -s -i -X POST "$BASE_URL/post/$NON_EXISTENT_POST_ID/dislike" \
    -H "Cookie: session_token=$SESSION_TOKEN")
DISLIKE_STATUS=$(echo "$DISLIKE_RESPONSE" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
DISLIKE_BODY=$(echo "$DISLIKE_RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
check_status "Dislike non-existent post (postID=$NON_EXISTENT_POST_ID)" "$DISLIKE_STATUS" 404 "$DISLIKE_BODY"

# Test 5: Dislike with invalid auth
DISLIKE_NO_AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/post/$VALID_POST_ID/dislike")
check_status "Dislike with invalid auth (postID=$VALID_POST_ID)" "$DISLIKE_NO_AUTH_RESPONSE" 303 ""

echo ""

# Step 5: Test Comment Endpoint (FIXED: using /comment/ not /reply/)
echo "========================================="
echo "Testing Comment Creation Endpoint"
echo "========================================="
echo ""

# Test 6: Comment on non-existent post
COMMENT_RESPONSE=$(curl -s -i -X POST "$BASE_URL/comment/$NON_EXISTENT_POST_ID" \
    -H "Cookie: session_token=$SESSION_TOKEN" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "content=$TEST_COMMENT_CONTENT")
COMMENT_STATUS=$(echo "$COMMENT_RESPONSE" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
COMMENT_BODY=$(echo "$COMMENT_RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
check_status "Comment on non-existent post (postID=$NON_EXISTENT_POST_ID)" "$COMMENT_STATUS" 404 "$COMMENT_BODY"

# Test 7: Comment with invalid auth
COMMENT_NO_AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/comment/$VALID_POST_ID" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "content=$TEST_COMMENT_CONTENT")
check_status "Comment with invalid auth (postID=$VALID_POST_ID)" "$COMMENT_NO_AUTH_RESPONSE" 303 ""

# Test 8: Comment on valid post
COMMENT_VALID_RESPONSE=$(curl -s -i -X POST "$BASE_URL/comment/$VALID_POST_ID" \
    -H "Cookie: session_token=$SESSION_TOKEN" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "content=$TEST_COMMENT_CONTENT")
COMMENT_VALID_STATUS=$(echo "$COMMENT_VALID_RESPONSE" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
COMMENT_VALID_BODY=$(echo "$COMMENT_VALID_RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
check_status "Comment on valid post (postID=$VALID_POST_ID)" "$COMMENT_VALID_STATUS" 303 "$COMMENT_VALID_BODY"

echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}/$TESTS_TOTAL"
echo ""

if [ "$TESTS_PASSED" -eq "$TESTS_TOTAL" ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}       ✓✓✓ ALL TESTS PASSED! ✓✓✓       ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "All endpoints working correctly:"
    echo "  ✓ Like endpoint (/post/{id}/like)"
    echo "  ✓ Dislike endpoint (/post/{id}/dislike)"
    echo "  ✓ Comment endpoint (/comment/{postID})"
    echo ""
    echo "All validations passed:"
    echo "  ✓ 404 errors for non-existent resources"
    echo "  ✓ 303 redirects for unauthenticated requests"
    echo "  ✓ 303 redirects for successful actions"
    exit 0
else
    echo -e "${YELLOW}Some tests failed${NC}"
    echo ""
    echo "Note:"
    echo "  • 404 errors are expected for non-existent posts"
    echo "  • 303 redirects are expected for auth/success"
    echo ""
    echo "Common issues:"
    echo "  • Make sure post ID 1 exists in your database"
    echo "  • Check that the server is running on port 8080"
    echo "  • Verify comment content has enough characters (10+)"
    exit 1
fi