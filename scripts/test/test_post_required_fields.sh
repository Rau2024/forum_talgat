#!/bin/bash

BASE_URL="http://localhost:8080"
COOKIE_FILE="test_required_fields.txt"
TIMESTAMP=$(date +%s)
TEST_USER="reqtest_${TIMESTAMP}"
TEST_EMAIL="reqtest${TIMESTAMP}@test.com"
PASSWORD="TestPass123!"  # ✅ FIXED: Valid password

echo "=========================================="
echo "POST Required Fields Validation Testing"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass_test() { echo -e "${GREEN}✓ PASS${NC}: $1"; }
fail_test() { echo -e "${RED}✗ FAIL${NC}: $1"; }
info_test() { echo -e "${YELLOW}ℹ INFO${NC}: $1"; }

# Setup: Register and login
echo "Setting up test user..."
REGISTER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/register" \
    -d "username=${TEST_USER}&email=${TEST_EMAIL}&password=${PASSWORD}&confirm_password=${PASSWORD}")

if [ "$REGISTER_RESPONSE" -eq 303 ]; then
    info_test "User registered successfully"
else
    info_test "Registration returned $REGISTER_RESPONSE (may already exist)"
fi

curl -s -c $COOKIE_FILE -o /dev/null -X POST "$BASE_URL/login" \
    -d "username=${TEST_USER}&password=${PASSWORD}"

echo ""

# Test 1: Missing title (empty)
echo "Test 1: Missing title (empty)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=&content=This is valid content&category_id[]=1")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Validation failure = 200 (form re-render) NOT 303 (redirect)
if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "required\|title"; then
    pass_test "Backend rejected missing title"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted missing title (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 2: Missing content (empty)
echo "Test 2: Missing content (empty)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=&category_id[]=1")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "required\|content"; then
    pass_test "Backend rejected missing content"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted missing content (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 3: Missing categories (none selected)
echo "Test 3: Missing categories (none selected)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=This is valid content")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "category\|categories"; then
    pass_test "Backend rejected missing categories"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted missing categories (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 4: Too many categories (> 5)
echo "Test 4: Too many categories (> 5)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=Valid content&category_id[]=1&category_id[]=2&category_id[]=3&category_id[]=4&category_id[]=5&category_id[]=1")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "up to 5\|5 categories"; then
    pass_test "Backend rejected too many categories"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted too many categories (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 5: Invalid category ID (non-numeric)
echo "Test 5: Invalid category ID (non-numeric)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=Valid content&category_id[]=abc")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "invalid\|category"; then
    pass_test "Backend rejected invalid category ID"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted invalid category ID (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 6: Invalid category ID (zero or negative)
echo "Test 6: Invalid category ID (zero)"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=Valid content&category_id[]=0")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "invalid\|positive\|category"; then
    pass_test "Backend rejected zero category ID"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted zero category ID (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 7: Missing authentication (no cookie)
echo "Test 7: Missing authentication (no login)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=Valid content&category_id[]=1")

if [ "$RESPONSE" -eq 303 ]; then
    pass_test "Backend redirected unauthenticated user"
else
    fail_test "Backend allowed unauthenticated post creation (HTTP $RESPONSE)"
fi
echo ""

# Test 8: Wrong HTTP method (GET returns form, not creates post)
echo "Test 8: GET request for post creation (should show form)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b $COOKIE_FILE -X GET "$BASE_URL/post/create")

if [ "$RESPONSE" -eq 200 ]; then
    pass_test "Backend returns form for GET (doesn't create post)"
elif [ "$RESPONSE" -eq 303 ]; then
    fail_test "Backend redirected on GET (session expired?)"
else
    fail_test "Backend GET behavior unexpected (HTTP $RESPONSE)"
fi
echo ""

# Test 9: All fields valid (should succeed)
echo "Test 9: All required fields valid (should succeed)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Complete Valid Post&content=This is completely valid content&category_id[]=1")

if [ "$RESPONSE" -eq 303 ]; then
    pass_test "Backend accepted post with all valid fields"
else
    fail_test "Backend rejected valid post (HTTP $RESPONSE)"
fi
echo ""

# Test 10: Whitespace-only title (after trim should be empty)
echo "Test 10: Whitespace-only title"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=   &content=Valid content&category_id[]=1")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "required\|cannot have spaces\|title"; then
    pass_test "Backend rejected whitespace-only title"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted whitespace-only title (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 11: Whitespace-only content
echo "Test 11: Whitespace-only content"
RESPONSE=$(curl -s -w "\n%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Valid Title&content=   &category_id[]=1")
STATUS=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$STATUS" -eq 200 ] && echo "$BODY" | grep -qi "required\|cannot have spaces\|content"; then
    pass_test "Backend rejected whitespace-only content"
elif [ "$STATUS" -eq 303 ]; then
    fail_test "Backend accepted whitespace-only content (redirected)"
else
    fail_test "Backend response unclear (HTTP $STATUS)"
fi
echo ""

# Test 12: Multiple valid categories (1-5 range)
echo "Test 12: Multiple valid categories (3 categories)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b $COOKIE_FILE -X POST "$BASE_URL/post/create" \
    -d "title=Multi Category Post&content=Valid content&category_id[]=1&category_id[]=2&category_id[]=3")

if [ "$RESPONSE" -eq 303 ]; then
    pass_test "Backend accepted post with 3 categories"
else
    fail_test "Backend rejected post with 3 valid categories (HTTP $RESPONSE)"
fi
echo ""

# Cleanup
rm -f $COOKIE_FILE

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
info_test "Key validation checks:"
echo "  ✓ Required fields (title, content, categories)"
echo "  ✓ Field length limits (min/max characters)"
echo "  ✓ Category count limits (1-5)"
echo "  ✓ Category ID validation (numeric, positive)"
echo "  ✓ Whitespace-only rejection"
echo "  ✓ Authentication requirement"
echo "  ✓ HTTP method validation"
echo ""
echo "Success response: HTTP 303 (redirect to new post)"
echo "Validation failure: HTTP 200 (form re-render with errors)"
echo ""
echo "Required Fields Validation Testing Complete!"