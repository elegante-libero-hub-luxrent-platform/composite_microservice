#!/usr/bin/env bash
# Test script for Order & Rental Service endpoints
# Usage: ./scripts/test_orders.sh [BASE_URL]
# Default: http://localhost:8080 (composite service)
# Or use: https://order-and-rental-service-314897419193.europe-west1.run.app (direct)

set -e

BASE=${1:-http://localhost:8080}
COMPOSITE_BASE=${1:-http://localhost:8080}
ORDER_BASE=${2:-https://order-and-rental-service-314897419193.europe-west1.run.app}

echo "=== Testing Order & Rental Service ==="
echo "Composite Service: $COMPOSITE_BASE"
echo "Order Service (direct): $ORDER_BASE"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. Health Check (Order Service)${NC}"
curl -sS -i "$ORDER_BASE/" | head -10
echo ""

echo -e "${BLUE}2. List All Orders (Order Service)${NC}"
curl -sS "$ORDER_BASE/orders" | jq . || echo "Response: $(curl -sS $ORDER_BASE/orders)"
echo ""

echo -e "${BLUE}3. List Orders by Status (Order Service)${NC}"
curl -sS "$ORDER_BASE/orders?state=pending" | jq . || echo "Response: $(curl -sS $ORDER_BASE/orders?state=pending)"
echo ""

echo -e "${BLUE}4. Create Order via Composite Service${NC}"
echo "Note: Composite service uses camelCase (userId, itemId, startDate, endDate)"
echo "Using item ID 1 and user ID 1 (from existing orders)"
ORDER_RESPONSE=$(curl -sS -i -X POST "$COMPOSITE_BASE/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "1",
    "itemId": "1",
    "startDate": "2025-06-01",
    "endDate": "2025-06-07"
  }')
echo "$ORDER_RESPONSE"
ORDER_ID=$(echo "$ORDER_RESPONSE" | grep -i "location:" | sed 's/.*\/orders\///' | tr -d '\r' || echo "")
echo ""
if [ -n "$ORDER_ID" ]; then
  echo -e "${GREEN}Created Order ID: $ORDER_ID${NC}"
  echo ""
  
  echo -e "${BLUE}5. Get Order Details (Composite Service)${NC}"
  curl -sS "$COMPOSITE_BASE/orders/$ORDER_ID" | jq . || echo "Response: $(curl -sS $COMPOSITE_BASE/orders/$ORDER_ID)"
  echo ""
  
  echo -e "${BLUE}6. Get Order Details (Order Service - direct)${NC}"
  curl -sS "$ORDER_BASE/orders/$ORDER_ID" | jq . || echo "Response: $(curl -sS $ORDER_BASE/orders/$ORDER_ID)"
  echo ""
  
  echo -e "${BLUE}7. Get Order Logs (Order Service)${NC}"
  curl -sS "$ORDER_BASE/orders/$ORDER_ID/logs" | jq . || echo "Response: $(curl -sS $ORDER_BASE/orders/$ORDER_ID/logs)"
  echo ""
  
  echo -e "${BLUE}8. Confirm Order (202 Accepted - Composite Service)${NC}"
  CONFIRM_RESPONSE=$(curl -sS -i -X POST "$COMPOSITE_BASE/orders/$ORDER_ID/confirm")
  echo "$CONFIRM_RESPONSE"
  JOB_ID=$(echo "$CONFIRM_RESPONSE" | grep -i "location:" | sed 's/.*\/jobs\///' | tr -d '\r' || echo "")
  echo ""
  
  if [ -n "$JOB_ID" ]; then
    echo -e "${GREEN}Job ID: $JOB_ID${NC}"
    echo ""
    
    echo -e "${BLUE}9. Get Job Status (Composite Service)${NC}"
    curl -sS "$COMPOSITE_BASE/jobs/$JOB_ID" | jq . || echo "Response: $(curl -sS $COMPOSITE_BASE/jobs/$JOB_ID)"
    echo ""
    
    echo -e "${BLUE}10. Get Job Status (Order Service - direct)${NC}"
    curl -sS "$ORDER_BASE/jobs/$JOB_ID" | jq . || echo "Response: $(curl -sS $ORDER_BASE/jobs/$JOB_ID)"
    echo ""
  fi
fi

echo -e "${BLUE}11. Create Order Directly (Order Service - snake_case)${NC}"
echo "Note: Order service uses snake_case (user_id, item_id, start_date, end_date) and integer IDs"
echo "Using item ID 1 and user ID 1 (from existing orders)"
curl -sS -i -X POST "$ORDER_BASE/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": 1,
    "item_id": 1,
    "start_date": "2025-06-01",
    "end_date": "2025-06-07"
  }' | head -20
echo ""

echo -e "${YELLOW}=== Test Complete ===${NC}"

