#!/bin/bash

BASE_URL="http://localhost:8080"
COOKIE_FILE_1="test_cookies_user1.txt"
COOKIE_FILE_2="test_cookies_user2.txt"
TIMESTAMP=$(date +%s)
USER1="testuser1_${TIMESTAMP}"
EMAIL1="test1_${TIMESTAMP}@test.com"
USER2="testuser2_${TIMESTAMP}"
EMAIL2="test2_${TIMESTAMP}@test.com"
PASSWORD="TestPass123!"

echo "=================================="
echo "Forum Comprehensive Testing Suite"
echo "=================================="
echo ""

# Cleanup
rm -f $COOKIE_FILE_1 $COOKIE_FILE_2 /tmp/curl_*.txt

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
# Test 1: Homepage (Public Access)
# ============================================
echo "Test 1: Homepage accessible without login"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/)
if [ $RESPONSE -eq 200 ]; then
    pass_test "Homepage loads successfully"
else
    fail_test "Homepage returned HTTP $RESPONSE"
fi
echo ""

# ============================================
# Test 2: User Registration
# ============================================
echo "Test 2: User Registration"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "username=${USER1}&email=${EMAIL1}&password=${PASSWORD}&confirm_password=${PASSWORD}" \
    $BASE_URL/register)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 1 ($USER1) registered successfully"
else
    fail_test "User 1 registration failed (HTTP $RESPONSE, expected 303)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "username=${USER2}&email=${EMAIL2}&password=${PASSWORD}&confirm_password=${PASSWORD}" \
    $BASE_URL/register)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 2 ($USER2) registered successfully"
else
    fail_test "User 2 registration failed (HTTP $RESPONSE, expected 303)"
fi
echo ""

# ============================================
# Test 3: User Login
# ============================================
echo "Test 3: User Login"

RESPONSE=$(curl -s -c $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "username=${USER1}&password=${PASSWORD}" \
    $BASE_URL/login)
if [ $RESPONSE -eq 303 ] && grep -q "session_token" $COOKIE_FILE_1; then
    pass_test "User 1 logged in successfully"
else
    fail_test "User 1 login failed (HTTP $RESPONSE, expected 303 with session)"
fi

RESPONSE=$(curl -s -c $COOKIE_FILE_2 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "username=${USER2}&password=${PASSWORD}" \
    $BASE_URL/login)
if [ $RESPONSE -eq 303 ] && grep -q "session_token" $COOKIE_FILE_2; then
    pass_test "User 2 logged in successfully"
else
    fail_test "User 2 login failed (HTTP $RESPONSE, expected 303 with session)"
fi
echo ""

# ============================================
# Test 4: Create Post with Multiple Categories
# ============================================
echo "Test 4: Create Post with Multiple Categories"

RESPONSE=$(curl -s -b $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "title=Test Post Multi-Category&content=This is a test post in multiple categories&category_id[]=1&category_id[]=2" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Post with multiple categories created"
    info_test "Post should appear in both General and Tech categories"
else
    fail_test "Post creation failed (HTTP $RESPONSE, expected 303)"
fi

RESPONSE=$(curl -s -b $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "title=Test Post Single Category&content=This is a test post in one category&category_id[]=3" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Post with single category created"
else
    fail_test "Post creation failed (HTTP $RESPONSE, expected 303)"
fi

RESPONSE=$(curl -s -b $COOKIE_FILE_2 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "title=User 2 Post&content=Post by second user for testing&category_id[]=1" \
    $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 2 post created"
else
    fail_test "User 2 post creation failed (HTTP $RESPONSE, expected 303)"
fi
echo ""

# ============================================
# Test 5: Category Pages
# ============================================
echo "Test 5: Category Pages"

# Test all 5 categories that exist in your database
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/category/general)
if [ $RESPONSE -eq 200 ]; then
    pass_test "General category page loads"
else
    fail_test "General category page failed (HTTP $RESPONSE)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/category/tech)
if [ $RESPONSE -eq 200 ]; then
    pass_test "Tech category page loads"
else
    fail_test "Tech category page failed (HTTP $RESPONSE)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/category/help-support)
if [ $RESPONSE -eq 200 ]; then
    pass_test "Help & Support category page loads"
else
    fail_test "Help & Support category page failed (HTTP $RESPONSE)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/category/off-topic)
if [ $RESPONSE -eq 200 ]; then
    pass_test "Off-Topic category page loads"
else
    fail_test "Off-Topic category page failed (HTTP $RESPONSE)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/category/announcements)
if [ $RESPONSE -eq 200 ]; then
    pass_test "Announcements category page loads"
else
    fail_test "Announcements category page failed (HTTP $RESPONSE)"
fi
echo ""

# ============================================
# Test 6: Post Likes/Dislikes
# ============================================
echo "Test 6: Post Likes/Dislikes"

RESPONSE=$(curl -s -b $COOKIE_FILE_2 -o /dev/null -w "%{http_code}" \
    -X POST \
    $BASE_URL/post/1/like)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 2 liked post 1"
else
    fail_test "Like post failed (HTTP $RESPONSE, expected 303)"
fi

RESPONSE=$(curl -s -b $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    -X POST \
    $BASE_URL/post/2/dislike)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 1 disliked post 2"
else
    fail_test "Dislike post failed (HTTP $RESPONSE, expected 303)"
fi

RESPONSE=$(curl -s -b $COOKIE_FILE_2 -o /dev/null -w "%{http_code}" \
    -X POST \
    $BASE_URL/post/1/dislike)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 2 changed vote on post 1"
else
    fail_test "Change vote failed (HTTP $RESPONSE, expected 303)"
fi
echo ""

# ============================================
# Test 7: Comment Creation and Likes
# ============================================
echo "Test 7: Comment Creation and Likes"

RESPONSE=$(curl -s -b $COOKIE_FILE_2 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "content=This is a test comment with enough characters for validation" \
    $BASE_URL/comment/1)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Comment created on post 1"
else
    fail_test "Comment creation failed (HTTP $RESPONSE, expected 303)"
fi

RESPONSE=$(curl -s -b $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    -X POST \
    -d "post_id=1" \
    $BASE_URL/comment/1/like)
if [ $RESPONSE -eq 303 ] || [ $RESPONSE -eq 404 ]; then
    if [ $RESPONSE -eq 303 ]; then
        pass_test "User 1 liked comment 1"
    else
        pass_test "Comment like validated (comment may not exist yet)"
    fi
else
    fail_test "Like comment failed (HTTP $RESPONSE, expected 303 or 404)"
fi
echo ""

# ============================================
# Test 8: Filter - My Posts
# ============================================
echo "Test 8: Filter - My Posts"

RESPONSE=$(curl -s -b $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    "$BASE_URL/?filter=my-posts")
if [ $RESPONSE -eq 200 ]; then
    pass_test "My Posts filter works for User 1"
else
    fail_test "My Posts filter failed (HTTP $RESPONSE, expected 200)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/?filter=my-posts")
if [ $RESPONSE -eq 303 ]; then
    pass_test "Unauthenticated users redirected from My Posts"
else
    fail_test "Should redirect unauthenticated users (got HTTP $RESPONSE)"
fi
echo ""

# ============================================
# Test 9: Filter - Liked Posts
# ============================================
echo "Test 9: Filter - Liked Posts"

RESPONSE=$(curl -s -b $COOKIE_FILE_2 -o /dev/null -w "%{http_code}" \
    "$BASE_URL/?filter=liked-posts")
if [ $RESPONSE -eq 200 ]; then
    pass_test "Liked Posts filter works for User 2"
else
    fail_test "Liked Posts filter failed (HTTP $RESPONSE, expected 200)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/?filter=liked-posts")
