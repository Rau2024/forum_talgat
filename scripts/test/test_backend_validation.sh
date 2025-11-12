#!/bin/bash

BASE_URL="http://localhost:8080"
COOKIE_FILE="test_cookies.txt"
TIMESTAMP=$(date +%s)
TEST_USER="testuser_${TIMESTAMP}"
TEST_EMAIL="test${TIMESTAMP}@test.com"
PASSWORD="TestPass123!"  # Valid password

echo "=================================="
echo "Backend Validation Testing (Fixed)"
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass_test() { echo -e "${GREEN}✓ PASS${NC}: $1"; }
fail_test() { echo -e "${RED}✗ FAIL${NC}: $1"; }
info_test() { echo -e "${YELLOW}ℹ INFO${NC}: $1"; }

# Register and login
echo "Setting up test user..."
REGISTER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/register" \
    -d "username=${TEST_USER}&email=${TEST_EMAIL}&password=${PASSWORD}&confirm_password=${PASSWORD}")

REGISTER_CODE=$(echo "$REGISTER_RESPONSE" | tail -1)
if [ "$REGISTER_CODE" = "303" ] || [ "$REGISTER_CODE" = "200" ]; then
    info_test "User registered successfully"
else
    info_test "User might already exist or registration flow different (code: $REGISTER_CODE)"
fi

curl -s -L -c $COOKIE_FILE -o /dev/null -X POST "$BASE_URL/login" \
    -d "username=${TEST_USER}&password=${PASSWORD}"

echo ""

# Test 1: Short post title
echo "Test 1: Short post title (< 3 chars)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=ab&content=This is valid content with more than ten characters&category_id[]=1")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Validation failure = 200 (form re-render) with error message
if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "at least 3 characters"; then
    pass_test "Backend rejected short title"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted short title (redirected successfully)"
else
    fail_test "Backend accepted short title or unexpected response (HTTP $STATUS)"
fi
echo ""

# Test 2: Long post title
echo "Test 2: Long post title (> 255 chars)"
LONG_TITLE=$(python3 -c "print('a' * 256)")
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=$LONG_TITLE&content=This is valid content&category_id[]=1")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "no more than 255 characters"; then
    pass_test "Backend rejected long title"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted long title (redirected successfully)"
else
    fail_test "Backend accepted long title or unexpected response (HTTP $STATUS)"
fi
echo ""

# Test 3: Short post content
echo "Test 3: Short post content (< 10 chars)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=short&category_id[]=1")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "at least 10 characters"; then
    pass_test "Backend rejected short content"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted short content (redirected successfully)"
else
    fail_test "Backend accepted short content or unexpected response (HTTP $STATUS)"
fi
echo ""

# Test 4: Long post content
echo "Test 4: Long post content (> 10,000 chars)"
LONG_CONTENT=$(python3 -c "print('a' * 10001)")
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=$LONG_CONTENT&category_id[]=1")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "no more than 10,000 characters\|10000 characters"; then
    pass_test "Backend rejected long content"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted long content (redirected successfully)"
else
    fail_test "Backend accepted long content or unexpected response (HTTP $STATUS)"
fi
echo ""

