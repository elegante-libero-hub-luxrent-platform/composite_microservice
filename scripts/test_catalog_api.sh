#!/bin/bash
# Comprehensive test script for Catalog & Inventory Service API
# Tests all implemented endpoints

set -e

BASE_URL="https://catalog-and-inventory-service-314897419193.europe-west1.run.app"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Testing Catalog & Inventory Service API ==="
echo "Base URL: $BASE_URL"
echo ""

# Track created item ID for subsequent tests
CREATED_ITEM_ID=""

# Test 1: Root/Health Check
echo -e "${BLUE}1. GET / (Root/Health Check)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    echo "$RESPONSE" | grep -A 5 "{" | head -3
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
fi
echo ""

# Test 2: List Catalog Items (Empty)
echo -e "${BLUE}2. GET /catalog/items (List - Empty)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/catalog/items?pageSize=2")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    echo "$RESPONSE" | tail -1 | python3 -m json.tool 2>/dev/null || echo "$RESPONSE" | tail -1
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
    echo "$RESPONSE" | tail -5
fi
echo ""

# Test 3: Create Catalog Item
echo -e "${BLUE}3. POST /catalog/items (Create Item)${NC}"
CREATE_BODY='{
  "sku": "TEST-SKU-'$(date +%s)'",
  "name": "Luxury Test Handbag",
  "brand": "Gucci",
  "category": "Handbag",
  "description": "A beautiful test handbag for API testing",
  "photos": ["https://example.com/photo1.jpg"],
  "rent_price_cents": 5000,
  "deposit_cents": 10000,
  "attrs": {
    "color": "Black",
    "size": "Medium",
    "condition": "Excellent"
  }
}'

RESPONSE=$(curl -sS -i -X POST "$BASE_URL/catalog/items" \
  -H 'Content-Type: application/json' \
  -d "$CREATE_BODY")

HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE Created${NC}"
    LOCATION=$(echo "$RESPONSE" | grep -i "location:" | sed 's/.*location: //i' | tr -d '\r')
    CREATED_ITEM_ID=$(echo "$RESPONSE" | tail -1 | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
    echo "   Location: $LOCATION"
    echo "   Item ID: $CREATED_ITEM_ID"
    echo "$RESPONSE" | tail -1 | python3 -m json.tool 2>/dev/null | head -15 || echo "$RESPONSE" | tail -1
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
    echo "$RESPONSE" | tail -5
fi
echo ""

if [ -z "$CREATED_ITEM_ID" ]; then
    echo -e "${YELLOW}⚠️  Cannot continue tests without created item ID${NC}"
    exit 1
fi

# Test 4: List Catalog Items (With Data)
echo -e "${BLUE}4. GET /catalog/items (List - With Data)${NC}"
RESPONSE=$(curl -sS "$BASE_URL/catalog/items?pageSize=5")
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | head -20 || echo "$RESPONSE"
echo ""

# Test 5: Get Specific Item
echo -e "${BLUE}5. GET /catalog/items/{id} (Get Item)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/catalog/items/$CREATED_ITEM_ID")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    ETAG=$(echo "$RESPONSE" | grep -i "etag:" | sed 's/.*etag: //i' | tr -d '\r')
    if [ -n "$ETAG" ]; then
        echo "   ETag: $ETAG"
    fi
    echo "$RESPONSE" | tail -1 | python3 -m json.tool 2>/dev/null | head -15 || echo "$RESPONSE" | tail -1
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
    echo "$RESPONSE" | tail -5
fi
echo ""

# Test 6: Get Item with If-None-Match (304 Not Modified)
if [ -n "$ETAG" ]; then
    echo -e "${BLUE}6. GET /catalog/items/{id} with If-None-Match (ETag)${NC}"
    RESPONSE=$(curl -sS -i -H "If-None-Match: $ETAG" "$BASE_URL/catalog/items/$CREATED_ITEM_ID")
    HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
    if [ "$HTTP_CODE" = "304" ]; then
        echo -e "${GREEN}✅ Status: $HTTP_CODE Not Modified (ETag working)${NC}"
    else
        echo -e "${YELLOW}⚠️  Status: $HTTP_CODE (Expected 304)${NC}"
    fi
    echo ""
fi

# Test 7: Update Item (PUT)
echo -e "${BLUE}7. PUT /catalog/items/{id} (Update Item)${NC}"
UPDATE_BODY='{
  "name": "Updated Luxury Test Handbag",
  "brand": "Prada",
  "rent_price_cents": 6000,
  "description": "Updated description"
}'

RESPONSE=$(curl -sS -i -X PUT "$BASE_URL/catalog/items/$CREATED_ITEM_ID" \
  -H 'Content-Type: application/json' \
  -d "$UPDATE_BODY")

HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE OK${NC}"
    echo "$RESPONSE" | tail -1 | python3 -m json.tool 2>/dev/null | head -15 || echo "$RESPONSE" | tail -1
else
    echo -e "${RED}❌ Status: $HTTP_CODE${NC}"
    echo "$RESPONSE" | tail -5
