#!/bin/bash
# Script to enable public access to Cloud Run services
# This allows unauthenticated requests to the services

set -e

PROJECT_ID="314897419193"
REGION="europe-west1"

echo "Enabling public access to Cloud Run services..."
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI is not installed or not in PATH"
    echo ""
    echo "To install gcloud:"
    echo "1. Visit: https://cloud.google.com/sdk/docs/install"
    echo "2. Or run: curl https://sdk.cloud.google.com | bash"
    echo "3. Then run: exec -l \$SHELL"
    exit 1
fi

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "ERROR: Not authenticated with gcloud"
    echo ""
    echo "To authenticate, run:"
    echo "  gcloud auth login"
    exit 1
fi

# Set the project
echo "Setting project to ${PROJECT_ID}..."
gcloud config set project ${PROJECT_ID}

echo ""
echo "Enabling public access for:"
echo "  1. microservices1iter2 (User & Profile Service)"
echo "  2. catalog-and-inventory-service"
echo "  3. order-and-rental-service"
echo ""

# Enable public access for User & Profile Service
echo "1. Enabling public access for microservices1iter2..."
gcloud run services add-iam-policy-binding microservices1iter2 \
  --region=${REGION} \
  --member="allUsers" \
  --role="roles/run.invoker" || echo "  ⚠️  Failed or already configured"

# Enable public access for Catalog & Inventory Service
echo ""
echo "2. Enabling public access for catalog-and-inventory-service..."
gcloud run services add-iam-policy-binding catalog-and-inventory-service \
  --region=${REGION} \
  --member="allUsers" \
  --role="roles/run.invoker" || echo "  ⚠️  Failed or already configured"

# Enable public access for Order & Rental Service
echo ""
echo "3. Enabling public access for order-and-rental-service..."
gcloud run services add-iam-policy-binding order-and-rental-service \
  --region=${REGION} \
  --member="allUsers" \
  --role="roles/run.invoker" || echo "  ⚠️  Failed or already configured"

echo ""
echo "✅ Done! All services should now allow public access."
echo ""
echo "Test with:"
echo "  curl -i https://microservices1iter2-314897419193.europe-west1.run.app/"
echo "  curl -i https://catalog-and-inventory-service-314897419193.europe-west1.run.app/"
echo "  curl -i https://order-and-rental-service-314897419193.europe-west1.run.app/"

