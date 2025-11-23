#!/usr/bin/env bash
set -e
BASE=${1:-http://localhost:8080}
curl -sS $BASE/healthz | jq .
curl -sS -i $BASE/users/demo-user
curl -sS $BASE/items?pageSize=2 | jq .
curl -sS -X POST $BASE/orders \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u1","itemId":"i1","startDate":"2025-11-22","endDate":"2025-11-25"}' | jq .