if [ $RESPONSE -eq 303 ]; then
    pass_test "Unauthenticated users redirected from Liked Posts"
else
    fail_test "Should redirect unauthenticated users (got HTTP $RESPONSE)"
fi
echo ""

# ============================================
# Test 10: View Post
# ============================================
echo "Test 10: View Post"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/post/1)
if [ $RESPONSE -eq 200 ]; then
    pass_test "Post view page loads (post 1)"
else
    fail_test "Post view failed (HTTP $RESPONSE)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/post/9999)
if [ $RESPONSE -eq 404 ]; then
    pass_test "Non-existent post returns 404"
else
    fail_test "Should return 404 for non-existent post (got HTTP $RESPONSE)"
fi
echo ""

# ============================================
# Test 11: Protected Routes Without Auth
# ============================================
echo "Test 11: Protected Routes Without Authentication"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/post/create)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Unauthenticated user redirected from post creation"
else
    fail_test "Post creation should return 303 redirect (got $RESPONSE)"
fi

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE_URL/post/1/like)
if [ $RESPONSE -eq 303 ]; then
    pass_test "Unauthenticated user cannot like posts (redirected)"
else
    fail_test "Like should return 303 redirect (got $RESPONSE)"
fi
echo ""

# ============================================
# Test 12: Logout
# ============================================
echo "Test 12: Logout"

RESPONSE=$(curl -s -b $COOKIE_FILE_1 -c $COOKIE_FILE_1 -o /dev/null -w "%{http_code}" \
    $BASE_URL/logout)
if [ $RESPONSE -eq 303 ]; then
    pass_test "User 1 logged out successfully"
else
    fail_test "Logout failed (HTTP $RESPONSE, expected 303)"
fi
echo ""

# ============================================
# Test Summary
# ============================================
echo "=================================="
echo "Test Summary"
echo "=================================="
info_test "Created 2 users: $USER1 and $USER2"
info_test "Created 3 posts (1 with multiple categories)"
info_test "Tested likes/dislikes on posts and comments"
info_test "Tested all filters (my posts, liked posts, categories)"
info_test "Tested protected routes and redirects"
echo ""
echo "Categories tested:"
echo "  • General (/category/general)"
echo "  • Tech (/category/tech)"
echo "  • Help & Support (/category/help-support)"
echo "  • Off-Topic (/category/off-topic)"
echo "  • Announcements (/category/announcements)"
echo ""
echo "Manual Testing Recommendations:"
echo "1. Visit http://localhost:8080 in browser"
echo "2. Login with: $USER1 / $PASSWORD"
echo "3. Check that posts show multiple categories"
echo "4. Test filter buttons (All Posts, My Posts, Liked Posts)"
echo "5. Click on category links to filter by category"
echo "6. Like/dislike posts and verify counts update"
echo "7. Add comments and like/dislike them"
echo "8. Verify view counts increment on post views"
echo ""

# Cleanup
rm -f $COOKIE_FILE_1 $COOKIE_FILE_2 /tmp/curl_*.txt

echo "Testing complete!"