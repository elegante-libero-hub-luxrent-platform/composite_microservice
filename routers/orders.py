from __future__ import annotations

import asyncio
import time

from fastapi import APIRouter, Depends, Response
from httpx import AsyncClient, Response as HTTPXResponse

from composite.config import Settings
from composite.deps import get_http_client, get_settings_from_app
from composite.error_model import http_error
from composite.etag import combined_etag, strong_etag_bytes
from composite.http import (
    create_sync_client,
    request_with_retry,
    request_with_retry_sync,
)
from composite.models.order_models import OrderCreate

router = APIRouter(prefix="/orders", tags=["orders"])


async def _fetch_in_thread(url: str, settings: Settings) -> HTTPXResponse:
    def _call() -> HTTPXResponse:
        client = create_sync_client(settings)
        try:
            return request_with_retry_sync(
                client, "GET", url, retries=settings.http_retries
            )
        finally:
            client.close()

    return await asyncio.to_thread(_call)


@router.post("", status_code=201)
async def create_order(
    order: OrderCreate,
    response: Response,
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    if not order.userId or not order.itemId:
        raise http_error(
            422, code="FK_VALIDATION_FAILED", message="userId and itemId are required"
        )

    fanout_start = time.perf_counter()
    user_resp, item_resp = await asyncio.gather(
        _fetch_in_thread(f"{settings.user_svc_base}/users/{order.userId}", settings),
        _fetch_in_thread(f"{settings.catalog_svc_base}/items/{order.itemId}", settings),
    )
    fanout_elapsed_ms = int((time.perf_counter() - fanout_start) * 1000)

    if user_resp.status_code == 404:
        raise http_error(
            422, code="FK_USER_NOT_FOUND", message="Referenced user does not exist"
        )
    if item_resp.status_code == 404:
        raise http_error(
            422, code="FK_ITEM_NOT_FOUND", message="Referenced item does not exist"
        )
    user_resp.raise_for_status()
    item_resp.raise_for_status()

    availability_params = {
        "startDate": order.startDate,
        "endDate": order.endDate,
    }
    availability_params = {k: v for k, v in availability_params.items() if v}

    availability_resp = await request_with_retry(
        client,
        "GET",
        f"{settings.catalog_svc_base}/items/{order.itemId}/availability",
        params=availability_params,
        retries=settings.http_retries,
    )
    if availability_resp.status_code == 409:
        raise http_error(
            409,
            code="ITEM_UNAVAILABLE",
            message="Item is not available for the requested window",
        )
    availability_resp.raise_for_status()

    create_resp = await request_with_retry(
        client,
        "POST",
        f"{settings.order_svc_base}/orders",
        json=order.model_dump(exclude_none=True),
        retries=settings.http_retries,
    )
    if create_resp.status_code >= 400:
        if create_resp.status_code == 409:
            raise http_error(
                409,
                code="ORDER_CONFLICT",
                message="Order service rejected the request",
                details=create_resp.json(),
            )
        create_resp.raise_for_status()

    composite_etag = combined_etag(
        [
            user_resp.headers.get("etag"),
            item_resp.headers.get("etag"),
            create_resp.headers.get("etag"),
        ]
    )
    if not composite_etag:
        composite_etag = strong_etag_bytes(create_resp.content)

    payload = create_resp.json()
    response.headers["Location"] = create_resp.headers.get(
        "Location", f"/orders/{payload.get('id', '')}"
    )
    response.headers["ETag"] = composite_etag
    response.headers["X-Composite-Parallel-Ms"] = str(fanout_elapsed_ms)
    response.headers["X-Composite-Fanout"] = "user,item,availability,order"
    response.headers["X-Composite-Threaded"] = "true"
    response.status_code = 201
    return payload


@router.get("/{order_id}")
async def get_order(
    order_id: str,
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    upstream = await request_with_retry(
        client,
        "GET",
        f"{settings.order_svc_base}/orders/{order_id}",
        retries=settings.http_retries,
    )
    if upstream.status_code == 404:
        raise http_error(404, code="ORDER_NOT_FOUND", message="Order not found")
    upstream.raise_for_status()
    response = Response(
        content=upstream.content,
        media_type=upstream.headers.get("content-type", "application/json"),
        status_code=upstream.status_code,
    )
    etag = upstream.headers.get("etag") or strong_etag_bytes(upstream.content)
    response.headers["ETag"] = etag
    return response
