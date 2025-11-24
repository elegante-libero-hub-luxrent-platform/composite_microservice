#!/bin/bash
# Test script for User & Profile Service API

set -e

BASE_URL="https://user-and-profile-service-314897419193.europe-west1.run.app"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Testing User & Profile Service API ==="
echo "Base URL: $BASE_URL"
echo ""

# Test 1: Root/Health Check
echo -e "${BLUE}1. GET / (Root/Health Check)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    echo "$RESPONSE" | grep -A 5 "{" | head -3
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
    echo "$RESPONSE" | head -10
fi
echo ""

# Test 2: Get User
echo -e "${BLUE}2. GET /users/{id} (Get User)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/users/1")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    ETAG=$(echo "$RESPONSE" | grep -i "etag:" | sed 's/.*etag: //i' | tr -d '\r')
    if [ -n "$ETAG" ]; then
        echo "   ETag: $ETAG"
    fi
    echo "$RESPONSE" | tail -1 | python3 -m json.tool 2>/dev/null | head -20 || echo "$RESPONSE" | tail -1
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠️  Status: $HTTP_CODE Not Found (User may not exist)${NC}"
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
    echo "$RESPONSE" | tail -5
fi
echo ""

# Test 3: Get User with If-None-Match (if ETag available)
if [ -n "$ETAG" ] && [ "$HTTP_CODE" = "200" ]; then
    echo -e "${BLUE}3. GET /users/{id} with If-None-Match (ETag)${NC}"
    RESPONSE=$(curl -sS -i -H "If-None-Match: $ETAG" "$BASE_URL/users/1")
    HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
    if [ "$HTTP_CODE" = "304" ]; then
        echo -e "${GREEN}✅ Status: $HTTP_CODE Not Modified (ETag working)${NC}"
    else
        echo -e "${YELLOW}⚠️  Status: $HTTP_CODE (Expected 304)${NC}"
    fi
    echo ""
fi

# Test 4: Try different user IDs
echo -e "${BLUE}4. Testing different user IDs${NC}"
for USER_ID in 1 2 3 12; do
    echo "   Testing user ID: $USER_ID"
    RESPONSE=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/users/$USER_ID" 2>&1)
    if [ "$RESPONSE" = "200" ]; then
        echo -e "   ${GREEN}✅ User $USER_ID exists${NC}"
    elif [ "$RESPONSE" = "404" ]; then
        echo -e "   ${YELLOW}⚠️  User $USER_ID not found${NC}"
    else
        echo -e "   ${RED}❌ Unexpected status: $RESPONSE${NC}"
    fi
done
echo ""

# Test 5: List Users (if endpoint exists)
echo -e "${BLUE}5. GET /users (List Users - if available)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/users")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    echo "$RESPONSE" | tail -1 | python3 -m json.tool 2>/dev/null | head -20 || echo "$RESPONSE" | tail -1
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠️  Endpoint not available (404)${NC}"
else
    echo -e "${YELLOW}⚠️  Status: $HTTP_CODE${NC}"
fi
echo ""

# Test 6: API Documentation
echo -e "${BLUE}6. GET /docs (API Documentation)${NC}"
RESPONSE=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/docs" 2>&1)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    echo "   API docs available at: $BASE_URL/docs"
else
    echo -e "${YELLOW}⚠️  Status: $RESPONSE${NC}"
fi
echo ""

echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""
echo "Service URL: $BASE_URL"
echo "Access Status: $(if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then echo "✅ Accessible"; else echo "❌ Not accessible"; fi)"
echo ""
echo "Available endpoints:"
echo "  - GET / (Root/Health)"
echo "  - GET /users/{id} (Get User)"
echo "  - GET /docs (API Documentation)"

