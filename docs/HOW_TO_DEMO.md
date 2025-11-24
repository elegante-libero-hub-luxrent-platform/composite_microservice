# How to Demo the Composite Service

This guide provides step-by-step instructions for demonstrating all required features of the Composite Microservice.

## Quick Start

1. **Run the demo script:**
   ```bash
   ./scripts/demo.sh
   ```

2. **Or use the interactive web UI:**
   - Deploy to Cloud Storage: `./scripts/deploy_ui_to_gcs.sh`
   - Open the public URL in your browser
   - Configure the composite service URL
   - Test all features interactively

3. **Or follow the detailed demo guide:**
   - See `docs/DEMO_GUIDE.md` for comprehensive examples

---

## Demo Checklist

Use this checklist to ensure all requirements are demonstrated:

### ✅ Encapsulation
- [ ] Health check endpoint works
- [ ] User endpoint mirrors atomic service API
- [ ] Items endpoint mirrors atomic service API
- [ ] Orders endpoint mirrors atomic service API
- [ ] All endpoints delegate to atomic services

### ✅ Threads
- [ ] POST /orders uses threads (check `X-Composite-Threaded: true` header)
- [ ] Parallel execution timing shown (`X-Composite-Parallel-Ms` header)
- [ ] User and item fetched in parallel (faster than sequential)
- [ ] Test shows parallelism: `pytest tests/test_threads.py`

### ✅ Logical Foreign Keys
- [ ] Missing user → 422 FK_USER_NOT_FOUND
- [ ] Missing item → 422 FK_ITEM_NOT_FOUND
- [ ] Unavailable item → 409 ITEM_UNAVAILABLE
- [ ] FK validation happens before order creation
- [ ] Test shows FK failures: `pytest tests/test_fk.py`

### ✅ ETag Propagation
- [ ] User endpoint returns ETag header
- [ ] Item endpoint returns ETag header
- [ ] Order endpoint returns ETag header
- [ ] If-None-Match returns 304 when unchanged
- [ ] Combined ETag in POST /orders response
- [ ] Test shows ETag handling: `pytest tests/test_etag.py`

### ✅ Pagination
- [ ] Items endpoint supports pageSize parameter
- [ ] Items endpoint supports pageToken parameter
- [ ] Search endpoint merges pagination from multiple services
- [ ] nextPageToken works correctly
- [ ] Test shows pagination: `pytest tests/test_pagination.py`

### ✅ 201 Created
- [ ] POST /orders returns 201 Created
- [ ] Location header points to created resource
- [ ] Response body contains created order

### ✅ 202 Accepted with Async Jobs
- [ ] POST /orders/{id}/confirm returns 202 Accepted
- [ ] Location header points to job endpoint
- [ ] GET /jobs/{id} shows job status
- [ ] Job status transitions: pending → processing → completed/failed
- [ ] Test shows async flow: `pytest tests/test_jobs_202.py`

### ✅ Search with Merged Results
- [ ] /search aggregates results from catalog and orders
- [ ] Results include source indicator
- [ ] Pagination works with merged tokens
- [ ] ETag combines from multiple sources

### ✅ Web UI
- [ ] Web UI deployed to Cloud Storage
- [ ] UI accessible via public URL
- [ ] UI can interact with composite service
- [ ] UI demonstrates all features

---

## Demo Flow (Recommended Order)

### 1. Setup (2 minutes)
- Verify all services are running
- Set COMPOSITE_URL environment variable
- Open web UI or prepare terminal

### 2. Health & Encapsulation (1 minute)
- Show health check
- Show user/item/order endpoints work
- Explain encapsulation concept

### 3. Threads Demonstration (2 minutes)
- Create an order
- Show `X-Composite-Threaded: true` header
- Show `X-Composite-Parallel-Ms` timing
- Explain parallel user/item fetch

### 4. FK Constraints (2 minutes)
- Try creating order with invalid user → 422
- Try creating order with invalid item → 422
- Try creating order with unavailable item → 409
- Show successful order creation

### 5. ETag & Caching (1 minute)
- Get user, show ETag
- Request same user with If-None-Match → 304
- Show combined ETag in order response

### 6. Pagination (1 minute)
- List items with pageSize=3
- Show nextPageToken
- Fetch next page
- Show search with merged pagination

### 7. Async Jobs (2 minutes)
- Confirm an order → 202 Accepted
- Show job Location header
- Poll job status
- Show status transitions

### 8. Search (1 minute)
- Search across services
- Show merged results
- Show pagination with merged tokens

