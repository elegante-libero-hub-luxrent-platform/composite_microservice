# Catalog Service to Cloud SQL Connectivity Status

## Test Results Summary

### ✅ Progress Made:
1. **DB_HOST updated**: Changed from `127.0.0.1:3306` to `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog`
2. **Service is attempting connection**: The service is now trying to use the Unix socket path
3. **IAM permissions**: Service account has `roles/cloudsql.client`

### ❌ Current Issue:

**Error in logs:**
```
_mysql_connector.MySQLInterfaceError: Unknown MySQL server host '/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog' (-2)
```

### Root Cause:

The service code is passing the Unix socket path to the `host` parameter of `mysql.connector.connect()`, but it should use the `unix_socket` parameter instead.

This is the **same issue** that was fixed in the order-and-rental-service. The catalog service code needs to be updated.

### Solution Required:

The catalog service's database connection code (likely in `/app/database.py`) needs to be updated to:

```python
def get_connection():
    """
    Create a new MySQL connection.
    Supports both Unix socket (Cloud Run with Cloud SQL) and TCP (local development).
    """
    # Check if using Unix socket (Cloud Run with Cloud SQL)
    if DB_HOST and DB_HOST.startswith('/cloudsql/'):
        # Use Unix socket connection for Cloud Run
        return mysql.connector.connect(
            unix_socket=DB_HOST,  # ← Use unix_socket parameter, not host
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
        )
    # Use TCP connection for local development
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        port=DB_PORT,
    )
```

## Current Configuration

- **DB_HOST**: `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog` ✅
- **Cloud SQL Connection**: Needs to be verified in service spec
- **Service Code**: Needs update to use `unix_socket` parameter

## Next Steps

1. **Update the catalog service code** to use `unix_socket` parameter for Unix socket connections
2. **Redeploy the service** with the updated code
3. **Verify Cloud SQL connection** is properly configured in the service spec
4. **Test connectivity** again

## Test Commands

```bash
# Check current configuration
gcloud run services describe catalog-and-inventory-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --format="value(spec.template.spec.containers[0].env)"

# Check logs for connection attempts
gcloud run services logs read catalog-and-inventory-service \
  --region=europe-west1 \
  --limit=20

# Test API endpoint
curl https://catalog-and-inventory-service-314897419193.europe-west1.run.app/items
```

