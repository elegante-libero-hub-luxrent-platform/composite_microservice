# Composite Microservice Demo Guide

This guide demonstrates all required features of the Composite Microservice for the Luxury Rental Platform.

## Prerequisites

- Composite service deployed and accessible
- Three atomic microservices running:
  - User & Profile Service (Cloud Run) - `user-and-profile-service`
  - Catalog & Inventory Service (Cloud Run) - `catalog-and-inventory-service`
  - Order & Rental Service (Cloud Run) - `order-and-rental-service`
- Web UI deployed on Cloud Storage

## Demo Base URL

```bash
COMPOSITE_URL="https://your-composite-service.run.app"
# Or for local testing:
COMPOSITE_URL="http://localhost:8080"
```

---

## 1. Encapsulation - Exposing Same APIs as Atomics

The composite service exposes the same endpoints as atomic services but adds composite-specific behavior.

### 1.1 Health Check
```bash
curl -s "$COMPOSITE_URL/healthz" | jq .
```

### 1.2 Get User (with ETag)
```bash
curl -s -i "$COMPOSITE_URL/users/{user_id}" | grep -i "etag\|http"
```

### 1.3 List Items (with Pagination)
```bash
curl -s "$COMPOSITE_URL/items?pageSize=5" | jq .
```

### 1.4 Get Item
```bash
curl -s "$COMPOSITE_URL/items/{item_id}" | jq .
```

### 1.5 Get Order
```bash
curl -s "$COMPOSITE_URL/orders/{order_id}" | jq .
```

---

## 2. Threads - Parallel Execution in POST /orders

The `POST /orders` endpoint uses threads to fetch user and item details in parallel, demonstrating parallelism.

### 2.1 Create Order (Shows Parallel Execution)

```bash
curl -s -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "valid-user-id",
    "itemId": "valid-item-id",
    "startDate": "2025-12-01",
    "endDate": "2025-12-05"
  }' | grep -i "x-composite\|location\|etag\|http"
```

**Look for these headers:**
- `X-Composite-Threaded: true` - Confirms threads were used
- `X-Composite-Parallel-Ms: <number>` - Time taken for parallel fan-out
- `X-Composite-Fanout: user,item,availability,order` - Shows what was checked in parallel
- `Location: /orders/{order_id}` - 201 Created response
- `ETag: "..."` - Combined ETag from all services

### 2.2 Timing Comparison

To demonstrate parallelism, compare sequential vs parallel timing:

```bash
# Parallel (threaded) - should be faster
time curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}'
```

The `X-Composite-Parallel-Ms` header shows the parallel fan-out time (user + item fetched simultaneously).

---

## 3. Logical Foreign Key Constraints

The composite service enforces logical FKs by verifying referenced entities exist before creating orders.

### 3.1 FK Validation - Missing User (422)

```bash
curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "non-existent-user",
    "itemId": "valid-item-id",
    "startDate": "2025-12-01",
    "endDate": "2025-12-05"
  }' | jq .
```

**Expected Response:**
```json
{
  "detail": {
    "code": "FK_USER_NOT_FOUND",
    "message": "Referenced user does not exist"
  }
}
```
**Status:** 422 Unprocessable Entity

### 3.2 FK Validation - Missing Item (422)

```bash
curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "valid-user-id",
    "itemId": "non-existent-item",
    "startDate": "2025-12-01",
    "endDate": "2025-12-05"
  }' | jq .
```

**Expected Response:**
```json
{
  "detail": {
    "code": "FK_ITEM_NOT_FOUND",
    "message": "Referenced item does not exist"
  }
}
```
**Status:** 422 Unprocessable Entity

### 3.3 FK Validation - Unavailable Item (409)

```bash
curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{
    "userId": "valid-user-id",
    "itemId": "valid-item-id",
    "startDate": "2025-12-01",
    "endDate": "2025-12-05"
  }' | jq .
```

If item is unavailable for the date range:
**Expected Response:**
```json
{
  "detail": {
    "code": "ITEM_UNAVAILABLE",
    "message": "Item is not available for the requested window"
  }
}
```
**Status:** 409 Conflict

### 3.4 Successful FK Validation (201)

When both user and item exist and item is available:
**Status:** 201 Created
**Headers:** `Location: /orders/{order_id}`

