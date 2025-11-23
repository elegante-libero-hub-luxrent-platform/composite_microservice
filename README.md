# Composite Microservice (Luxury Rental Platform)

The composite service fan-outs to the three domain microservices (Users, Catalog, Orders) and exposes a single, mobile-friendly API surface for the luxury rental experience. It owns the responsibilities that span domains: FK enforcement, cross-service pagination, aggregated search, traceability, and demo automation.

## Quick start

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export USER_SVC_BASE=http://localhost:7001
export CAT_SVC_BASE=http://localhost:7002
export ORD_SVC_BASE=http://localhost:7003
uvicorn app:app --reload --port 8080
```

The helper script `scripts/run_local.sh` wires the same defaults. `scripts/smoke.sh` exercises health, user eTags, catalog pagination, and order fan-out using curl.

## Feature highlights

- **Encapsulation** – every endpoint mirrors the “atomic” services but enforces composite-specific behavior before delegating, keeping clients unaware of service boundaries.
- **Threaded order creation** – `POST /orders` uses background threads (via `asyncio.to_thread`) to fetch user + item details in parallel, recording proof via the `X-Composite-Parallel-*` headers.
- **Logical foreign keys** – FK validation rejects missing users/items (422) and unavailable items (409) before the order service ever sees the request.
- **ETag propagation** – user/item passthrough responses forward upstream `ETag`s; aggregated responses compute deterministic combined tags to keep caches coherent.
- **Merged pagination** – opaque `nextPageToken` strings store per-source cursors so `/search` can stitch catalog and order data while clients manage a single token.
- **Jobs façade** – `/orders/{id}/confirm` returns `202 Accepted` with a polling location, and `/jobs/{jobId}` proxies job state transitions for synchronous UX.
- **OpenAPI + docs** – `openapi/composite.yaml` and the `docs/` folder describe the API, shared headers, and demo scripts for onboarding.

## Testing

```bash
pytest
```

Unit tests rely on `respx` to mock the downstream services and cover:

- threaded fan-out timing (`tests/test_threads.py`)
- FK and conflict guards (`tests/test_fk.py`)
- ETag propagation and combined caching (`tests/test_etag.py`)
- pagination helpers (`tests/test_pagination.py`)
- async job lifecycle (`tests/test_jobs_202.py`)

CI can simply call `make test` (see `Makefile`) to run the same suite.

## Deployment notes

- Container image builds are defined in `Dockerfile`. `Makefile` exposes `make docker-build` / `make docker-run`.
- `deploy/cloudrun.yaml` and Terraform stubs under `deploy/terraform/` outline how to host the composite service alongside a managed MySQL and per-service VMs.
- Secrets/ENV expectations are documented in `.env.example` and `deploy/secrets.md`.

See `docs/DEMO.md` for an end-to-end script that exercises Sprint 1 capabilities (health checks, aggressive caching, FK enforcement, 202 job confirmation, and merged search).
