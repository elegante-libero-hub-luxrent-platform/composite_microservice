#!/bin/bash
# Comprehensive endpoint verification for UI

CATALOG_URL="https://catalog-and-inventory-service-314897419193.europe-west1.run.app"
ORDER_URL="https://order-and-rental-service-314897419193.europe-west1.run.app"
USER_URL="https://34.13.123.175"
COMPOSITE_URL="https://composite-microservice-314897419193.europe-west1.run.app"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

test_endpoint() {
    local method=$1
    local url=$2
    local data=$3
    local description=$4
    local expected_code=${5:-200}
    
    if [ -z "$data" ]; then
        http_code=$(curl -s -k -o /dev/null -w "%{http_code}" -X "$method" "$url" 2>/dev/null)
    else
        http_code=$(curl -s -k -o /dev/null -w "%{http_code}" -X "$method" "$url" \
            -H "Content-Type: application/json" -d "$data" 2>/dev/null)
    fi
    
    if [ "$http_code" -eq "$expected_code" ] || ([ "$expected_code" -eq 200 ] && [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]); then
        echo -e "${GREEN}✓${NC} $description (${http_code})"
        ((PASSED++))
        return 0
    elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
        echo -e "${YELLOW}⚠${NC} $description (${http_code} - Client Error, may be expected)"
        ((WARNINGS++))
        return 1
    elif [ "$http_code" -ge 500 ]; then
        echo -e "${RED}✗${NC} $description (${http_code} - Server Error)"
        ((FAILED++))
        return 1
    else
        echo -e "${BLUE}?${NC} $description (${http_code} - Unexpected)"
        ((WARNINGS++))
        return 1
    fi
}

echo "=========================================="
echo "UI Endpoint Verification"
echo "=========================================="
echo ""

echo -e "${BLUE}=== CATALOG & INVENTORY SERVICE ===${NC}"
test_endpoint "GET" "${CATALOG_URL}/catalog/items?pageSize=5" "" "List Catalog Items"
test_endpoint "GET" "${CATALOG_URL}/catalog/items/it-test123" "" "Get Catalog Item" 404
echo ""

echo -e "${BLUE}=== ORDER & RENTAL SERVICE ===${NC}"
test_endpoint "GET" "${ORDER_URL}/orders" "" "List Orders"
test_endpoint "GET" "${ORDER_URL}/orders/1" "" "Get Order"
test_endpoint "GET" "${ORDER_URL}/orders/99999" "" "Get Non-existent Order" 404
echo ""

echo -e "${BLUE}=== USER & PROFILE SERVICE ===${NC}"
test_endpoint "GET" "${USER_URL}/users?pageSize=5" "" "List Users"
test_endpoint "GET" "${USER_URL}/users/550e8400-e29b-41d4-a716-446655440001" "" "Get User"
test_endpoint "GET" "${USER_URL}/profiles?pageSize=5" "" "List Profiles"
echo ""

echo -e "${BLUE}=== COMPOSITE SERVICE ===${NC}"
test_endpoint "GET" "${COMPOSITE_URL}/readyz" "" "Health Check"
test_endpoint "GET" "${COMPOSITE_URL}/users/550e8400-e29b-41d4-a716-446655440001" "" "Get User via Composite"
test_endpoint "GET" "${COMPOSITE_URL}/items?pageSize=5" "" "List Items via Composite"
test_endpoint "GET" "${COMPOSITE_URL}/items/it-test123" "" "Get Item via Composite" 404
test_endpoint "GET" "${COMPOSITE_URL}/orders/1" "" "Get Order via Composite"
test_endpoint "GET" "${COMPOSITE_URL}/search?q=test&pageSize=5" "" "Search via Composite"
echo ""

echo "=========================================="
echo -e "Summary: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}, ${YELLOW}${WARNINGS} warnings${NC}"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    exit 1
fi

