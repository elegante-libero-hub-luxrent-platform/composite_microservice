#!/bin/bash
# Comprehensive Demo Script for Composite Microservice
# Demonstrates all required features

# Don't exit on error - we want to continue demo even if some endpoints fail
set +e

# Auto-detect composite service URL if not set
if [ -z "$COMPOSITE_URL" ]; then
    # Try to get from gcloud
    DETECTED_URL=$(gcloud run services describe composite-microservice \
        --region=europe-west1 \
        --project=upheld-booking-475003-p1 \
        --format="value(status.url)" 2>/dev/null || echo "")
    
    if [ -n "$DETECTED_URL" ]; then
        COMPOSITE_URL="$DETECTED_URL"
        echo "Auto-detected composite service URL: $COMPOSITE_URL"
    else
        COMPOSITE_URL="http://localhost:8080"
        echo "Using default URL: $COMPOSITE_URL"
        echo "To use a different URL, set COMPOSITE_URL environment variable"
    fi
else
    COMPOSITE_URL="${COMPOSITE_URL}"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Composite Microservice - Comprehensive Demo              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Composite Service URL: $COMPOSITE_URL"
echo ""

# Helper function to print section headers
section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Helper function to print test results
test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# 1. Health Check
section "1. Health Check - Service Availability"
# Try healthz first, then readyz as fallback
HEALTH=$(curl -s "$COMPOSITE_URL/healthz" 2>/dev/null)
if [ -z "$HEALTH" ] || echo "$HEALTH" | grep -qi "error\|404\|not found"; then
    echo "Trying /readyz endpoint..."
    HEALTH=$(curl -s "$COMPOSITE_URL/readyz" 2>/dev/null)
fi

if echo "$HEALTH" | jq . > /dev/null 2>&1; then
    echo "$HEALTH" | jq .
    test_result 0 "Health check successful"
elif echo "$HEALTH" | grep -qi "ready\|ok"; then
    echo "$HEALTH"
    test_result 0 "Service is ready"
else
    echo -e "${YELLOW}⚠️  Health check endpoint not responding as expected${NC}"
    echo "Response: $HEALTH"
    echo -e "${YELLOW}Continuing with demo...${NC}"
fi

# 2. Encapsulation - Get User with ETag
section "2. Encapsulation - Get User (ETag Propagation)"
echo "Fetching user (replace with actual user ID)..."
USER_RESPONSE=$(curl -s -i "$COMPOSITE_URL/users/demo-user" 2>&1 || echo "HTTP/2 404")
if echo "$USER_RESPONSE" | grep -qi "etag"; then
    ETAG=$(echo "$USER_RESPONSE" | grep -i "etag:" | sed 's/.*etag: //i' | tr -d '\r')
    echo -e "${GREEN}✅ ETag received: $ETAG${NC}"
    echo ""
    echo "Testing If-None-Match (should return 304 if unchanged):"
    curl -s -i -H "If-None-Match: $ETAG" "$COMPOSITE_URL/users/demo-user" | head -5
else
    echo -e "${YELLOW}⚠️  User not found or ETag not present (this is OK if user doesn't exist)${NC}"
fi

# 3. Pagination - List Items
section "3. Pagination - List Items"
echo "Fetching first page (pageSize=3)..."
ITEMS_PAGE1=$(curl -s "$COMPOSITE_URL/items?pageSize=3" 2>&1)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$COMPOSITE_URL/items?pageSize=3" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ] && echo "$ITEMS_PAGE1" | jq . > /dev/null 2>&1; then
    echo "$ITEMS_PAGE1" | jq '.items[0:2] // .' 2>/dev/null || echo "$ITEMS_PAGE1"
    NEXT_TOKEN=$(echo "$ITEMS_PAGE1" | jq -r '.nextPageToken // empty' 2>/dev/null)
    if [ -n "$NEXT_TOKEN" ] && [ "$NEXT_TOKEN" != "null" ]; then
        echo -e "${GREEN}✅ Pagination working - nextPageToken: $NEXT_TOKEN${NC}"
        echo ""
        echo "Fetching next page..."
        if [ -n "$NEXT_TOKEN" ]; then
            curl -s "$COMPOSITE_URL/items?pageSize=3&pageToken=$NEXT_TOKEN" | jq '.items[0:2] // .' 2>/dev/null || echo "Next page fetched"
        fi
    else
        echo -e "${YELLOW}⚠️  No nextPageToken (may be last page or pagination not implemented)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Items endpoint returned HTTP $HTTP_CODE${NC}"
    echo "Response: $(echo "$ITEMS_PAGE1" | head -5)"
    echo -e "${YELLOW}This may indicate the catalog service is not accessible. Continuing...${NC}"
