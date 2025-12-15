#!/bin/bash
# Test all endpoints from the UI to verify they work as expected

set -e

CATALOG_URL="https://catalog-and-inventory-service-314897419193.europe-west1.run.app"
ORDER_URL="https://order-and-rental-service-314897419193.europe-west1.run.app"
USER_URL="https://34.13.123.175"
COMPOSITE_URL="https://composite-microservice-314897419193.europe-west1.run.app"

echo "=========================================="
echo "Testing All UI Endpoints"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_endpoint() {
    local method=$1
    local url=$2
    local data=$3
    local description=$4
    
    echo -n "Testing: $description ... "
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -d "$data" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "${GREEN}✓ OK (${http_code})${NC}"
        return 0
    elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
        echo -e "${YELLOW}⚠ Client Error (${http_code})${NC}"
        return 1
    elif [ "$http_code" -ge 500 ]; then
        echo -e "${RED}✗ Server Error (${http_code})${NC}"
        return 1
    else
        echo -e "${YELLOW}? Unexpected (${http_code})${NC}"
        return 1
    fi
}

echo "=== CATALOG & INVENTORY SERVICE ==="
test_endpoint "GET" "${CATALOG_URL}/catalog/items?pageSize=5" "" "List Catalog Items"
test_endpoint "GET" "${CATALOG_URL}/catalog/items/it-test123" "" "Get Catalog Item (may 404)"
echo ""

echo "=== ORDER & RENTAL SERVICE ==="
test_endpoint "GET" "${ORDER_URL}/orders" "" "List Orders"
test_endpoint "GET" "${ORDER_URL}/orders/1" "" "Get Order (may 404)"
echo ""

echo "=== USER & PROFILE SERVICE ==="
test_endpoint "GET" "${USER_URL}/users?pageSize=5" "" "List Users"
test_endpoint "GET" "${USER_URL}/users/550e8400-e29b-41d4-a716-446655440001" "" "Get User (may 404)"
test_endpoint "GET" "${USER_URL}/profiles?pageSize=5" "" "List Profiles"
echo ""

echo "=== COMPOSITE SERVICE ==="
test_endpoint "GET" "${COMPOSITE_URL}/readyz" "" "Health Check"
test_endpoint "GET" "${COMPOSITE_URL}/users/550e8400-e29b-41d4-a716-446655440001" "" "Get User via Composite"
test_endpoint "GET" "${COMPOSITE_URL}/items?pageSize=5" "" "List Items via Composite"
test_endpoint "GET" "${COMPOSITE_URL}/search?q=test&pageSize=5" "" "Search via Composite"
echo ""

echo "=========================================="
echo "Testing Complete!"
echo "=========================================="

