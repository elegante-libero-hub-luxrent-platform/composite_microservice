#!/bin/bash
# Quick test script using valid IDs from existing orders
# Based on existing orders, valid IDs are:
# - Users: 1, 2, 3, 12
# - Items: 1, 5, 10, 15, 77, 99, 200, 505

set -e

COMPOSITE_BASE=${1:-http://localhost:8080}

echo "=== Testing with Valid IDs ==="
echo "Composite Service: $COMPOSITE_BASE"
echo ""
echo "Valid IDs from existing orders:"
echo "  Users: 1, 2, 3, 12"
echo "  Items: 1, 5, 10, 15, 77, 99, 200, 505"
echo ""

# Test 1: Create order with user 1 and item 1
echo "Test 1: Create order (user=1, item=1)"
RESPONSE=$(curl -sS -i -X POST "$COMPOSITE_BASE/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "1",
    "itemId": "1",
    "startDate": "2025-06-01",
    "endDate": "2025-06-07"
  }')

echo "$RESPONSE" | head -15
ORDER_ID=$(echo "$RESPONSE" | grep -i "location:" | sed 's/.*\/orders\///' | tr -d '\r' || echo "")

if [ -n "$ORDER_ID" ]; then
  echo ""
  echo "✅ Order created: $ORDER_ID"
  echo ""
  echo "Order details:"
  curl -sS "$COMPOSITE_BASE/orders/$ORDER_ID" | jq . || curl -sS "$COMPOSITE_BASE/orders/$ORDER_ID"
else
  echo ""
  echo "❌ Failed to create order"
  echo "Full response:"
  echo "$RESPONSE"
fi

echo ""
echo "---"
echo ""

# Test 2: Try with different valid IDs
echo "Test 2: Create order (user=2, item=5)"
RESPONSE2=$(curl -sS -i -X POST "$COMPOSITE_BASE/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "2",
    "itemId": "5",
    "startDate": "2025-07-01",
    "endDate": "2025-07-05"
  }')

echo "$RESPONSE2" | head -15

echo ""
echo "=== Test Complete ==="

