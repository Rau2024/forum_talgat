#!/bin/bash

BASE_URL="http://localhost:8080"
COOKIE_FILE="validation_test_cookies.txt"
TIMESTAMP=$(date +%s)
VALID_USER="validuser_${TIMESTAMP}"
VALID_EMAIL="valid${TIMESTAMP}@test.com"
VALID_PASSWORD="Password123!"  # ✅ FIXED: Strong password

echo "=================================="
echo "Input Validation Testing Suite"
echo "=================================="
echo ""

# Cleanup
rm -f $COOKIE_FILE /tmp/response.html

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1"
}

info_test() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# ============================================
# Test 1: Username Validation
# ============================================
echo "Test 1: Username Validation"

# Test short username (< 3 chars)
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=ab&email=test@test.com&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "at least 3 characters" /tmp/response.html; then
    pass_test "Short username rejected (< 3 chars)"
else
    fail_test "Short username validation failed"
fi

# Test long username (> 50 chars)
LONG_USERNAME="a123456789012345678901234567890123456789012345678901"
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=${LONG_USERNAME}&email=test@test.com&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "no more than 50 characters" /tmp/response.html; then
    pass_test "Long username rejected (> 50 chars)"
else
    fail_test "Long username validation failed"
fi

# Test invalid characters in username
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=user@name&email=test@test.com&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "can only contain" /tmp/response.html; then
    pass_test "Invalid username characters rejected"
else
    fail_test "Invalid username characters validation failed"
fi

echo ""

# ============================================
# Test 2: Email Validation
# ============================================
echo "Test 2: Email Validation"

# Test invalid email format
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=notanemail&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "Invalid email" /tmp/response.html; then
    pass_test "Invalid email format rejected"
else
    fail_test "Email format validation failed"
fi

# Test email without @ symbol
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=testemail.com&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "Invalid email" /tmp/response.html; then
    pass_test "Email without @ rejected"
else
    fail_test "Email @ validation failed"
fi

# Test email without domain
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=test@&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "Invalid email" /tmp/response.html; then
    pass_test "Email without domain rejected"
else
    fail_test "Email domain validation failed"
fi

# Test email without TLD
echo "Test 2b: Email without TLD"
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=hello@hello&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "Invalid email" /tmp/response.html; then
    pass_test "Email without TLD rejected (hello@hello)"
else
    fail_test "Email without TLD validation failed"
fi

# Test email with just @ symbol
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=@example.com&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "Invalid email" /tmp/response.html; then
    pass_test "Email without username rejected (@example.com)"
else
    fail_test "Email without username should be rejected"
fi

# Test incomplete email (user@)
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=user@&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "Invalid email" /tmp/response.html; then
    pass_test "Incomplete email rejected (user@)"
else
    fail_test "Incomplete email should be rejected"
fi

echo ""

# ============================================
# Test 3: Password Validation
# ============================================
echo "Test 3: Password Validation"

# Test short password (< 8 chars)
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=test@test.com&password=Pass1!&confirm_password=Pass1!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "at least 8 characters" /tmp/response.html; then
    pass_test "Short password rejected (< 8 chars)"
else
    fail_test "Short password validation failed"
fi

# Test password mismatch
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=testuser&email=test@test.com&password=Password123!&confirm_password=Password456!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "do not match" /tmp/response.html; then
    pass_test "Password mismatch detected"
else
    fail_test "Password mismatch validation failed"
fi

echo ""

# ============================================
# Test 4: Create Valid User for Post Tests
# ============================================
echo "Test 4: Create valid user for post/comment tests"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "username=${VALID_USER}&email=${VALID_EMAIL}&password=${VALID_PASSWORD}&confirm_password=${VALID_PASSWORD}" \
    $BASE_URL/register)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Valid user created successfully"
else
    fail_test "Valid user creation failed (HTTP $RESPONSE)"
fi

# Login the user
curl -s -L -c $COOKIE_FILE -o /dev/null \
    -X POST \
    -d "username=${VALID_USER}&password=${VALID_PASSWORD}" \
    $BASE_URL/login

echo ""

# ============================================
# Test 5: Post Title Validation
# ============================================
echo "Test 5: Post Title Validation"

# Test short title (< 3 chars)
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=ab&content=This is valid content with more than ten characters&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "at least 3 characters" /tmp/response.html; then
    pass_test "Short title rejected (< 3 chars)"
else
    fail_test "Short title validation failed (HTTP $RESPONSE)"
fi

# Test long title (> 255 chars)
LONG_TITLE="a123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345"
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=${LONG_TITLE}&content=This is valid content with more than ten characters&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "no more than 255 characters" /tmp/response.html; then
    pass_test "Long title rejected (> 255 chars)"
else
    fail_test "Long title validation failed (HTTP $RESPONSE)"
fi

# Test empty title
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=&content=This is valid content with more than ten characters&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "required" /tmp/response.html; then
    pass_test "Empty title rejected"
else
    fail_test "Empty title validation failed (HTTP $RESPONSE)"
fi

echo ""

# ============================================
# Test 6: Post Content Validation
# ============================================
echo "Test 6: Post Content Validation"

# Test short content (< 10 chars)
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=Valid Title&content=short&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "at least 10 characters" /tmp/response.html; then
    pass_test "Short content rejected (< 10 chars)"
else
    fail_test "Short content validation failed (HTTP $RESPONSE)"
fi

# Test empty content
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=Valid Title&content=&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "required" /tmp/response.html; then
    pass_test "Empty content rejected"
else
    fail_test "Empty content validation failed (HTTP $RESPONSE)"
fi

echo ""

# ============================================
# Test 7: Category Validation
# ============================================
echo "Test 7: Category Validation"

