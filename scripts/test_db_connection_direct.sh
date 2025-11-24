#!/bin/bash
# Direct database connectivity test
# Tests if we can connect to Cloud SQL from the service's perspective

set -e

PROJECT_ID="upheld-booking-475003-p1"
REGION="europe-west1"
SERVICE_NAME="catalog-and-inventory-service"
DB_INSTANCE="luxury-rental-db-catalog"
DB_REGION="us-central1"
CONNECTION_NAME="${PROJECT_ID}:${DB_REGION}:${DB_INSTANCE}"

echo "=== Direct Database Connectivity Test ==="
echo "Service: $SERVICE_NAME"
echo "Database: $DB_INSTANCE"
echo "Connection: $CONNECTION_NAME"
echo ""

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    export PATH="$HOME/google-cloud-sdk/bin:$PATH"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}1. Verifying Cloud SQL Connection Configuration${NC}"
CONN=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.containers[0].cloudSqlConnections[0])" 2>&1)

if [ -n "$CONN" ] && [ "$CONN" = "$CONNECTION_NAME" ]; then
    echo -e "${GREEN}✅ Cloud SQL connection configured: $CONN${NC}"
else
    echo -e "${RED}❌ Cloud SQL connection not properly configured${NC}"
    echo "   Expected: $CONNECTION_NAME"
    echo "   Got: $CONN"
    exit 1
fi
echo ""

echo -e "${BLUE}2. Checking IAM Permissions${NC}"
SERVICE_ACCOUNT=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.serviceAccountName)" 2>&1)

if [ -z "$SERVICE_ACCOUNT" ] || [ "$SERVICE_ACCOUNT" = "null" ]; then
    SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"
fi

echo "   Service Account: $SERVICE_ACCOUNT"

HAS_PERMISSION=$(gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT} AND bindings.role:roles/cloudsql.client" \
    --format="value(bindings.role)" 2>&1 | head -1)

if [ -n "$HAS_PERMISSION" ]; then
    echo -e "${GREEN}✅ Service account has cloudsql.client role${NC}"
else
    echo -e "${YELLOW}⚠️  Service account may not have cloudsql.client role${NC}"
fi
echo ""

echo -e "${BLUE}3. Checking Database Environment Variables${NC}"
ENV_VARS=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(spec.template.spec.containers[0].env)" 2>&1)

if echo "$ENV_VARS" | grep -qi "DB_HOST\|DB_USER\|DB_NAME"; then
    echo -e "${GREEN}✅ Database environment variables found${NC}"
    echo "$ENV_VARS" | grep -i "DB_" | head -5
else
    echo -e "${YELLOW}⚠️  No database environment variables found${NC}"
    echo "   Service may need: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, DB_PORT"
fi
echo ""

echo -e "${BLUE}4. Testing Service Health and Response${NC}"
HEALTH=$(curl -sS -o /dev/null -w "%{http_code}" "https://catalog-and-inventory-service-314897419193.europe-west1.run.app/" 2>&1)
if [ "$HEALTH" = "200" ]; then
    echo -e "${GREEN}✅ Service is responding (HTTP $HEALTH)${NC}"
else
    echo -e "${YELLOW}⚠️  Service returned HTTP $HEALTH${NC}"
fi
echo ""

echo -e "${BLUE}5. Checking Recent Service Logs for Database Activity${NC}"
echo "   Looking for connection attempts, queries, or errors..."
LOGS=$(gcloud run services logs read "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --limit=50 2>&1)

if echo "$LOGS" | grep -qi "connected\|connection\|database\|mysql\|sql"; then
    echo -e "${GREEN}✅ Found database-related log entries${NC}"
    echo "$LOGS" | grep -i "connected\|connection\|database\|mysql\|sql" | head -5
elif echo "$LOGS" | grep -qi "error\|failed\|exception"; then
    echo -e "${RED}❌ Found errors in logs${NC}"
    echo "$LOGS" | grep -i "error\|failed\|exception" | head -5
else
    echo -e "${YELLOW}⚠️  No database-related activity found in recent logs${NC}"
    echo "   This might mean:"
    echo "   - Service hasn't attempted database connection yet"
    echo "   - Database credentials not configured"
    echo "   - Service endpoints not being called"
fi
echo ""

echo -e "${BLUE}6. Testing Database Operations via API${NC}"
echo "6a. Attempting to list items (read operation):"
READ_TEST=$(curl -sS -w "\nHTTP_CODE:%{http_code}" "https://catalog-and-inventory-service-314897419193.europe-west1.run.app/items?pageSize=1" 2>&1)
HTTP_CODE=$(echo "$READ_TEST" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$READ_TEST" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Read operation successful (HTTP 200)${NC}"
    echo "$BODY" | head -3
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠️  Endpoint not found (HTTP 404) - may be path issue${NC}"
    echo "   Try: /catalog/items or check /docs for correct paths"
else
    echo -e "${RED}❌ Read operation failed (HTTP $HTTP_CODE)${NC}"
    echo "$BODY" | head -5
fi
echo ""

echo -e "${BLUE}7. Cloud SQL Instance Status${NC}"
INSTANCE_STATE=$(gcloud sql instances describe "$DB_INSTANCE" \
    --project="$PROJECT_ID" \
    --format="value(state)" 2>&1)

if [ "$INSTANCE_STATE" = "RUNNABLE" ]; then
    echo -e "${GREEN}✅ Database instance is RUNNABLE${NC}"
else
    echo -e "${RED}❌ Database instance state: $INSTANCE_STATE${NC}"
fi
echo ""

echo -e "${YELLOW}=== Connectivity Test Summary ===${NC}"
echo ""
if [ "$CONN" = "$CONNECTION_NAME" ] && [ "$INSTANCE_STATE" = "RUNNABLE" ]; then
    echo -e "${GREEN}✅ Infrastructure is properly configured:${NC}"
    echo "   - Cloud SQL connection: Configured"
    echo "   - Database instance: RUNNABLE"
    echo "   - IAM permissions: Checked"
    echo ""
    if echo "$ENV_VARS" | grep -qi "DB_"; then
        echo -e "${GREEN}✅ Database credentials appear to be configured${NC}"
        echo ""
        echo "To fully verify connectivity:"
        echo "1. Check service logs for successful database connections"
        echo "2. Test actual API endpoints that use the database"
        echo "3. Verify database credentials are correct"
    else
        echo -e "${YELLOW}⚠️  Database credentials may need to be configured${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Set DB_HOST=/cloudsql/$CONNECTION_NAME"
        echo "2. Set DB_USER, DB_PASSWORD (from Secret Manager), DB_NAME"
        echo "3. Redeploy the service"
    fi
else
    echo -e "${RED}❌ Configuration issues found${NC}"
    echo "   Please review the output above"
fi

