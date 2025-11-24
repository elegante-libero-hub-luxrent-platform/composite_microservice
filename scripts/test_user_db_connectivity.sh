#!/bin/bash
# Test connectivity between user-and-profile-service and Cloud SQL
# Database: luxury-rental-db

set -e

SERVICE_URL="https://user-and-profile-service-314897419193.europe-west1.run.app"
PROJECT_ID="upheld-booking-475003-p1"
REGION="europe-west1"
DB_INSTANCE="luxury-rental-db"

echo "=== Testing User & Profile Service to Cloud SQL Connectivity ==="
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

echo -e "${BLUE}1. Testing User Service Health${NC}"
HEALTH_RESPONSE=$(curl -sS -i "$SERVICE_URL/" 2>&1)
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}' || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Service is healthy (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}⚠️  Service health check returned HTTP $HTTP_CODE${NC}"
fi
echo "$HEALTH_RESPONSE" | head -10
echo ""

echo -e "${BLUE}2. Checking Cloud SQL Instance Status${NC}"
if command -v gcloud &> /dev/null; then
    echo "Instance details:"
    INSTANCE_INFO=$(gcloud sql instances describe "$DB_INSTANCE" \
        --project="$PROJECT_ID" \
        --format="table(name,region,databaseVersion,state,settings.ipConfiguration.ipv4Enabled)" 2>&1)
    
    if echo "$INSTANCE_INFO" | grep -q "RUNNABLE"; then
        echo -e "${GREEN}✅ Instance is RUNNABLE${NC}"
    else
        echo -e "${RED}❌ Instance is not RUNNABLE${NC}"
    fi
    echo "$INSTANCE_INFO" | head -10
    echo ""
    
    echo "Connection name:"
    CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE" \
        --project="$PROJECT_ID" \
        --format="value(connectionName)" 2>&1)
    echo -e "${GREEN}$CONNECTION_NAME${NC}"
    echo ""
    
    echo "Expected Unix socket path:"
    echo -e "${GREEN}/cloudsql/$CONNECTION_NAME${NC}"
    echo ""
else
    echo "⚠️  gcloud not available - skipping Cloud SQL instance checks"
fi

echo -e "${BLUE}3. Testing Database Operations via Service${NC}"
echo "3a. Get user (tests database read):"
GET_USER_RESPONSE=$(curl -sS -i "$SERVICE_URL/users/1" 2>&1)
GET_USER_CODE=$(echo "$GET_USER_RESPONSE" | grep -i "HTTP" | head -1 | awk '{print $2}' || echo "000")
echo "$GET_USER_RESPONSE" | head -15

