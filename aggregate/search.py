import asyncio
import json
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
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
    
    # Process Catalog Response
    items_list = []
    items_token = None
    items_etag = None
    if items_resp.status_code < 400:
        items_body = items_resp.json()
        items_list = items_body.get("items", [])
        items_token = items_body.get("nextPageToken")
        items_etag = items_resp.headers.get("etag")
    
    # Process Order Response
    orders_list = []
    orders_token = None
    orders_etag = None
    if orders_resp.status_code < 400:
        orders_body = orders_resp.json()
        orders_list = orders_body if isinstance(orders_body, list) else orders_body.get("orders", [])
        orders_token = orders_body.get("nextPageToken") if isinstance(orders_body, dict) else None
        orders_etag = orders_resp.headers.get("etag")

    # If both failed with 5xx, raise error
    if items_resp.status_code >= 500 and orders_resp.status_code >= 500:
        raise HTTPException(
            status_code=502,
            detail="Both upstream services (Catalog and Order) are unavailable."
        )

    merged = []
    for item in items_list:
        merged.append({"source": "catalog", **item})
    for order in orders_list:
        merged.append({"source": "order", **order})
    
    merged = merged[:size]
    
    next_token = merge_tokens(
        {
            "items": items_token,
            "orders": orders_token,
        }
    )

    etag = combined_etag(
        [e for e in [items_etag, orders_etag] if e]
    )
    if not etag and merged:
        # Fallback etag
        etag = strong_etag_bytes(json.dumps(merged, sort_keys=True).encode())

    if etag:
        response.headers["ETag"] = etag
    
    return {"results": merged, "nextPageToken": next_token, "pageSize": size}
