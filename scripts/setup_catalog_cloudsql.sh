#!/bin/bash
# Script to configure Cloud SQL connection for catalog-and-inventory-service

set -e

PROJECT_ID="upheld-booking-475003-p1"
REGION="europe-west1"
SERVICE_NAME="catalog-and-inventory-service"
DB_INSTANCE="luxury-rental-db-catalog"
DB_REGION="us-central1"

echo "=== Configuring Cloud SQL Connection for Catalog Service ==="
echo "Service: $SERVICE_NAME"
echo "Database: $DB_INSTANCE"
echo "Project: $PROJECT_ID"
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "⚠️  gcloud CLI not found. Adding to PATH..."
    export PATH="$HOME/google-cloud-sdk/bin:$PATH"
fi

# Get connection name
CONNECTION_NAME="${PROJECT_ID}:${DB_REGION}:${DB_INSTANCE}"
echo "Connection Name: $CONNECTION_NAME"
echo ""

echo "1. Checking current Cloud SQL connections..."
CURRENT_CONN=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.containers[0].cloudSqlConnections[0])" 2>&1 || echo "")

if [ -n "$CURRENT_CONN" ] && [ "$CURRENT_CONN" != "null" ]; then
    echo "   Current connection: $CURRENT_CONN"
    if [ "$CURRENT_CONN" = "$CONNECTION_NAME" ]; then
        echo "   ✅ Cloud SQL connection already configured correctly!"
        exit 0
    else
        echo "   ⚠️  Different connection configured. Will update..."
    fi
else
    echo "   No Cloud SQL connection configured."
fi

echo ""
echo "2. Adding Cloud SQL connection to service..."
gcloud run services update "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --add-cloudsql-instances="$CONNECTION_NAME" \
    --quiet

echo ""
echo "3. Verifying connection..."
NEW_CONN=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.containers[0].cloudSqlConnections[0])" 2>&1)

if [ "$NEW_CONN" = "$CONNECTION_NAME" ]; then
    echo "   ✅ Cloud SQL connection configured successfully!"
else
    echo "   ⚠️  Connection may not be configured. Check manually."
    echo "   Expected: $CONNECTION_NAME"
    echo "   Got: $NEW_CONN"
fi

echo ""
echo "4. Granting Cloud SQL Client role to service account..."
SERVICE_ACCOUNT=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.serviceAccountName)" 2>&1)

if [ -z "$SERVICE_ACCOUNT" ] || [ "$SERVICE_ACCOUNT" = "null" ]; then
    SERVICE_ACCOUNT="${SERVICE_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    echo "   Using default service account: $SERVICE_ACCOUNT"
else
    echo "   Service account: $SERVICE_ACCOUNT"
fi

echo ""
echo "   Granting roles/cloudsql.client..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/cloudsql.client" \
    --condition=None \
    --quiet 2>&1 || echo "   ⚠️  May already have permission or service account doesn't exist"

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Next steps:"
echo "1. The service will need to be redeployed or will restart automatically"
echo "2. Test connectivity with: ./scripts/test_catalog_db_connectivity.sh"
echo "3. Ensure database credentials are set in environment variables:"
echo "   - DB_HOST (Unix socket: /cloudsql/$CONNECTION_NAME)"
echo "   - DB_USER"
echo "   - DB_PASSWORD (from Secret Manager)"
echo "   - DB_NAME"
echo "   - DB_PORT (usually 3306)"