# Test 5: Create valid post for comment tests
echo "Test 5: Creating valid post for comment tests..."
RESPONSE=$(curl -s -L -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Test Post For Comments&content=This is a valid test post with enough content&category_id[]=1")

STATUS=$(echo "$RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "303" ]; then
    # Extract post ID from redirect location if possible
    # For now, we'll assume post ID 1 exists or try to get the latest post
    POST_ID=1
    info_test "Valid post created (HTTP $STATUS)"
elif [ "$STATUS" = "200" ]; then
    # Check if it's an error page or success page
    if echo "$RESPONSE_BODY" | grep -qi "error"; then
        fail_test "Failed to create valid post - got error"
        echo "Trying to use existing post ID 1 for comment tests..."
        POST_ID=1
    else
        info_test "Valid post created (HTTP $STATUS)"
        POST_ID=1
    fi
else
    fail_test "Unexpected response creating post (HTTP $STATUS)"
    echo "Trying to use existing post ID 1 for comment tests..."
    POST_ID=1
fi
echo ""

# Test 6: Short comment
echo "Test 6: Short comment (< 10 chars)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/comment/$POST_ID" \
    -d "content=short")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Comment validation failure = 200 (page re-render) with error
if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "at least 10 characters"; then
    pass_test "Backend rejected short comment"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted short comment (redirected successfully)"
elif [ "$STATUS" = "404" ]; then
    fail_test "Post $POST_ID not found - cannot test comments (create a post first)"
else
    fail_test "Backend accepted short comment or unexpected response (HTTP $STATUS)"
fi
echo ""

# Test 7: Long comment
echo "Test 7: Long comment (> 5,000 chars)"
LONG_COMMENT=$(python3 -c "print('a' * 5001)")
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/comment/$POST_ID" \
    -d "content=$LONG_COMMENT")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "no more than 5,000 characters\|5000 characters"; then
    pass_test "Backend rejected long comment"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted long comment (redirected successfully)"
elif [ "$STATUS" = "404" ]; then
    fail_test "Post $POST_ID not found - cannot test comments"
else
    fail_test "Backend accepted long comment or unexpected response (HTTP $STATUS)"
fi
echo ""

# Test 8: Valid post (should succeed with redirect)
echo "Test 8: Valid post (should succeed)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Test Post&content=This is completely valid content&category_id[]=1")

STATUS=$(echo "$RESPONSE" | tail -1)

# Valid post creation returns 303 (redirect)
if [ "$STATUS" = "303" ]; then
    pass_test "Backend accepted valid post"
elif [ "$STATUS" = "200" ]; then
    BODY=$(echo "$RESPONSE" | sed '$d')
    if echo "$BODY" | grep -qi "error"; then
        fail_test "Backend rejected valid post with error"
    else
        pass_test "Backend accepted valid post (returned page instead of redirect)"
    fi
else
    fail_test "Backend rejected valid post (HTTP $STATUS)"
fi
echo ""

# Test 9: Valid comment (should succeed with redirect)
echo "Test 9: Valid comment (should succeed)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/comment/$POST_ID" \
    -d "content=This is a valid comment with enough characters to pass validation")

STATUS=$(echo "$RESPONSE" | tail -1)

# Valid comment creation returns 303 (redirect)
if [ "$STATUS" = "303" ]; then
    pass_test "Backend accepted valid comment"
elif [ "$STATUS" = "200" ]; then
    BODY=$(echo "$RESPONSE" | sed '$d')
    if echo "$BODY" | grep -qi "error"; then
        fail_test "Backend rejected valid comment with error"
    else
        pass_test "Backend accepted valid comment (returned page instead of redirect)"
    fi
elif [ "$STATUS" = "404" ]; then
    fail_test "Post $POST_ID not found - cannot test comments"
else
    fail_test "Backend rejected valid comment (HTTP $STATUS)"
fi
echo ""

# Test 10: No categories selected
echo "Test 10: Post with no categories"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=This is valid content")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "at least one category"; then
    pass_test "Backend rejected post without categories"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted post without categories"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 11: Too many categories (> 5)
echo "Test 11: Post with too many categories (> 5)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=This is valid content&category_id[]=1&category_id[]=2&category_id[]=3&category_id[]=4&category_id[]=5&category_id[]=6")

STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ] && echo "$BODY" | grep -qi "up to 5 categories"; then
    pass_test "Backend rejected post with too many categories"
elif [ "$STATUS" = "303" ]; then
    fail_test "Backend accepted post with too many categories"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Cleanup
rm -f $COOKIE_FILE

echo "=================================="
echo "Backend Validation Testing Complete!"
echo "=================================="
echo ""
echo "Summary:"
echo "- Tests 1-4: Post validation (title & content length)"
echo "- Tests 6-7: Comment validation (content length)"
echo "- Tests 8-9: Valid submissions (should succeed)"
echo "- Tests 10-11: Category validation"
echo ""
echo "Note: Comment tests use POST /comment/{postID}"
echo "      (where postID is the ID of the post to comment on)"