---

## 4. ETag Propagation

The composite service propagates ETags from atomic services and combines them for aggregated responses.

### 4.1 ETag from User Service

```bash
# First request
RESPONSE1=$(curl -s -i "$COMPOSITE_URL/users/{user_id}")
ETAG1=$(echo "$RESPONSE1" | grep -i "etag:" | sed 's/.*etag: //i' | tr -d '\r')

# Second request with If-None-Match
curl -s -i -H "If-None-Match: $ETAG1" "$COMPOSITE_URL/users/{user_id}"
```

**Expected:** 304 Not Modified (if data unchanged)

### 4.2 Combined ETag in POST /orders

The `POST /orders` response includes a combined ETag from user, item, and order services:

```bash
curl -s -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}' \
  | grep -i "etag"
```

---

## 5. Pagination

The composite service supports pagination with `pageSize` and `pageToken` parameters.

### 5.1 List Items with Pagination

```bash
# First page
curl -s "$COMPOSITE_URL/items?pageSize=3" | jq .

# Get nextPageToken from response, then:
curl -s "$COMPOSITE_URL/items?pageSize=3&pageToken=<token>" | jq .
```

### 5.2 Merged Pagination in Search

The `/search` endpoint merges pagination from multiple services:

```bash
# First page
curl -s "$COMPOSITE_URL/search?q=luxury&pageSize=5" | jq .

# Next page (merged token)
curl -s "$COMPOSITE_URL/search?q=luxury&pageSize=5&pageToken=<merged_token>" | jq .
```

**Response includes:**
- `results`: Merged array from catalog and orders
- `nextPageToken`: Opaque token containing per-source cursors
- `pageSize`: Current page size

---

## 6. 201 Created for POST Methods

All POST endpoints return 201 Created with a `Location` header.

### 6.1 Create Order (201)

```bash
curl -s -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}' \
  | grep -i "http\|location"
```

**Expected:**
- Status: `201 Created`
- Header: `Location: /orders/{order_id}`

---

## 7. 202 Accepted with Async Job Polling

The `/orders/{id}/confirm` endpoint returns 202 Accepted with a job polling location.

### 7.1 Confirm Order (202 Accepted)

```bash
# Confirm an order
RESPONSE=$(curl -s -i -X POST "$COMPOSITE_URL/orders/{order_id}/confirm")
echo "$RESPONSE" | grep -i "http\|location"

# Extract Location header
JOB_LOCATION=$(echo "$RESPONSE" | grep -i "location:" | sed 's/.*location: //i' | tr -d '\r')
```

**Expected:**
- Status: `202 Accepted`
- Header: `Location: /jobs/{job_id}`

### 7.2 Poll Job Status

```bash
# Poll the job status
curl -s "$COMPOSITE_URL/jobs/{job_id}" | jq .
```

**Job states:**
- `pending` - Job is queued
- `processing` - Job is being processed
- `completed` - Job finished successfully
- `failed` - Job failed

### 7.3 Complete Async Flow Example

```bash
# 1. Create order
ORDER_RESPONSE=$(curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}')
ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.id')

# 2. Confirm order (returns 202)
CONFIRM_RESPONSE=$(curl -s -i -X POST "$COMPOSITE_URL/orders/$ORDER_ID/confirm")
JOB_ID=$(echo "$CONFIRM_RESPONSE" | grep -i "location:" | sed 's/.*\/jobs\///i' | tr -d '\r')

# 3. Poll job status
while true; do
  JOB_STATUS=$(curl -s "$COMPOSITE_URL/jobs/$JOB_ID" | jq -r '.status')
  echo "Job status: $JOB_STATUS"
  if [ "$JOB_STATUS" = "completed" ] || [ "$JOB_STATUS" = "failed" ]; then
    break
  fi
  sleep 2
done
```

---

## 8. Search with Merged Results

The `/search` endpoint aggregates results from catalog and orders services.

### 8.1 Basic Search

```bash
curl -s "$COMPOSITE_URL/search?q=luxury" | jq .
```

**Response:**
```json
{
  "results": [
    {"source": "catalog", "id": "...", "name": "..."},
    {"source": "order", "id": "...", "status": "..."}
  ],
  "nextPageToken": "...",
  "pageSize": 10
}
```

