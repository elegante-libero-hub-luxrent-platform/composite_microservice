# Cloud Run to Cloud SQL Connection Setup Guide

## ✅ Completed Steps

1. **Enabled Cloud SQL Admin API**
2. **Added Cloud SQL connection annotation** to `order-and-rental-service`
3. **Granted Cloud SQL Client role** to service account
4. **Updated DB_HOST secret** to use Unix socket path: `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`

## 🔄 Next Steps

### 1. Redeploy the Order Service

The service needs to be redeployed to pick up the new secret version:

```bash
# Option 1: Trigger a new deployment (if using Cloud Build)
git commit --allow-empty -m "Trigger redeploy for DB connection"
git push

# Option 2: Force a new revision
gcloud run services update order-and-rental-service \
  --region=europe-west1 \
  --no-traffic
```

### 2. Add Test Endpoint (Optional)

Add the test endpoint from `db_test_endpoint_example.py` to your order service's `main.py`:

```python
from scripts.db_test_endpoint_example import router as test_router
app.include_router(test_router)
```

### 3. Test the Connection

Once redeployed, test the connection:

```bash
# Test the endpoint (if you added it)
curl https://order-and-rental-service-plrurfl3kq-ew.a.run.app/test/db-connection

# Or test the actual /orders endpoint
curl -X POST "https://order-and-rental-service-plrurfl3kq-ew.a.run.app/orders" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":1,"item_id":1,"start_date":"2025-01-05","end_date":"2025-01-09"}'
```

## 📋 Connection Details

- **Cloud SQL Instance**: `luxury-rental-db-orders`
- **Connection Name**: `upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`
- **Unix Socket Path**: `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`
- **Service Account**: `314897419193-compute@developer.gserviceaccount.com`
- **IAM Role**: `roles/cloudsql.client`

## 🔍 Troubleshooting

### If connection still fails:

1. **Check secret values:**
   ```bash
   gcloud secrets versions access latest --secret="orders-db-host"
   gcloud secrets versions access latest --secret="orders-db-user"
   gcloud secrets versions access latest --secret="orders-db-name"
   ```

2. **Verify Cloud SQL instance is running:**
   ```bash
   gcloud sql instances describe luxury-rental-db-orders
   ```

3. **Check service logs:**
   ```bash
   gcloud run services logs read order-and-rental-service --region=europe-west1 --limit=50
   ```

4. **Verify database exists and user has permissions:**
   ```bash
   gcloud sql databases list --instance=luxury-rental-db-orders
   gcloud sql users list --instance=luxury-rental-db-orders
   ```

## 📝 Database Connection Code Pattern

For your order service code, use this pattern:

```python
import os
import mysql.connector

db_host = os.getenv('DB_HOST')
use_unix_socket = db_host.startswith('/cloudsql/')

config = {
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_NAME'),
}

if use_unix_socket:
    config['unix_socket'] = db_host
else:
    config['host'] = db_host
    config['port'] = int(os.getenv('DB_PORT', 3306))

conn = mysql.connector.connect(**config)
```