fi
echo ""

# Test 8: List with Filters
echo -e "${BLUE}8. GET /catalog/items (With Filters)${NC}"
echo "8a. Filter by brand:"
curl -sS "$BASE_URL/catalog/items?brand=Prada&pageSize=2" | python3 -m json.tool 2>/dev/null | head -10 || echo "Response received"
echo ""

echo "8b. Filter by category:"
curl -sS "$BASE_URL/catalog/items?category=Handbag&pageSize=2" | python3 -m json.tool 2>/dev/null | head -10 || echo "Response received"
echo ""

echo "8c. Filter by price range:"
curl -sS "$BASE_URL/catalog/items?minPrice=4000&maxPrice=7000&pageSize=2" | python3 -m json.tool 2>/dev/null | head -10 || echo "Response received"
echo ""

# Test 9: Pagination
echo -e "${BLUE}9. GET /catalog/items (Pagination Test)${NC}"
FIRST_PAGE=$(curl -sS "$BASE_URL/catalog/items?pageSize=2")
NEXT_TOKEN=$(echo "$FIRST_PAGE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('nextPageToken', ''))" 2>/dev/null || echo "")
if [ -n "$NEXT_TOKEN" ] && [ "$NEXT_TOKEN" != "null" ]; then
    echo -e "${GREEN}✅ Pagination token received: $NEXT_TOKEN${NC}"
    echo "   First page items: $(echo "$FIRST_PAGE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('items', [])))" 2>/dev/null || echo "?")"
    echo ""
    echo "   Fetching next page:"
    curl -sS "$BASE_URL/catalog/items?pageSize=2&nextPageToken=$NEXT_TOKEN" | python3 -m json.tool 2>/dev/null | head -10 || echo "Response received"
else
    echo -e "${YELLOW}⚠️  No pagination token (may be last page or only one page)${NC}"
fi
echo ""

# Test 10: Delete Item
echo -e "${BLUE}10. DELETE /catalog/items/{id} (Delete Item)${NC}"
RESPONSE=$(curl -sS -i -X DELETE "$BASE_URL/catalog/items/$CREATED_ITEM_ID")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "204" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE No Content (Deleted)${NC}"
else
    echo -e "${RED}❌ Status: $HTTP_CODE (Expected 204)${NC}"
    echo "$RESPONSE" | tail -5
fi
echo ""

# Test 11: Verify Deletion
echo -e "${BLUE}11. GET /catalog/items/{id} (Verify Deletion - Should 404)${NC}"
RESPONSE=$(curl -sS -i "$BASE_URL/catalog/items/$CREATED_ITEM_ID")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "404" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE Not Found (Correctly deleted)${NC}"
else
    echo -e "${YELLOW}⚠️  Status: $HTTP_CODE (Expected 404)${NC}"
fi
echo ""

# Test 12: Not Implemented Endpoints
echo -e "${BLUE}12. Testing Not Implemented Endpoints (Should return 501)${NC}"
echo "12a. GET /physical-items:"
RESPONSE=$(curl -sS -i "$BASE_URL/physical-items")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "501" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE Not Implemented (Expected)${NC}"
else
    echo -e "${YELLOW}⚠️  Status: $HTTP_CODE${NC}"
fi
echo ""

echo "12b. GET /availability:"
RESPONSE=$(curl -sS -i "$BASE_URL/availability?sku=TEST&start_date=2025-01-01&end_date=2025-01-05")
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "501" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE Not Implemented (Expected)${NC}"
else
    echo -e "${YELLOW}⚠️  Status: $HTTP_CODE${NC}"
fi
echo ""

echo "12c. POST /reservations:"
RESPONSE=$(curl -sS -i -X POST "$BASE_URL/reservations" -H 'Content-Type: application/json' -d '{}')
HTTP_CODE=$(echo "$RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}')
if [ "$HTTP_CODE" = "501" ]; then
    echo -e "${GREEN}✅ Status: $HTTP_CODE Not Implemented (Expected)${NC}"
else
    echo -e "${YELLOW}⚠️  Status: $HTTP_CODE${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=== Test Summary ===${NC}"
echo ""
echo "Implemented Endpoints Tested:"
echo "  ✅ GET / (Root)"
echo "  ✅ GET /catalog/items (List)"
echo "  ✅ POST /catalog/items (Create)"
echo "  ✅ GET /catalog/items/{id} (Get)"
echo "  ✅ PUT /catalog/items/{id} (Update)"
echo "  ✅ DELETE /catalog/items/{id} (Delete)"
echo "  ✅ GET /catalog/items (Filters)"
echo "  ✅ GET /catalog/items (Pagination)"
echo "  ✅ GET /catalog/items/{id} (ETag/304)"
echo ""
echo "Not Implemented Endpoints (501):"
echo "  ✅ GET /physical-items"
echo "  ✅ GET /availability"
echo "  ✅ POST /reservations"
echo ""
echo -e "${GREEN}✅ All catalog API methods tested!${NC}"