### 8.2 Search with Pagination

```bash
# First page
curl -s "$COMPOSITE_URL/search?q=luxury&pageSize=3" | jq .

# Next page
curl -s "$COMPOSITE_URL/search?q=luxury&pageSize=3&pageToken=<token>" | jq .
```

---

## 9. Complete Demo Flow

Here's a complete end-to-end demo:

```bash
#!/bin/bash
COMPOSITE_URL="${COMPOSITE_URL:-http://localhost:8080}"

echo "=== 1. Health Check ==="
curl -s "$COMPOSITE_URL/healthz" | jq .

echo -e "\n=== 2. Get User (ETag) ==="
curl -s -i "$COMPOSITE_URL/users/{user_id}" | head -10

echo -e "\n=== 3. List Items (Pagination) ==="
curl -s "$COMPOSITE_URL/items?pageSize=3" | jq '.items[0:2]'

echo -e "\n=== 4. Create Order (Threads + FK) ==="
ORDER_RESPONSE=$(curl -s -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}')
echo "$ORDER_RESPONSE" | grep -i "x-composite\|location\|http"

echo -e "\n=== 5. FK Failure - Missing User ==="
curl -s -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"invalid","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}' \
  | jq '.detail.code'

echo -e "\n=== 6. Search (Merged Pagination) ==="
curl -s "$COMPOSITE_URL/search?q=luxury&pageSize=2" | jq '.results[0:2]'

echo -e "\n=== 7. Confirm Order (202 Accepted) ==="
curl -s -i -X POST "$COMPOSITE_URL/orders/{order_id}/confirm" | head -5

echo -e "\n=== Demo Complete ==="
```

---

## 10. Testing Parallelism

To demonstrate threads are working, run the test suite:

```bash
pytest tests/test_threads.py -v
```

This test:
- Mocks user and item endpoints with delays
- Verifies parallel execution (should be faster than sequential)
- Checks `X-Composite-Parallel-Ms` header
- Confirms `X-Composite-Threaded: true` header

---

## 11. Testing FK Constraints

Run FK validation tests:

```bash
pytest tests/test_fk.py -v
```

Tests cover:
- Missing user → 422 FK_USER_NOT_FOUND
- Missing item → 422 FK_ITEM_NOT_FOUND
- Unavailable item → 409 ITEM_UNAVAILABLE

---

## 12. Web UI Demo

Access the web UI deployed on Cloud Storage:

1. Open the Cloud Storage URL in a browser
2. Use the UI to:
   - Browse items (pagination)
   - View user profiles (ETag caching)
   - Create orders (shows parallel execution timing)
   - Search across services (merged results)
   - Confirm orders (async job polling)

---

## Demo Checklist

- [ ] Health check works
- [ ] User endpoint returns ETag
- [ ] Items endpoint supports pagination
- [ ] POST /orders uses threads (check headers)
- [ ] FK validation rejects missing user (422)
- [ ] FK validation rejects missing item (422)
- [ ] FK validation rejects unavailable item (409)
- [ ] POST /orders returns 201 with Location
- [ ] POST /orders/{id}/confirm returns 202 with job Location
- [ ] GET /jobs/{id} shows job status
- [ ] /search merges results from multiple services
- [ ] /search supports pagination with merged tokens
- [ ] Tests show parallelism timing
- [ ] Tests show FK failure paths
- [ ] Web UI accessible and functional

---

## Troubleshooting

### Service Not Responding
- Check service is deployed and running
- Verify environment variables are set correctly
- Check service logs: `gcloud run services logs read <service-name>`

### FK Validation Failing
- Ensure atomic services are running
- Verify user/item IDs exist in respective services
- Check service URLs in configuration

### Threads Not Working
- Check `X-Composite-Threaded` header is present
- Verify `X-Composite-Parallel-Ms` shows reasonable timing
- Run `pytest tests/test_threads.py` to verify

### Pagination Issues
- Verify `nextPageToken` is being returned
- Check token format matches expected structure
- Ensure atomic services support pagination

---

## Additional Resources

- API Documentation: `$COMPOSITE_URL/docs` (Swagger UI)
- OpenAPI Spec: `openapi/composite.yaml`
- Test Suite: `pytest`
- Smoke Tests: `scripts/smoke.sh`