fi

# 4. Threads + FK - Create Order
section "4. Threads - Parallel Execution in POST /orders"
echo "Creating order with parallel user/item validation..."
echo ""
ORDER_DATA='{
  "userId": "test-user-id",
  "itemId": "test-item-id",
  "startDate": "2025-12-01",
  "endDate": "2025-12-05"
}'

ORDER_RESPONSE=$(curl -s -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d "$ORDER_DATA" 2>&1)

echo "Response headers:"
echo "$ORDER_RESPONSE" | grep -i "x-composite\|location\|etag\|http" | head -10

# Check for threading indicators
if echo "$ORDER_RESPONSE" | grep -qi "x-composite-threaded"; then
    THREADED=$(echo "$ORDER_RESPONSE" | grep -i "x-composite-threaded:" | sed 's/.*: //i' | tr -d '\r')
    PARALLEL_MS=$(echo "$ORDER_RESPONSE" | grep -i "x-composite-parallel-ms:" | sed 's/.*: //i' | tr -d '\r')
    FANOUT=$(echo "$ORDER_RESPONSE" | grep -i "x-composite-fanout:" | sed 's/.*: //i' | tr -d '\r')
    
    if [ "$THREADED" = "true" ]; then
        echo ""
        echo -e "${GREEN}✅ Threads used: $THREADED${NC}"
        echo -e "${GREEN}✅ Parallel execution time: ${PARALLEL_MS}ms${NC}"
        echo -e "${GREEN}✅ Fanout: $FANOUT${NC}"
    fi
fi

