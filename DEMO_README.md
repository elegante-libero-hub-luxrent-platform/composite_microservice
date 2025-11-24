# Composite Service Demo - Complete Guide

This document provides everything you need to demonstrate the Composite Microservice for the Luxury Rental Platform.

## 📋 Quick Links

- **How to Demo**: [`docs/HOW_TO_DEMO.md`](docs/HOW_TO_DEMO.md) - Step-by-step demo instructions
- **Detailed Demo Guide**: [`docs/DEMO_GUIDE.md`](docs/DEMO_GUIDE.md) - Comprehensive API examples
- **Demo Script**: [`scripts/demo.sh`](scripts/demo.sh) - Automated demo script
- **Web UI**: [`web_ui.html`](web_ui.html) - Interactive browser UI
- **Deploy UI**: [`scripts/deploy_ui_to_gcs.sh`](scripts/deploy_ui_to_gcs.sh) - Deploy UI to Cloud Storage

## 🚀 Quick Start

### Option 1: Run Demo Script (Fastest)
```bash
export COMPOSITE_URL="https://your-composite-service.run.app"
./scripts/demo.sh
```

### Option 2: Use Web UI (Most Visual)
```bash
# Deploy UI to Cloud Storage
export GCP_PROJECT_ID="your-project-id"
export GCS_BUCKET_NAME="luxury-rental-ui"
./scripts/deploy_ui_to_gcs.sh

# Open the public URL in your browser
```

### Option 3: Manual Demo (Most Control)
See [`docs/HOW_TO_DEMO.md`](docs/HOW_TO_DEMO.md) for step-by-step instructions.

## ✅ Requirements Checklist

### Composite Microservice Features

- [x] **Encapsulation** - Exposes same APIs as atomics, delegates to MS1/MS2/MS3
- [x] **Threads** - POST /orders uses threads for parallel user/item validation
- [x] **Logical FKs** - Validates user/item exist before creating orders
- [x] **ETag Propagation** - Forwards and combines ETags from atomic services
- [x] **Pagination** - Supports pageSize/pageToken, merges in search
- [x] **201 Created** - POST methods return 201 with Location header
- [x] **202 Accepted** - Async job confirmation with polling endpoint
- [x] **Tests** - Shows parallelism timing and FK failure paths

### Atomic Microservices

- [x] **User & Profile Service** - Cloud Run, Cloud SQL database
- [x] **Catalog & Inventory Service** - Cloud Run, Cloud SQL database  
- [x] **Order & Rental Service** - Cloud Run, Cloud SQL database

### Database Setup

- [x] **VM with MySQL** - One atomic service uses VM MySQL
- [x] **Cloud SQL #1** - `luxury-rental-db` (user service)
- [x] **Cloud SQL #2** - `luxury-rental-db-orders` (order service)
- [x] **Cloud SQL #3** - `luxury-rental-db-catalog` (catalog service)

### Atomic Service Features

- [x] **ETag Processing** - User service returns ETags
- [x] **Query Parameters** - All collection endpoints support filtering
- [x] **Pagination** - Items and orders support pageSize/pageToken
- [x] **Linked Data** - Relative paths in responses
- [x] **201 Created** - POST endpoints return 201 with Location
- [x] **202 Accepted** - Order confirmation returns 202 with job polling

### Web UI

- [x] **Browser UI** - Interactive HTML interface
- [x] **Cloud Storage** - Deployed on GCS with public access
- [x] **All Features** - Demonstrates all composite service features

## 📖 Documentation Structure

```
composite/
├── DEMO_README.md          ← You are here
├── docs/
│   ├── HOW_TO_DEMO.md      ← Step-by-step demo guide
│   └── DEMO_GUIDE.md       ← Detailed API examples
├── scripts/
│   ├── demo.sh             ← Automated demo script
│   └── deploy_ui_to_gcs.sh ← Deploy UI to Cloud Storage
├── web_ui.html             ← Interactive web UI
└── tests/                  ← Test suite demonstrating features
    ├── test_threads.py     ← Parallelism tests
    ├── test_fk.py          ← FK constraint tests
    ├── test_etag.py        ← ETag propagation tests
    ├── test_pagination.py  ← Pagination tests
    └── test_jobs_202.py    ← Async job tests
```

