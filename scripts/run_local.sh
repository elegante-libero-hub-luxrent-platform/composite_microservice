#!/usr/bin/env bash
set -eu
export USER_SVC_BASE=${USER_SVC_BASE:-http://localhost:7001}
export CAT_SVC_BASE=${CAT_SVC_BASE:-http://localhost:7002}
export ORD_SVC_BASE=${ORD_SVC_BASE:-http://localhost:7003}
uvicorn app:app --host 0.0.0.0 --port ${PORT:-8080} --reload
