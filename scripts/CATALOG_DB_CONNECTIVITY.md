# Catalog Service to Cloud SQL Connectivity Test

## Current Status

Based on the test results:

✅ **Cloud SQL Instance**: `luxury-rental-db-catalog` is RUNNABLE
- Region: `us-central1`
- Connection Name: `upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog`
- IPv4 Enabled: Yes

❌ **Cloud Run Service**: `catalog-and-inventory-service` 
- **No Cloud SQL connection configured**
- Service is running but endpoints return 404 (may be endpoint path issue)

## Issues Found

1. **Cloud SQL Connection Not Configured**
   - The Cloud Run service doesn't have Cloud SQL connections in its configuration
   - This means the service cannot connect to the database via Unix socket

2. **Endpoint Paths**
   - The service may use different endpoint paths (e.g., `/catalog/items` instead of `/items`)
   - Need to verify the actual API structure

## Solution: Configure Cloud SQL Connection

### Option 1: Use the Setup Script

```bash
./scripts/setup_catalog_cloudsql.sh
```

This script will:
1. Add the Cloud SQL connection to the Cloud Run service
2. Grant necessary IAM permissions
3. Verify the configuration

### Option 2: Manual Configuration

#### Step 1: Add Cloud SQL Connection

```bash
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
gcloud run services update catalog-and-inventory-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --add-cloudsql-instances=upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog
```

#### Step 2: Grant IAM Permissions

```bash
# Get the service account
SERVICE_ACCOUNT=$(gcloud run services describe catalog-and-inventory-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --format="value(spec.template.spec.serviceAccountName)")

# If no custom service account, use default
if [ -z "$SERVICE_ACCOUNT" ] || [ "$SERVICE_ACCOUNT" = "null" ]; then
  SERVICE_ACCOUNT="catalog-and-inventory-service@upheld-booking-475003-p1.iam.gserviceaccount.com"
fi

# Grant Cloud SQL Client role
gcloud projects add-iam-policy-binding upheld-booking-475003-p1 \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client"
```

#### Step 3: Configure Environment Variables

The service needs these environment variables:

```bash
DB_HOST=/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog
DB_USER=<your-db-user>
DB_PASSWORD=<from-secret-manager>
DB_NAME=<your-database-name>
DB_PORT=3306
```

Set them via:

```bash
gcloud run services update catalog-and-inventory-service \
  --region=europe-west1 \
  --project=upheld-booking-475003-p1 \
  --set-env-vars="DB_HOST=/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog,DB_NAME=your_db_name,DB_USER=your_user" \
  --update-secrets="DB_PASSWORD=your-secret-name:latest"
```

## Testing Connectivity

After configuration, test with:

```bash
./scripts/test_catalog_db_connectivity.sh
```

## Expected Endpoints

Based on the service structure, try these endpoints:

```bash
# Health check
curl https://catalog-and-inventory-service-314897419193.europe-west1.run.app/

# List items (if using /catalog prefix)
curl https://catalog-and-inventory-service-314897419193.europe-west1.run.app/catalog/items

# List items (if using root)
curl https://catalog-and-inventory-service-314897419193.europe-west1.run.app/items

# Get specific item
curl https://catalog-and-inventory-service-314897419193.europe-west1.run.app/catalog/items/1
```

## Troubleshooting

### If endpoints return 404:
- Check the actual API structure at `/docs` endpoint
- Verify the service code uses the correct route paths

### If database connection fails:
1. Verify Cloud SQL connection is configured:
   ```bash
   gcloud run services describe catalog-and-inventory-service \
     --region=europe-west1 \
     --format="value(spec.template.spec.containers[0].cloudSqlConnections)"
   ```

2. Check IAM permissions:
   ```bash
   gcloud projects get-iam-policy upheld-booking-475003-p1 \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:*catalog*"
   ```

3. Verify database credentials are correct
4. Check service logs:
   ```bash
   gcloud run services logs read catalog-and-inventory-service \
     --region=europe-west1 \
     --limit=50
   ```

## Connection Details

- **Connection Name**: `upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog`
- **Unix Socket Path**: `/cloudsql/upheld-booking-475003-p1:us-central1:luxury-rental-db-catalog`
- **Region**: `us-central1` (note: service is in `europe-west1`, but DB is in `us-central1` - this is fine)

