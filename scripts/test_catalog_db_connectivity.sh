#!/bin/bash
# Test connectivity between catalog-and-inventory-service and Cloud SQL
# Database: luxury-rental-db-catalog

set -e

SERVICE_URL="https://catalog-and-inventory-service-314897419193.europe-west1.run.app"
PROJECT_ID="upheld-booking-475003-p1"
REGION="europe-west1"
DB_INSTANCE="luxury-rental-db-catalog"

echo "=== Testing Catalog Service to Cloud SQL Connectivity ==="
echo "Service: $SERVICE_URL"
echo "Database Instance: $DB_INSTANCE"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "⚠️  gcloud CLI not found. Adding to PATH..."
    export PATH="$HOME/google-cloud-sdk/bin:$PATH"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}1. Testing Catalog Service Health${NC}"
HEALTH_RESPONSE=$(curl -sS -i "$SERVICE_URL/" 2>&1)
echo "$HEALTH_RESPONSE" | head -10
echo ""

echo -e "${BLUE}2. Testing Catalog Service Endpoints${NC}"
echo "2a. List items (tests database read):"
curl -sS "$SERVICE_URL/items?pageSize=2" | jq . 2>/dev/null || echo "Response: $(curl -sS $SERVICE_URL/items?pageSize=2 | head -20)"
echo ""

echo "2b. Get specific item (tests database read by ID):"
curl -sS "$SERVICE_URL/items/1" 2>/dev/null | jq . || echo "Response: $(curl -sS $SERVICE_URL/items/1 | head -20)"
echo ""

echo -e "${BLUE}3. Checking Cloud SQL Instance Status${NC}"
if command -v gcloud &> /dev/null; then
    echo "Instance details:"
    gcloud sql instances describe "$DB_INSTANCE" \
        --project="$PROJECT_ID" \
        --format="table(name,region,databaseVersion,state,settings.ipConfiguration.ipv4Enabled)" 2>&1 | head -10 || echo "Could not fetch instance details"
    echo ""
    
    echo "Connection name:"
    gcloud sql instances describe "$DB_INSTANCE" \
        --project="$PROJECT_ID" \
        --format="value(connectionName)" 2>&1 || echo "Could not fetch connection name"
    echo ""
else
    echo "⚠️  gcloud not available - skipping Cloud SQL instance checks"
fi

echo -e "${BLUE}4. Testing Database Operations via Service${NC}"
echo "4a. Create item (tests database write):"
CREATE_RESPONSE=$(curl -sS -i -X POST "$SERVICE_URL/items" \
  -H 'Content-Type: application/json' \
  -d '{
    "sku": "TEST-CONN-'$(date +%s)'",
    "name": "Connectivity Test Item",
    "brand": "Test Brand",
    "category": "Test",
    "rent_price_cents": 1000,
    "deposit_cents": 2000
  }' 2>&1)

echo "$CREATE_RESPONSE" | head -15
ITEM_ID=$(echo "$CREATE_RESPONSE" | grep -i "location:" | sed 's/.*\/items\///' | tr -d '\r' || echo "")

if [ -n "$ITEM_ID" ]; then
    echo -e "${GREEN}✅ Item created: $ITEM_ID${NC}"
    echo ""
    echo "4b. Verify item exists (tests database read after write):"
    curl -sS "$SERVICE_URL/items/$ITEM_ID" | jq . 2>/dev/null || curl -sS "$SERVICE_URL/items/$ITEM_ID"
    echo ""
else
    echo -e "${RED}❌ Failed to create item${NC}"
    echo "Full response:"
    echo "$CREATE_RESPONSE"
fi

echo ""
echo -e "${BLUE}5. Checking Cloud Run Service Configuration${NC}"
if command -v gcloud &> /dev/null; then
    echo "Service environment variables:"
    gcloud run services describe catalog-and-inventory-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(spec.template.spec.containers[0].env)" 2>&1 | grep -i "db\|sql\|database" || echo "No DB-related env vars found or service not found"
    echo ""
    
    echo "Cloud SQL connections:"
    gcloud run services describe catalog-and-inventory-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(spec.template.spec.containers[0].cloudSqlConnections)" 2>&1 || echo "No Cloud SQL connections configured"
    echo ""
else
    echo "⚠️  gcloud not available - skipping service configuration checks"
fi

echo ""
echo -e "${YELLOW}=== Connectivity Test Summary ===${NC}"
echo "If all operations above succeeded, the service can connect to Cloud SQL."
echo "If operations failed, check:"
echo "  1. Cloud SQL instance is running"
echo "  2. Cloud Run service has Cloud SQL connection configured"
echo "  3. Service has proper IAM permissions"
echo "  4. Database credentials are correct"