# Test no categories selected
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=Valid Title&content=This is valid content with more than ten characters" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "at least one category" /tmp/response.html; then
    pass_test "No categories rejected"
else
    fail_test "Category requirement validation failed (HTTP $RESPONSE)"
fi

# Test too many categories (> 5)
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -b $COOKIE_FILE \
    -X POST \
    -d "title=Valid Title&content=This is valid content&category_id[]=1&category_id[]=2&category_id[]=3&category_id[]=4&category_id[]=5&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 200 ] && grep -q "up to 5 categories" /tmp/response.html; then
    pass_test "Too many categories rejected (> 5)"
else
    info_test "Too many categories test (check if limit exists) - HTTP $RESPONSE"
fi

echo ""

# ============================================
# Test 8: Create Valid Post for Comment Tests
# ============================================
echo "Test 8: Create valid post for comment tests"

RESPONSE=$(curl -s -b $COOKIE_FILE -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "title=Test Post for Comments&content=This is a valid test post with enough content&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Valid post created for comment tests"
else
    fail_test "Valid post creation failed (HTTP $RESPONSE)"
fi

echo ""

# ============================================
# Test 9: Comment Content Validation
# ============================================
echo "Test 9: Comment Content Validation"

# ✅ FIXED: Changed /reply/ to /comment/
# Test short comment (< 10 chars)
RESPONSE=$(curl -s -b $COOKIE_FILE -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "content=short" \
    $BASE_URL/comment/1)
if [ $RESPONSE -eq 200 ] && grep -q "at least 10 characters" /tmp/response.html; then
    pass_test "Short comment rejected (< 10 chars)"
else
    fail_test "Short comment validation failed (HTTP $RESPONSE)"
fi

# Test empty comment
RESPONSE=$(curl -s -b $COOKIE_FILE -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "content=" \
    $BASE_URL/comment/1)
if [ $RESPONSE -eq 200 ] && grep -q "required" /tmp/response.html; then
    pass_test "Empty comment rejected"
else
    fail_test "Empty comment validation failed (HTTP $RESPONSE)"
fi

echo ""

# ============================================
# Test 10: Unicode Character Validation
# ============================================
echo "Test 10: Unicode Character Validation"

# Test username with Cyrillic characters
RESPONSE=$(curl -s -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "username=Привет&email=test@test.com&password=Password123!&confirm_password=Password123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 200 ] && grep -q "can only contain" /tmp/response.html; then
    pass_test "Cyrillic characters in username rejected"
else
    fail_test "Unicode username validation failed"
fi

# Test post title with emoji (should work - counting characters correctly)
RESPONSE=$(curl -s -b $COOKIE_FILE -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "title=Test 😀 Post&content=This is valid content with emoji 😀 and more than ten characters&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Emoji in title accepted (correct character counting)"
else
    fail_test "Emoji validation test (HTTP $RESPONSE)"
fi

# Test very long content with multibyte characters
CYRILLIC_CONTENT="Привет мир! Это тестовое сообщение на русском языке для проверки валидации контента."
RESPONSE=$(curl -s -b $COOKIE_FILE -o /tmp/response.html -w "%{http_code}" \
    -X POST \
    -d "title=Cyrillic Test&content=${CYRILLIC_CONTENT}&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Multibyte characters in content handled correctly"
else
    fail_test "Multibyte character validation failed (HTTP $RESPONSE)"
fi

echo ""

# ============================================
# Test 11: Valid Inputs (Should Succeed)
# ============================================
echo "Test 11: Valid Inputs (Should Succeed)"

# Test valid username - use nanoseconds for uniqueness
UNIQUE_TIMESTAMP=$(date +%s%N 2>/dev/null || date +%s)
VALID_TEST_USER="valid_user_${UNIQUE_TIMESTAMP}"
VALID_TEST_EMAIL="valid${UNIQUE_TIMESTAMP}@test.com"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "username=${VALID_TEST_USER}&email=${VALID_TEST_EMAIL}&password=ValidPass123!&confirm_password=ValidPass123!" \
    $BASE_URL/register)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Valid registration accepted"
else
    fail_test "Valid registration rejected (HTTP $RESPONSE)"
fi

# Login valid user
curl -s -L -c $COOKIE_FILE -o /dev/null \
    -X POST \
    -d "username=${VALID_TEST_USER}&password=ValidPass123!" \
    $BASE_URL/login

# Test valid post
RESPONSE=$(curl -s -b $COOKIE_FILE -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "title=Valid Test Post&content=This is a completely valid post with proper content length and formatting&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Valid post accepted"
else
    fail_test "Valid post rejected (HTTP $RESPONSE)"
fi

# ✅ FIXED: Changed /reply/ to /comment/
# Test valid comment
RESPONSE=$(curl -s -b $COOKIE_FILE -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "content=This is a valid comment with enough characters" \
    $BASE_URL/comment/1)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Valid comment accepted"
else
    fail_test "Valid comment rejected (HTTP $RESPONSE)"
fi

echo ""

# ============================================
# Test Summary
# ============================================
echo "=================================="
echo "Validation Test Summary"
echo "=================================="
info_test "Tested username validation (length, characters)"
info_test "Tested email validation (format, structure)"
info_test "Tested password validation (length, matching)"
info_test "Tested post title validation (length limits)"
info_test "Tested post content validation (length limits)"
info_test "Tested category validation (selection requirements)"
info_test "Tested comment validation (length limits)"
info_test "Tested Unicode character handling"
info_test "Verified valid inputs are accepted"
echo ""

# Cleanup
rm -f $COOKIE_FILE /tmp/response.html

echo "Validation testing complete!"