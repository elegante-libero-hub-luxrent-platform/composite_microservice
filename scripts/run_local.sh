#!/usr/bin/env bash
set -eu
# Default to Cloud Run URLs, but allow override via environment variables
export USER_SVC_BASE=${USER_SVC_BASE:-https://microservices1iter2-314897419193.europe-west1.run.app}
export CAT_SVC_BASE=${CAT_SVC_BASE:-https://catalog-and-inventory-service-314897419193.europe-west1.run.app}
export ORD_SVC_BASE=${ORD_SVC_BASE:-https://order-and-rental-service-314897419193.europe-west1.run.app}
export HTTP_TIMEOUT_SECONDS=${HTTP_TIMEOUT_SECONDS:-5}
export RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-2}
uvicorn app:app --host 0.0.0.0 --port ${PORT:-8080} --reload
