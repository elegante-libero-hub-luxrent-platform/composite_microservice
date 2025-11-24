# Curl Commands for Testing Order & Rental Service

## Quick Reference

### Direct Order Service (snake_case, integer IDs)

**Base URL:** `https://order-and-rental-service-314897419193.europe-west1.run.app`

#### 1. Health Check
```bash
curl -i https://order-and-rental-service-314897419193.europe-west1.run.app/
```

#### 2. List All Orders
```bash
curl https://order-and-rental-service-314897419193.europe-west1.run.app/orders
```

#### 3. List Orders by Status
```bash
curl "https://order-and-rental-service-314897419193.europe-west1.run.app/orders?state=pending"
```

#### 4. Create Order (Direct - snake_case)
```bash
curl -i -X POST https://order-and-rental-service-314897419193.europe-west1.run.app/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": 12,
    "item_id": 505,
    "start_date": "2025-05-01",
    "end_date": "2025-05-07"
  }'
```

#### 5. Get Order Details
```bash
curl https://order-and-rental-service-314897419193.europe-west1.run.app/orders/{order_id}
```

#### 6. Get Order Logs
```bash
curl https://order-and-rental-service-314897419193.europe-west1.run.app/orders/{order_id}/logs
```

#### 7. Confirm Order (202 Accepted)
```bash
curl -i -X POST https://order-and-rental-service-314897419193.europe-west1.run.app/orders/{order_id}/confirm
```

#### 8. Get Job Status
```bash
curl https://order-and-rental-service-314897419193.europe-west1.run.app/jobs/{job_id}
```

---

### Composite Service (camelCase, string IDs)

**Base URL:** `http://localhost:8080` (or your deployed composite service)

#### 1. Create Order (Composite - camelCase)
```bash
curl -i -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "12",
    "itemId": "505",
    "startDate": "2025-05-01",
    "endDate": "2025-05-07"
  }'
```

**Note:** The composite service:
- Uses camelCase field names (userId, itemId, startDate, endDate)
- Validates user and item existence (FK checks)
- Checks item availability
- Returns headers: `X-Composite-Parallel-Ms`, `X-Composite-Fanout`, `X-Composite-Threaded`
- Returns combined ETag

#### 2. Get Order Details
```bash
curl http://localhost:8080/orders/{order_id}
```

#### 3. Confirm Order (202 Accepted)
```bash
curl -i -X POST http://localhost:8080/orders/{order_id}/confirm
```

#### 4. Get Job Status
```bash
curl http://localhost:8080/jobs/{job_id}
```

---

## Complete Test Script

Run the automated test script:

```bash
./scripts/test_orders.sh
```

Or test specific services:

```bash
# Test composite service
./scripts/test_orders.sh http://localhost:8080

# Test direct order service
./scripts/test_orders.sh http://localhost:8080 https://order-and-rental-service-314897419193.europe-west1.run.app
```

---

## Key Differences

| Feature | Direct Order Service | Composite Service |
|---------|---------------------|-------------------|
| Field Names | snake_case (user_id, item_id) | camelCase (userId, itemId) |
| ID Types | Integers | Strings |
| FK Validation | None | Validates user/item exist |
| Availability Check | None | Checks item availability |
| Parallel Execution | No | Yes (threaded) |
| Headers | Standard | Adds X-Composite-* headers |
| ETag | Single | Combined ETag |

---

## Example Workflow

### 1. Create an order via composite service
```bash
RESPONSE=$(curl -sS -i -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "12",
    "itemId": "505",
    "startDate": "2025-05-01",
    "endDate": "2025-05-07"
  }')

# Extract order ID from Location header
ORDER_ID=$(echo "$RESPONSE" | grep -i "location:" | sed 's/.*\/orders\///' | tr -d '\r')
echo "Order ID: $ORDER_ID"
```

### 2. Get order details
```bash
curl http://localhost:8080/orders/$ORDER_ID | jq .
```

### 3. Confirm order (async job)
```bash
CONFIRM_RESPONSE=$(curl -sS -i -X POST http://localhost:8080/orders/$ORDER_ID/confirm)

# Extract job ID from Location header
JOB_ID=$(echo "$CONFIRM_RESPONSE" | grep -i "location:" | sed 's/.*\/jobs\///' | tr -d '\r')
echo "Job ID: $JOB_ID"
```

### 4. Poll job status
```bash
curl http://localhost:8080/jobs/$JOB_ID | jq .
```

---

## Error Scenarios

### Missing User (422)
```bash
curl -i -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "missing-user",
    "itemId": "505",
    "startDate": "2025-05-01",
    "endDate": "2025-05-07"
  }'
```

### Missing Item (422)
```bash
curl -i -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "12",
    "itemId": "missing-item",
    "startDate": "2025-05-01",
    "endDate": "2025-05-07"
  }'
```

### Unavailable Item (409)
```bash
curl -i -X POST http://localhost:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "12",
    "itemId": "505",
    "startDate": "2025-01-01",
    "endDate": "2025-12-31"
  }'
```

