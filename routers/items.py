from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from httpx import AsyncClient

from config import Settings
from deps import get_http_client, get_settings_from_app
from etag import strong_etag_bytes
from http_client import copy_headers, request_with_retry

router = APIRouter(prefix="/items", tags=["items"])


@router.get("")
async def list_items(
    request: Request,
    page_size: Optional[int] = Query(default=None, alias="pageSize"),
    page_token: Optional[str] = Query(default=None, alias="pageToken"),
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    size = settings.clamp_page_size(page_size)
    params = dict(request.query_params)
    params["pageSize"] = size
    if page_token:
        params["pageToken"] = page_token

    upstream = await request_with_retry(
        client,
        "GET",
        f"{settings.catalog_svc_base}/catalog/items",
        params=params,
        retries=settings.http_retries,
    )
    upstream.raise_for_status()
    etag = upstream.headers.get("etag") or strong_etag_bytes(upstream.content)
    response = Response(
        content=upstream.content,
        media_type=upstream.headers.get("content-type", "application/json"),
        status_code=upstream.status_code,
    )
    response.headers["ETag"] = etag
    copy_headers(upstream.headers, response.headers, allow=["Cache-Control", "Next-Page-Token"])
    return response


@router.get("/{item_id}")
async def get_item(
    item_id: str,
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    upstream = await request_with_retry(
        client,
        "GET",
        f"{settings.catalog_svc_base}/catalog/items/{item_id}",
        retries=settings.http_retries,
    )
    if upstream.status_code == 404:
        raise HTTPException(status_code=404, detail="Item not found")
    upstream.raise_for_status()
    etag = upstream.headers.get("etag") or strong_etag_bytes(upstream.content)
    response = Response(
        content=upstream.content,
        media_type=upstream.headers.get("content-type", "application/json"),
        status_code=upstream.status_code,
    )
    response.headers["ETag"] = etag
    copy_headers(upstream.headers, response.headers, allow=["Cache-Control", "Last-Modified"])
    return response