### 9. Tests (1 minute)
- Run `pytest tests/test_threads.py` - show parallelism
- Run `pytest tests/test_fk.py` - show FK failures
- Show test coverage

**Total Time: ~13 minutes**

---

## Command-Line Demo

### Quick Demo (5 minutes)
```bash
# Set your composite service URL
export COMPOSITE_URL="https://your-service.run.app"

# Run the comprehensive demo script
./scripts/demo.sh
```

### Manual Demo (10 minutes)
```bash
# 1. Health
curl "$COMPOSITE_URL/healthz" | jq .

# 2. Get User (ETag)
curl -i "$COMPOSITE_URL/users/{user_id}" | grep -i "etag"

# 3. List Items (Pagination)
curl "$COMPOSITE_URL/items?pageSize=3" | jq .

# 4. Create Order (Threads + FK)
curl -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}' \
  | grep -i "x-composite\|location"

# 5. FK Failure
curl -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"invalid","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}' \
  | jq '.detail.code'

# 6. Search
curl "$COMPOSITE_URL/search?q=luxury&pageSize=3" | jq .

# 7. Confirm Order (202)
curl -i -X POST "$COMPOSITE_URL/orders/{order_id}/confirm" | head -5

# 8. Poll Job
curl "$COMPOSITE_URL/jobs/{job_id}" | jq .
```

---

## Web UI Demo

### Deploy UI to Cloud Storage
```bash
# Set your project and bucket name
export GCP_PROJECT_ID="your-project-id"
export GCS_BUCKET_NAME="luxury-rental-ui"

# Deploy
./scripts/deploy_ui_to_gcs.sh
```

### Use the UI
1. Open the public URL in your browser
2. Enter your composite service URL
3. Navigate through tabs:
   - **Health**: Verify service is running
   - **Users**: Test user operations and ETag
   - **Items**: Test pagination
   - **Orders**: Create orders, see threads, test FK
   - **Search**: Test merged search
   - **Jobs**: Test async job confirmation and polling

---

## Testing Demo

### Run All Tests
```bash
pytest
```

### Run Specific Feature Tests
```bash
# Threads
pytest tests/test_threads.py -v

# FK Constraints
pytest tests/test_fk.py -v

# ETags
pytest tests/test_etag.py -v

# Pagination
pytest tests/test_pagination.py -v

# Async Jobs
pytest tests/test_jobs_202.py -v
```

### Show Test Coverage
```bash
pytest --cov=. --cov-report=html
open htmlcov/index.html
```

---

## Troubleshooting

### Service Not Responding
- Check service is deployed: `gcloud run services list`
- Check service logs: `gcloud run services logs read <service-name>`
- Verify environment variables are set

### FK Validation Not Working
- Ensure atomic services are running
- Verify user/item IDs exist
- Check service URLs in configuration

### Threads Not Showing
- Check `X-Composite-Threaded` header is present
- Verify `X-Composite-Parallel-Ms` shows timing
- Run `pytest tests/test_threads.py` to verify

### Web UI Not Loading
- Verify bucket exists: `gsutil ls gs://$BUCKET_NAME`
- Check public access: `gsutil iam get gs://$BUCKET_NAME`
- Verify file uploaded: `gsutil ls gs://$BUCKET_NAME/`

---

## Presentation Tips

1. **Start with the big picture**: Explain composite service architecture
2. **Show encapsulation first**: Same APIs, but with added value
3. **Demonstrate threads visually**: Show timing in headers
4. **Make FK failures obvious**: Use clear error messages
5. **Show async flow**: 202 → polling → completion
6. **Use the web UI**: More visual and interactive
7. **Run tests**: Shows code quality and coverage

---

## Additional Resources

- **API Documentation**: `$COMPOSITE_URL/docs` (Swagger UI)
- **OpenAPI Spec**: `openapi/composite.yaml`
- **Demo Guide**: `docs/DEMO_GUIDE.md`
- **Test Suite**: `pytest tests/`
- **Smoke Tests**: `scripts/smoke.sh`

---

## Success Criteria

Your demo is successful if you can show:

✅ All endpoints work and delegate to atomic services  
✅ POST /orders uses threads (headers prove it)  
✅ FK constraints reject invalid references (422/409)  
✅ ETags work for caching (304 responses)  
✅ Pagination works with tokens  
✅ 201 Created with Location header  
✅ 202 Accepted with job polling  
✅ Search merges results from multiple services  
✅ Tests demonstrate parallelism and FK failures  
✅ Web UI is deployed and functional  

Good luck with your demo! 🚀

