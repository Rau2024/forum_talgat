#!/bin/bash

BASE_URL="http://localhost:8080"
TIMESTAMP=$(date +%s)
RANDOM_ID=$(( RANDOM % 10000 ))

echo "=========================================="
echo "Password Validation Test Suite"
echo "=========================================="
echo "Test Run ID: ${TIMESTAMP}_${RANDOM_ID}"
echo "Testing Strong Password Policy Requirements"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

pass_test() { 
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

fail_test() { 
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

info_test() { 
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Test function with unique usernames
test_password() {
    local test_num=$1
    local password=$2
    local expected_result=$3
    local description=$4
    
    # Create unique username for each test
    local username="pwtest${test_num}_${TIMESTAMP}_${RANDOM_ID}"
    local email="${username}@test.com"
    
    echo ""
    echo "Test $test_num: $description"
    info_test "Password: '$password' (length: ${#password})"
    
    # URL encode the password to handle special characters like & and %
    local encoded_password=$(printf %s "$password" | jq -sRr @uri)
    
    RESPONSE=$(curl -s -X POST "$BASE_URL/register" \
        --data-urlencode "username=${username}" \
        --data-urlencode "email=${email}" \
        --data-urlencode "password=${password}" \
        --data-urlencode "confirm_password=${password}")
    
    if [ "$expected_result" = "reject" ]; then
        # Should be rejected - check for error message
        if echo "$RESPONSE" | grep -q "Password must" || echo "$RESPONSE" | grep -q "Password cannot"; then
            pass_test "Backend correctly rejected invalid password"
            # Show which validation message was returned
            ERROR_MSG=$(echo "$RESPONSE" | grep -o 'Password [^<]*' | head -1 | sed 's/&amp;/\&/g')
            info_test "Error message: $ERROR_MSG"
        else
            fail_test "Backend accepted invalid password (should have been rejected)"
        fi
    else
        # Should be accepted - check for redirect or success
        if echo "$RESPONSE" | grep -q "registered=1"; then
            pass_test "Backend accepted valid password"
        elif echo "$RESPONSE" | grep -q "Password must" || echo "$RESPONSE" | grep -q "Password cannot"; then
            ERROR_MSG=$(echo "$RESPONSE" | grep -o 'Password [^<]*' | head -1 | sed 's/&amp;/\&/g')
            fail_test "Backend rejected valid password (should have been accepted)"
            info_test "Error message: $ERROR_MSG"
        else
            # Check HTTP status code for redirect
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/register" \
                --data-urlencode "username=${username}_2" \
                --data-urlencode "email=${username}_2@test.com" \
                --data-urlencode "password=${password}" \
                --data-urlencode "confirm_password=${password}")
            if [ "$STATUS" = "303" ]; then
                pass_test "Backend accepted valid password (HTTP 303 redirect)"
            else
                fail_test "Backend rejected valid password (HTTP $STATUS)"
            fi
        fi
    fi
}

# ===========================================
# Section 1: Length Requirements
# ===========================================
section "Section 1: Password Length Requirements"

test_password 1 "Abc1!" "reject" "Too short (5 characters)"
test_password 2 "Abc12!" "reject" "Too short (6 characters)"  
test_password 3 "Abc123!" "reject" "Too short (7 characters)"
test_password 4 "Abcd123!" "accept" "Minimum valid length (8 characters)"
test_password 5 "Password123!" "accept" "Medium length (12 characters)"

# Create password over 128 characters
LONG_PASSWORD="Password123!"
for i in {1..20}; do
    LONG_PASSWORD="${LONG_PASSWORD}1234567"
done
test_password 6 "$LONG_PASSWORD" "reject" "Too long (>128 characters)"

# ===========================================
# Section 2: Character Type Requirements
# ===========================================
section "Section 2: Character Type Requirements"

test_password 7 "password123!" "reject" "Missing uppercase letter"
test_password 8 "PASSWORD123!" "reject" "Missing lowercase letter"
test_password 9 "Password!" "reject" "Missing digit"
test_password 10 "Password123" "reject" "Missing special character"
test_password 11 "12345678!@#" "reject" "Missing letters (only numbers + special)"
test_password 12 "abcdefgh!" "reject" "Missing uppercase and digit"

# ===========================================
# Section 3: Space Validation
# ===========================================
section "Section 3: Space Validation"

test_password 13 "Pass word123!" "reject" "Contains space in middle"
test_password 14 " Password123!" "reject" "Leading space"
test_password 15 "Password123! " "reject" "Trailing space"
test_password 16 "My Pass Word1!" "reject" "Multiple spaces"
test_password 17 "Password  123!" "reject" "Double space"

# ===========================================
# Section 4: Valid Strong Passwords
# ===========================================
section "Section 4: Valid Strong Passwords"

test_password 18 "Password123!" "accept" "Standard strong password"
test_password 19 "MyP@ss2024" "accept" "With @ symbol"
test_password 20 "Str0ng#Pass$" "accept" "With # and $ symbols"
test_password 21 "My_Pass123" "accept" "With underscore"
test_password 22 "My-Pass123" "accept" "With hyphen"
test_password 23 "Pass(123)W" "accept" "With parentheses"
test_password 24 "P@ssw0rd!2024" "accept" "Multiple special characters"
test_password 25 "Secure&Pass1" "accept" "With ampersand"
test_password 26 "Test%Pass9" "accept" "With percent sign"
test_password 27 "Valid^Pass7" "accept" "With caret"
test_password 28 "Strong*Pass3" "accept" "With asterisk"

# ===========================================
# Section 5: Password Confirmation Mismatch
# ===========================================
section "Section 5: Password Confirmation Validation"

echo ""
echo "Test 29: Mismatched passwords"
username="pwtest29_${TIMESTAMP}_${RANDOM_ID}"
RESPONSE=$(curl -s -X POST "$BASE_URL/register" \
    --data-urlencode "username=${username}" \
    --data-urlencode "email=${username}@test.com" \
    --data-urlencode "password=Password123!" \
    --data-urlencode "confirm_password=DifferentPass456!")

if echo "$RESPONSE" | grep -q "do not match"; then
    pass_test "Backend rejected mismatched passwords"
else
    fail_test "Backend accepted mismatched passwords"
fi

echo ""
echo "Test 30: Matching valid passwords"
username="pwtest30_${TIMESTAMP}_${RANDOM_ID}"
RESPONSE=$(curl -s -X POST "$BASE_URL/register" \
    --data-urlencode "username=${username}" \
    --data-urlencode "email=${username}@test.com" \
    --data-urlencode "password=Password123!" \
    --data-urlencode "confirm_password=Password123!")

if echo "$RESPONSE" | grep -q "registered=1" || curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/register" \
    --data-urlencode "username=${username}_2" \
    --data-urlencode "email=${username}_2@test.com" \
    --data-urlencode "password=Password123!" \
    --data-urlencode "confirm_password=Password123!" | grep -q "303"; then
    pass_test "Backend accepted matching valid passwords"
else
    fail_test "Backend rejected matching valid passwords"
fi

# ===========================================
# Final Summary
# ===========================================
section "Test Results Summary"

echo ""
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
fi

echo ""
echo "=========================================="
echo "Password Policy Requirements:"
echo "=========================================="
echo "✓ Minimum 8 characters"
echo "✓ Maximum 128 characters"
echo "✓ At least one uppercase letter (A-Z)"
echo "✓ At least one lowercase letter (a-z)"
echo "✓ At least one digit (0-9)"
echo "✓ At least one special character (!@#\$%^&*()-_=+[]{}|;:',.<>?/~\`)"
echo "✓ No spaces allowed"
echo ""
echo "Valid password examples:"
echo "  • Password123!"
echo "  • MyP@ss2024"
echo "  • Str0ng#Pass\$"
echo "  • Secure_Pass1"
echo "  • Valid-Pass7"
echo ""
echo "Test completed at: $(date)"
echo "=========================================="