if [ "$GET_USER_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Successfully retrieved user (HTTP 200)${NC}"
    echo "$GET_USER_RESPONSE" | tail -1 | jq . 2>/dev/null || echo "$GET_USER_RESPONSE" | tail -1
elif [ "$GET_USER_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠️  User not found (HTTP 404) - Database connection may be working but user doesn't exist${NC}"
elif [ "$GET_USER_CODE" = "500" ]; then
    echo -e "${RED}❌ Internal server error (HTTP 500) - Possible database connection issue${NC}"
    echo "Check service logs for database connection errors"
else
    echo -e "${YELLOW}⚠️  Unexpected status: HTTP $GET_USER_CODE${NC}"
fi
echo ""

echo "3b. Test multiple user IDs:"
for USER_ID in 1 2 3; do
    TEST_CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$SERVICE_URL/users/$USER_ID" 2>&1)
    if [ "$TEST_CODE" = "200" ]; then
        echo -e "   ${GREEN}✅ User $USER_ID exists${NC}"
    elif [ "$TEST_CODE" = "404" ]; then
        echo -e "   ${YELLOW}⚠️  User $USER_ID not found${NC}"
    elif [ "$TEST_CODE" = "500" ]; then
        echo -e "   ${RED}❌ User $USER_ID - Server error (possible DB issue)${NC}"
    else
        echo -e "   ${YELLOW}⚠️  User $USER_ID - Status: $TEST_CODE${NC}"
    fi
done
echo ""

echo -e "${BLUE}4. Checking Cloud Run Service Configuration${NC}"
if command -v gcloud &> /dev/null; then
    echo "4a. Service details:"
    SERVICE_INFO=$(gcloud run services describe user-and-profile-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="yaml(spec.template.spec.containers[0].name,status.url)" 2>&1)
    
    if echo "$SERVICE_INFO" | grep -q "user-and-profile-service"; then
        echo -e "${GREEN}✅ Service found${NC}"
        echo "$SERVICE_INFO"
    else
        echo -e "${RED}❌ Service not found or error accessing${NC}"
        echo "$SERVICE_INFO"
    fi
    echo ""
    
    echo "4b. Cloud SQL connections:"
    CLOUDSQL_CONN=$(gcloud run services describe user-and-profile-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(spec.template.metadata.annotations.'run\.googleapis\.com/cloudsql-instances')" 2>&1)
    
    if [ -n "$CLOUDSQL_CONN" ] && [ "$CLOUDSQL_CONN" != "None" ]; then
        echo -e "${GREEN}✅ Cloud SQL connection configured: $CLOUDSQL_CONN${NC}"
        if echo "$CLOUDSQL_CONN" | grep -q "$DB_INSTANCE"; then
            echo -e "${GREEN}✅ Connection matches database instance${NC}"
        else
            echo -e "${YELLOW}⚠️  Connection does not match expected instance${NC}"
        fi
    else
        echo -e "${RED}❌ No Cloud SQL connection configured${NC}"
    fi
    echo ""
    
    echo "4c. Database-related environment variables:"
    ENV_VARS=$(gcloud run services describe user-and-profile-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(spec.template.spec.containers[0].env)" 2>&1)
    
    if echo "$ENV_VARS" | grep -qi "db\|sql\|database"; then
        echo "$ENV_VARS" | grep -i "db\|sql\|database" | head -10
    else
        echo -e "${YELLOW}⚠️  No DB-related environment variables found${NC}"
    fi
    echo ""
    
    echo "4d. Service account and IAM:"
    SERVICE_ACCOUNT=$(gcloud run services describe user-and-profile-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="value(spec.template.spec.serviceAccountName)" 2>&1)
    echo "Service Account: $SERVICE_ACCOUNT"
    
    if [ -n "$SERVICE_ACCOUNT" ] && [ "$SERVICE_ACCOUNT" != "None" ]; then
        echo "Checking IAM permissions..."
        IAM_ROLES=$(gcloud projects get-iam-policy "$PROJECT_ID" \
            --flatten="bindings[].members" \
            --filter="bindings.members:$SERVICE_ACCOUNT" \
            --format="value(bindings.role)" 2>&1 | grep -i "cloudsql" || echo "")
        
        if echo "$IAM_ROLES" | grep -qi "cloudsql.client"; then
            echo -e "${GREEN}✅ Service account has cloudsql.client role${NC}"
        else
            echo -e "${YELLOW}⚠️  Service account may not have cloudsql.client role${NC}"
        fi
    fi
    echo ""
else
    echo "⚠️  gcloud not available - skipping service configuration checks"
fi

echo -e "${BLUE}5. Checking Recent Service Logs for Database Errors${NC}"
if command -v gcloud &> /dev/null; then
    echo "Recent logs (last 20 lines, filtering for DB/connection errors):"
    LOGS=$(gcloud run services logs read user-and-profile-service \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --limit=50 2>&1)
    
    if echo "$LOGS" | grep -qi "error\|exception\|failed\|connection\|mysql\|database"; then
        echo -e "${RED}⚠️  Found potential errors in logs:${NC}"
        echo "$LOGS" | grep -i "error\|exception\|failed\|connection\|mysql\|database" | head -10
    else
        echo -e "${GREEN}✅ No obvious database errors in recent logs${NC}"
        echo "Last few log entries:"
        echo "$LOGS" | head -10
    fi
    echo ""
else
    echo "⚠️  gcloud not available - skipping log checks"
fi

echo ""
echo -e "${YELLOW}=== Connectivity Test Summary ===${NC}"
echo ""
echo "Test Results:"
echo "  - Service Health: $(if [ "$HTTP_CODE" = "200" ]; then echo -e "${GREEN}✅ OK${NC}"; else echo -e "${RED}❌ Failed${NC}"; fi)"
echo "  - Database Instance: $DB_INSTANCE"
echo "  - Cloud SQL Connection: $(if [ -n "$CLOUDSQL_CONN" ] && [ "$CLOUDSQL_CONN" != "None" ]; then echo -e "${GREEN}✅ Configured${NC}"; else echo -e "${RED}❌ Not configured${NC}"; fi)"
echo "  - User Retrieval: $(if [ "$GET_USER_CODE" = "200" ]; then echo -e "${GREEN}✅ Working${NC}"; elif [ "$GET_USER_CODE" = "404" ]; then echo -e "${YELLOW}⚠️  User not found (connection may be OK)${NC}"; else echo -e "${RED}❌ Failed${NC}"; fi)"
echo ""
echo "If connectivity is failing, check:"
echo "  1. Cloud SQL instance is RUNNABLE"
echo "  2. Cloud Run service has Cloud SQL connection annotation configured"
echo "  3. Service account has roles/cloudsql.client IAM permission"
echo "  4. DB_HOST environment variable is set to Unix socket path: /cloudsql/$CONNECTION_NAME"
echo "  5. Service code uses unix_socket parameter (not host) when DB_HOST starts with /cloudsql/"
echo "  6. Database credentials (DB_USER, DB_PASSWORD, DB_NAME) are correct"
echo ""
echo "To view full service logs:"
echo "  gcloud run services logs read user-and-profile-service --region=$REGION --project=$PROJECT_ID --limit=100"

