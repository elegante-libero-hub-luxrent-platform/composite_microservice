#!/bin/bash
# Deploy Web UI to Google Cloud Storage
# This script uploads web_ui.html to a Cloud Storage bucket and makes it publicly accessible

set -e

BUCKET_NAME="${GCS_BUCKET_NAME:-luxury-rental-ui}"
PROJECT_ID="${GCP_PROJECT_ID:-upheld-booking-475003-p1}"
UI_FILE="${UI_FILE:-web_ui.html}"

echo "=== Deploying Web UI to Cloud Storage ==="
echo "Project: $PROJECT_ID"
echo "Bucket: $BUCKET_NAME"
echo "File: $UI_FILE"
echo ""

# Check if bucket exists
if ! gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    echo "Creating bucket: $BUCKET_NAME"
    gsutil mb -p "$PROJECT_ID" -l us-central1 "gs://$BUCKET_NAME"
    echo "✅ Bucket created"
else
    echo "✅ Bucket already exists"
fi

# Upload the HTML file
echo ""
echo "Uploading $UI_FILE..."
gsutil cp "$UI_FILE" "gs://$BUCKET_NAME/index.html"
echo "✅ File uploaded"

# Set public read access
echo ""
echo "Setting public read access..."
gsutil iam ch allUsers:objectViewer "gs://$BUCKET_NAME"
gsutil web set -m index.html -e index.html "gs://$BUCKET_NAME"
echo "✅ Public access configured"

# Get the public URL
PUBLIC_URL="https://storage.googleapis.com/$BUCKET_NAME/index.html"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Web UI deployed successfully!"
echo ""
echo "Public URL: $PUBLIC_URL"
echo ""
echo "You can also access it via:"
echo "  https://$BUCKET_NAME.storage.googleapis.com/index.html"
echo ""
echo "To update the composite service URL in the UI, edit the default value"
echo "in the 'Composite Service Base URL' field after opening the page."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

