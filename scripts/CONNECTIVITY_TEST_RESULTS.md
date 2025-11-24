# Catalog Service to Cloud SQL Connectivity Test Results

## Issue Found

The service is **trying to connect to the database** but using the **wrong connection method**:

### Error in Logs:
```
_mysql_connector.MySQLInterfaceError: Can't connect to MySQL server on '127.0.0.1:3306' (111)
```

### Root Cause:
1. ❌ **Cloud SQL connection not properly configured** - The service doesn't have the Cloud SQL connection in its spec
2. ❌ **Service is using TCP connection (127.0.0.1:3306)** instead of Unix socket
3. ❌ **DB_HOST environment variable** likely set to `127.0.0.1` or not set correctly

## Solution

The service needs to:
1. Have Cloud SQL connection configured (Unix socket access)
2. Use `DB_HOST=/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog` instead of `127.0.0.1`

### Steps to Fix:

1. **Verify Cloud SQL connection is configured:**
   ```bash
   gcloud run services describe catalog-and-inventory-service \
     --region=europe-west1 \
     --project=upheld-booking-475003-p1 \
     --format="value(spec.template.spec.containers[0].cloudSqlConnections)"
   ```

2. **Update DB_HOST environment variable:**
   ```bash
   gcloud run services update catalog-and-inventory-service \
     --region=europe-west1 \
     --project=upheld-booking-475003-p1 \
     --set-env-vars="DB_HOST=/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog"
   ```

3. **Verify other database credentials are set:**
   - DB_USER
   - DB_PASSWORD (from Secret Manager)
   - DB_NAME
   - DB_PORT (usually 3306, but not needed for Unix socket)

## Current Status

- ✅ Cloud SQL instance: RUNNABLE
- ✅ IAM permissions: Granted (cloudsql.client role)
- ❌ Cloud SQL connection: Not properly configured in service spec
- ❌ DB_HOST: Likely set to 127.0.0.1 instead of Unix socket path
- ❌ Database connectivity: Failing (connection refused on 127.0.0.1:3306)

## Next Steps

After fixing the configuration:
1. Service will automatically redeploy
2. Test connectivity again with: `./scripts/test_catalog_db_connectivity.sh`
3. Check logs for successful connections: `gcloud run services logs read catalog-and-inventory-service --region=europe-west1`