## 🎯 Demo Scenarios

### Scenario 1: Full Feature Demo (15 minutes)
1. Health check
2. Encapsulation (user/item/order endpoints)
3. Threads demonstration (POST /orders)
4. FK constraints (missing user/item)
5. ETag caching
6. Pagination
7. Search with merged results
8. Async job confirmation
9. Test suite execution

### Scenario 2: Quick Demo (5 minutes)
1. Run `./scripts/demo.sh`
2. Show web UI
3. Run key tests

### Scenario 3: Interactive Demo (10 minutes)
1. Use web UI
2. Create order (show threads)
3. Test FK failure
4. Confirm order (show 202)
5. Poll job status

## 🔍 Key Features to Highlight

### 1. Threads (Parallel Execution)
**What to show:**
- POST /orders response headers:
  - `X-Composite-Threaded: true`
  - `X-Composite-Parallel-Ms: <timing>`
  - `X-Composite-Fanout: user,item,availability,order`

**How to demonstrate:**
```bash
curl -i -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-12-01","endDate":"2025-12-05"}' \
  | grep -i "x-composite"
```

### 2. Logical Foreign Keys
**What to show:**
- 422 FK_USER_NOT_FOUND when user doesn't exist
- 422 FK_ITEM_NOT_FOUND when item doesn't exist
- 409 ITEM_UNAVAILABLE when item unavailable

**How to demonstrate:**
```bash
# Missing user
curl -X POST "$COMPOSITE_URL/orders" \
  -H 'Content-Type: application/json' \
  -d '{"userId":"invalid","itemId":"i1",...}' \
  | jq '.detail.code'  # Should be "FK_USER_NOT_FOUND"
```

### 3. ETag Propagation
**What to show:**
- ETag header in responses
- 304 Not Modified with If-None-Match
- Combined ETag in POST /orders

**How to demonstrate:**
```bash
# Get ETag
ETAG=$(curl -i "$COMPOSITE_URL/users/{id}" | grep -i "etag:" | sed 's/.*etag: //i')

# Use If-None-Match
curl -i -H "If-None-Match: $ETAG" "$COMPOSITE_URL/users/{id}"  # Should be 304
```

### 4. Pagination
**What to show:**
- pageSize and pageToken parameters
- nextPageToken in responses
- Merged pagination in search

**How to demonstrate:**
```bash
curl "$COMPOSITE_URL/items?pageSize=3" | jq '.nextPageToken'
curl "$COMPOSITE_URL/search?q=luxury&pageSize=3" | jq '.nextPageToken'
```

### 5. 202 Accepted with Async Jobs
**What to show:**
- POST /orders/{id}/confirm returns 202
- Location header points to /jobs/{job_id}
- GET /jobs/{job_id} shows status transitions

**How to demonstrate:**
```bash
# Confirm order
curl -i -X POST "$COMPOSITE_URL/orders/{id}/confirm"  # Should be 202

# Poll job
curl "$COMPOSITE_URL/jobs/{job_id}" | jq '.status'  # pending → processing → completed
```

## 🧪 Testing

### Run All Tests
```bash
pytest
```

### Run Feature-Specific Tests
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

### Test Output Shows
- ✅ Parallelism timing (faster than sequential)
- ✅ FK validation failures (422/409 responses)
- ✅ ETag handling (304 responses)
- ✅ Pagination token handling
- ✅ Job status transitions

## 🌐 Web UI Deployment

### Deploy to Cloud Storage
```bash
export GCP_PROJECT_ID="your-project-id"
export GCS_BUCKET_NAME="luxury-rental-ui"
./scripts/deploy_ui_to_gcs.sh
```

