# User & Profile Service to Cloud SQL Connectivity Test Results

**Date**: 2025-11-24  
**Service**: user-and-profile-service  
**Database**: luxury-rental-db

## ✅ Infrastructure Configuration (FIXED)

### Cloud SQL Instance
- **Status**: ✅ RUNNABLE
- **Connection Name**: `upheld-booking-475003-p1:us-central1:luxury-rental-db`
- **Database**: ✅ `user_profile_db` exists
- **User**: ✅ `admin` exists

### Cloud Run Service Configuration
- **Service**: `user-and-profile-service`
- **Region**: `europe-west1`
- **Cloud SQL Annotation**: ✅ **FIXED** - Now configured
  - `run.googleapis.com/cloudsql-instances: upheld-booking-475003-p1:us-central1:luxury-rental-db`
- **Service Account**: `314897419193-compute@developer.gserviceaccount.com`
- **IAM Role**: ✅ `roles/cloudsql.client` granted

### Secrets Configuration
- **DB_HOST**: ✅ **FIXED** - Updated from IP address to Unix socket path
  - **Before**: `10.105.176.9` (IP address - incorrect)
  - **After**: `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db` (Unix socket - correct)
- **DB_USER**: ✅ `admin` (from secret `user-db-user`)
- **DB_NAME**: ✅ `user_profile_db` (from secret `user-db-name`)
- **DB_PASSWORD**: ✅ Set (from Secret Manager `user-db-password`)

## ✅ Service Status

### Service Logs Show:
```
🚀 Starting User & Profile Service
🔗 Mode: Cloud Run (Unix Socket)
🔌 Connection Name: upheld-booking-475003-p1:us-central1:luxury-rental-db
📦 Database: user_profile_db
✓ Database schema initialized successfully
```

**Status**: ✅ Service is running and database connection is working!

## ⚠️ API Format Note

The service expects **UUID format** for user IDs, not integer IDs:
- ❌ `/users/1` → HTTP 422 (Invalid UUID format)
- ✅ `/users/{uuid}` → Should work with valid UUID

Example UUID format: `550e8400-e29b-41d4-a716-446655440000`

## Changes Made

### 1. Added Cloud SQL Connection Annotation
```bash
gcloud run services update user-and-profile-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --add-cloudsql-instances=upheld-booking-475003-p1:us-central1:luxury-rental-db
```

### 2. Updated DB_HOST Secret
```bash
echo -n "/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db" | \
  gcloud secrets versions add user-db-host --data-file=- \
  --project=upheld-booking-475003-p1
```

### 3. Triggered Service Restart
```bash
gcloud run services update user-and-profile-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --no-traffic
```

## Environment Variables

The service uses these environment variables (note: variable names use `CATALOG_DB_*` prefix, but they reference user-db secrets):

- `CATALOG_DB_HOST` → Secret: `user-db-host` (now set to Unix socket path)
- `CATALOG_DB_PORT` → Secret: `user-db-port`
- `CATALOG_DB_USER` → Secret: `user-db-user` (value: `admin`)
- `CATALOG_DB_NAME` → Secret: `user-db-name` (value: `user_profile_db`)
- `DB_PASSWORD_SECRET` → `user-db-password`
- `INSTANCE_CONNECTION_NAME` → `upheld-booking-475003-p1:us-central1:luxury-rental-db`

## Verification

### Test Service Health
```bash
curl https://user-and-profile-service-314897419193.europe-west1.run.app/health
```

### Test Database Connection (if service has test endpoint)
```bash
curl https://user-and-profile-service-314897419193.europe-west1.run.app/test/db-connection
```

### Check Service Logs
```bash
gcloud run services logs read user-and-profile-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --limit=50
```

## Current Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Cloud SQL Instance | ✅ | RUNNABLE |
| Connection Name | ✅ | Correctly configured |
| Cloud SQL Annotation | ✅ | **FIXED** - Now configured |
| DB_HOST Secret | ✅ | **FIXED** - Updated to Unix socket path |
| IAM Permissions | ✅ | cloudsql.client role granted |
| Service Code | ✅ | Detecting Unix socket mode correctly |
| Database Schema | ✅ | Initialized successfully |
| Service Running | ✅ | Application startup complete |

## Next Steps

1. ✅ **Cloud SQL connection configured** - DONE
2. ✅ **DB_HOST secret updated** - DONE
3. ✅ **Service restarted** - DONE
4. ⚠️ **Test with valid UUID** - Service expects UUID format for user IDs
5. 📝 **Optional**: Consider adding a test endpoint for database connectivity verification

## Test Script

Use the test script to verify connectivity:
```bash
./scripts/test_user_db_connectivity.sh
```

