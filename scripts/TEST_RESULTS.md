# Cloud Run to Cloud SQL Connection Test Results

**Date**: 2025-11-24  
**Service**: order-and-rental-service  
**Database**: luxury-rental-db-orders

## ✅ Infrastructure Configuration (ALL CORRECT)

### Cloud SQL Instance
- **Status**: ✅ RUNNABLE
- **Connection Name**: `upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`
- **Database**: ✅ `orders_db` exists
- **User**: ✅ `rentals_user` exists with host `%` (all hosts allowed)

### Cloud Run Service Configuration
- **Service**: `order-and-rental-service`
- **Region**: `europe-west1`
- **Cloud SQL Annotation**: ✅ Configured
  - `run.googleapis.com/cloudsql-instances: upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`
- **Service Account**: `314897419193-compute@developer.gserviceaccount.com`
- **IAM Role**: ✅ `roles/cloudsql.client` granted

### Secrets Configuration
- **DB_HOST**: ✅ `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders`
- **DB_USER**: ✅ `rentals_user`
- **DB_NAME**: ✅ `orders_db`
- **DB_PASSWORD**: ✅ Set (from Secret Manager)

## ❌ Current Issue

### Error
```
Unknown MySQL server host '/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders' (-2)
```

### Root Cause
The order service code is using the Unix socket path as a `host` parameter instead of the `unix_socket` parameter.

**Current Code (Incorrect)**:
```python
mysql.connector.connect(
    host=os.getenv('DB_HOST'),  # ❌ Wrong - treats Unix socket as hostname
    ...
)
```

**Required Fix**:
```python
db_host = os.getenv('DB_HOST')
if db_host.startswith('/cloudsql/'):
    mysql.connector.connect(
        unix_socket=db_host,  # ✅ Correct - use unix_socket parameter
        ...
    )
```

## 📊 Test Results

### Endpoint Test
```bash
curl -X POST "https://order-and-rental-service-plrurfl3kq-ew.a.run.app/orders" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":1,"item_id":1,"start_date":"2025-01-05","end_date":"2025-01-09"}'
```

**Result**: ❌ HTTP 500 Internal Server Error

**Reason**: Database connection code needs to be fixed to use Unix socket parameter.

## 🔧 Next Steps

1. **Fix the code** in `order_and_rental_service` repository:
   - File: `main.py`
   - Function: `get_connection()` (around line 57)
   - Apply fix from `QUICK_FIX_SUMMARY.md`

2. **Commit and push** the fix

3. **Wait for Cloud Build** to redeploy (~2-5 minutes)

4. **Re-test** the endpoint

## ✅ Verification Checklist

- [x] Cloud SQL instance is RUNNABLE
- [x] Database `orders_db` exists
- [x] User `rentals_user` exists
- [x] Service account has Cloud SQL Client role
- [x] Cloud Run service has Cloud SQL connection annotation
- [x] DB_HOST secret is set to Unix socket path
- [ ] **Code uses `unix_socket` parameter (NEEDS FIX)**

## 📝 Connection Details Summary

| Component | Status | Value |
|-----------|--------|-------|
| Cloud SQL Instance | ✅ | luxury-rental-db-orders |
| Connection Name | ✅ | upheld-booking-475003-p1:us-central1:luxury-rental-db-orders |
| Unix Socket Path | ✅ | /cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-orders |
| Database | ✅ | orders_db |
| Database User | ✅ | rentals_user |
| Service Account | ✅ | 314897419193-compute@developer.gserviceaccount.com |
| IAM Permission | ✅ | roles/cloudsql.client |
| Cloud Run Annotation | ✅ | Configured |
| Code Implementation | ❌ | Needs fix |

## 🎯 Conclusion

**Infrastructure**: ✅ 100% correctly configured  
**Code**: ❌ Needs fix to use Unix socket parameter

Once the code fix is applied and deployed, the connection should work immediately.




