import asyncio
from typing import Optional

from fastapi import APIRouter, Depends, Query, Response
from httpx import AsyncClient

from config import Settings
from deps import get_http_client, get_settings_from_app
from etag import combined_etag, strong_etag_bytes
from http_client import request_with_retry
from pagination import extract_tokens, merge_tokens

router = APIRouter(tags=["search"])


@router.get("/search")
async def search(
    q: str,
    response: Response,
    page_size: Optional[int] = Query(default=None, alias="pageSize"),
    page_token: Optional[str] = Query(default=None, alias="pageToken"),
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    size = settings.clamp_page_size(page_size)
    per_source_tokens = extract_tokens(page_token)

    async def fetch_items():
        params = {
            "q": q,
            "pageSize": size,
        }
        if token := per_source_tokens.get("items"):
            params["pageToken"] = token
        return await request_with_retry(
            client,
            "GET",
            f"{settings.catalog_svc_base}/catalog/items",
            params=params,
            retries=settings.http_retries,
        )

    async def fetch_orders():
        params = {
            "q": q,
            "pageSize": size,
        }
        if token := per_source_tokens.get("orders"):
            params["pageToken"] = token
        return await request_with_retry(
            client,
            "GET",
            f"{settings.order_svc_base}/orders",
            params=params,
            retries=settings.http_retries,
        )

    items_resp, orders_resp = await asyncio.gather(fetch_items(), fetch_orders())
    items_resp.raise_for_status()
    orders_resp.raise_for_status()

    items_body = items_resp.json()
    orders_body = orders_resp.json()

    merged = []
    for item in items_body.get("items", []):
        merged.append({"source": "catalog", **item})
    for order in orders_body.get("orders", []):
        merged.append({"source": "order", **order})

    merged = merged[:size]
    next_token = merge_tokens(
        {
            "items": items_body.get("nextPageToken"),
            "orders": orders_body.get("nextPageToken"),
        }
    )

    etag = combined_etag(
        [items_resp.headers.get("etag"), orders_resp.headers.get("etag")]
    )
    if not etag:
        etag = strong_etag_bytes(
            (items_resp.content + b"|" + orders_resp.content)
        )
    response.headers["ETag"] = etag
    return {"results": merged, "nextPageToken": next_token, "pageSize": size}
