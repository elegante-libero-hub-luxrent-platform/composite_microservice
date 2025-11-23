from contextlib import asynccontextmanager
import uuid

from fastapi import FastAPI, Request

from composite.aggregate import search
from composite.config import get_settings
from composite.http import create_async_client
from composite.routers import health, items, jobs, orders, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    http_client = create_async_client(settings)
    app.state.settings = settings
    app.state.http_client = http_client
    try:
        yield
    finally:
        await http_client.aclose()


app = FastAPI(title="Composite Service", lifespan=lifespan)


@app.middleware("http")
async def add_trace_id(request: Request, call_next):
    trace_id = request.headers.get("X-Trace-Id", str(uuid.uuid4()))
    response = await call_next(request)
    response.headers["X-Trace-Id"] = trace_id
    return response


app.include_router(health.router)
app.include_router(users.router)
app.include_router(items.router)
app.include_router(orders.router)
app.include_router(jobs.router)
app.include_router(search.router)