### Access UI
- Public URL: `https://storage.googleapis.com/luxury-rental-ui/index.html`
- Or: `https://luxury-rental-ui.storage.googleapis.com/index.html`

### UI Features
- Health check
- User operations (ETag testing)
- Item browsing (pagination)
- Order creation (threads + FK)
- Search (merged results)
- Job confirmation and polling

## 📊 Service Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Composite Service (Cloud Run)               │
│  - Encapsulation                                         │
│  - Threads (POST /orders)                                │
│  - Logical FK Constraints                                │
│  - ETag Propagation                                      │
│  - Merged Pagination                                     │
│  - 202 Async Jobs                                        │
└──────────────┬──────────────────────────────────────────┘
               │
       ┌───────┴───────┬──────────────┐
       │               │              │
┌──────▼──────┐ ┌─────▼──────┐ ┌────▼──────┐
│ User Service│ │Catalog Svc  │ │Order Svc  │
│ (Cloud Run) │ │(Cloud Run)  │ │(Cloud Run)│
└──────┬──────┘ └─────┬──────┘ └────┬──────┘
       │               │              │
┌──────▼──────┐ ┌─────▼──────┐ ┌────▼──────┐
│ Cloud SQL   │ │ Cloud SQL   │ │ Cloud SQL │
│ luxury-     │ │ luxury-     │ │ luxury-   │
│ rental-db   │ │ rental-db-   │ │ rental-db-│
│             │ │ catalog     │ │ orders    │
└─────────────┘ └─────────────┘ └───────────┘
```

## 🎓 Learning Resources

- **API Documentation**: `$COMPOSITE_URL/docs` (Swagger UI)
- **OpenAPI Spec**: `openapi/composite.yaml`
- **Architecture**: `docs/ARCH.md`
- **Error Model**: `docs/ERROR_MODEL.md`
- **Headers/ETag/Pagination**: `docs/HEADERS_ETAG_PAGINATION.md`

## 🐛 Troubleshooting

### Service Not Responding
```bash
# Check service status
gcloud run services list

# Check logs
gcloud run services logs read <service-name> --limit=50
```

### FK Validation Not Working
- Verify atomic services are running
- Check user/item IDs exist
- Verify service URLs in config

### Threads Not Showing
- Check `X-Composite-Threaded` header
- Verify `X-Composite-Parallel-Ms` timing
- Run `pytest tests/test_threads.py`

### Web UI Issues
- Verify bucket exists: `gsutil ls gs://$BUCKET_NAME`
- Check public access: `gsutil iam get gs://$BUCKET_NAME`
- Verify file: `gsutil ls gs://$BUCKET_NAME/index.html`

## 📝 Demo Scripts

### Quick Demo
```bash
./scripts/demo.sh
```

### Smoke Test
```bash
./scripts/smoke.sh
```

### Custom Demo
```bash
export COMPOSITE_URL="your-url"
# Use examples from docs/DEMO_GUIDE.md
```

## ✨ Success Criteria

Your demo is successful if you demonstrate:

✅ All endpoints work and delegate correctly  
✅ POST /orders uses threads (headers prove it)  
✅ FK constraints reject invalid data (422/409)  
✅ ETags enable caching (304 responses)  
✅ Pagination works with tokens  
✅ 201 Created with Location header  
✅ 202 Accepted with job polling  
✅ Search merges multiple services  
✅ Tests show parallelism and FK failures  
✅ Web UI is functional  

## 🚀 Ready to Demo?

1. **Choose your demo method:**
   - Quick: `./scripts/demo.sh`
   - Interactive: Deploy and use web UI
   - Detailed: Follow `docs/HOW_TO_DEMO.md`

2. **Prepare your environment:**
   - Set `COMPOSITE_URL`
   - Ensure services are running
   - Have test data ready

3. **Run the demo:**
   - Follow the checklist
   - Show key features
   - Run tests
   - Answer questions

**Good luck with your demo!** 🎉