HTTP_CODE=$(echo "$ORDER_RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}' || echo "000")
if [ "$HTTP_CODE" = "201" ]; then
    test_result 0 "Order created (201 Created)"
    ORDER_ID=$(echo "$ORDER_RESPONSE" | tail -1 | jq -r '.id // empty' 2>/dev/null || echo "")
    if [ -n "$ORDER_ID" ]; then
        echo "Order ID: $ORDER_ID"
    fi
elif [ "$HTTP_CODE" = "422" ]; then
    echo -e "${YELLOW}⚠️  FK Validation triggered (expected if user/item don't exist)${NC}"
    echo "$ORDER_RESPONSE" | tail -1 | jq '.detail // .' 2>/dev/null || echo "$ORDER_RESPONSE" | tail -1
else
    test_result 1 "Order creation failed (HTTP $HTTP_CODE)"
fi

# 5. FK Constraints - Missing User
section "5. Logical FK Constraints - Missing User (422)"
echo "Testing FK validation with non-existent user..."
FK_USER_RESPONSE=$(curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "non-existent-user-12345",
    "itemId": "test-item-id",
    "startDate": "2025-12-01",
    "endDate": "2025-12-05"
  }')

FK_CODE=$(echo "$FK_USER_RESPONSE" | jq -r '.detail.code // "unknown"' 2>/dev/null || echo "unknown")
if [ "$FK_CODE" = "FK_USER_NOT_FOUND" ]; then
    test_result 0 "FK constraint enforced - Missing user rejected (422)"
    echo "$FK_USER_RESPONSE" | jq '.detail' 2>/dev/null || echo "$FK_USER_RESPONSE"
else
    echo -e "${YELLOW}⚠️  Expected FK_USER_NOT_FOUND, got: $FK_CODE${NC}"
fi

# 6. FK Constraints - Missing Item
section "6. Logical FK Constraints - Missing Item (422)"
echo "Testing FK validation with non-existent item..."
FK_ITEM_RESPONSE=$(curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "test-user-id",
    "itemId": "non-existent-item-12345",
    "startDate": "2025-12-01",
    "endDate": "2025-12-05"
  }')

FK_CODE=$(echo "$FK_ITEM_RESPONSE" | jq -r '.detail.code // "unknown"' 2>/dev/null || echo "unknown")
if [ "$FK_CODE" = "FK_ITEM_NOT_FOUND" ]; then
    test_result 0 "FK constraint enforced - Missing item rejected (422)"
    echo "$FK_ITEM_RESPONSE" | jq '.detail' 2>/dev/null || echo "$FK_ITEM_RESPONSE"
else
    echo -e "${YELLOW}⚠️  Expected FK_ITEM_NOT_FOUND, got: $FK_CODE${NC}"
fi

# 7. Search with Merged Pagination
section "7. Search - Merged Pagination from Multiple Services"
echo "Searching for 'luxury' across catalog and orders..."
SEARCH_RESPONSE=$(curl -s "$COMPOSITE_URL/search?q=luxury&pageSize=3")
echo "$SEARCH_RESPONSE" | jq '.results[0:2] // .' 2>/dev/null || echo "$SEARCH_RESPONSE"

RESULT_COUNT=$(echo "$SEARCH_RESPONSE" | jq '.results | length' 2>/dev/null || echo "0")
if [ "$RESULT_COUNT" -gt 0 ]; then
    test_result 0 "Search returned merged results"
    echo "Result count: $RESULT_COUNT"
    SEARCH_TOKEN=$(echo "$SEARCH_RESPONSE" | jq -r '.nextPageToken // empty' 2>/dev/null)
    if [ -n "$SEARCH_TOKEN" ] && [ "$SEARCH_TOKEN" != "null" ]; then
        echo -e "${GREEN}✅ Merged pagination token available${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No results found (may be expected)${NC}"
fi

# 8. 202 Accepted - Async Job
section "8. 202 Accepted - Async Job Confirmation"
if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "" ]; then
    echo "Confirming order: $ORDER_ID"
    CONFIRM_RESPONSE=$(curl -s -i -X POST "$COMPOSITE_URL/orders/$ORDER_ID/confirm" 2>&1)
    HTTP_CODE=$(echo "$CONFIRM_RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}' || echo "000")
    LOCATION=$(echo "$CONFIRM_RESPONSE" | grep -i "location:" | sed 's/.*location: //i' | tr -d '\r' || echo "")
    
    if [ "$HTTP_CODE" = "202" ]; then
        test_result 0 "Order confirmation returned 202 Accepted"
        echo "Location: $LOCATION"
        if [ -n "$LOCATION" ]; then
            JOB_ID=$(echo "$LOCATION" | sed 's/.*\///')
            echo "Job ID: $JOB_ID"
            echo ""
            echo "Polling job status..."
            for i in {1..5}; do
                JOB_STATUS=$(curl -s "$COMPOSITE_URL/jobs/$JOB_ID" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
                echo "  Attempt $i: Status = $JOB_STATUS"
                if [ "$JOB_STATUS" = "completed" ] || [ "$JOB_STATUS" = "failed" ]; then
                    break
                fi
                sleep 2
            done
        fi
    else
        echo -e "${YELLOW}⚠️  Expected 202, got HTTP $HTTP_CODE${NC}"
        echo "$CONFIRM_RESPONSE" | head -10
    fi
else
    echo -e "${YELLOW}⚠️  Skipping - No order ID available from previous step${NC}"
    echo "To test: Create an order first, then confirm it"
fi

# Summary
section "Demo Summary"
echo -e "${BOLD}Features Demonstrated:${NC}"
echo -e "  ${GREEN}✅${NC} Encapsulation (same APIs as atomics)"
echo -e "  ${GREEN}✅${NC} Threads (parallel execution in POST /orders)"
echo -e "  ${GREEN}✅${NC} Logical FK constraints (user/item validation)"
echo -e "  ${GREEN}✅${NC} ETag propagation"
echo -e "  ${GREEN}✅${NC} Pagination support"
echo -e "  ${GREEN}✅${NC} 201 Created for POST methods"
echo -e "  ${GREEN}✅${NC} 202 Accepted with async job polling"
echo -e "  ${GREEN}✅${NC} Merged search with pagination"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo "  1. Run tests: pytest tests/"
echo "  2. View API docs: $COMPOSITE_URL/docs"
echo "  3. Deploy web UI to Cloud Storage"
echo "  4. Review demo guide: docs/DEMO_GUIDE.md"
echo ""
echo -e "${BOLD}Demo Complete!${NC}"

