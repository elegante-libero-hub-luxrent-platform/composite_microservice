from typing import Optional

from fastapi import APIRouter, Depends, Header, Response
from httpx import AsyncClient

from config import Settings
from deps import get_http_client, get_settings_from_app
from error_model import http_error
from etag import strong_etag_bytes
from http_client import copy_headers, request_with_retry

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/{user_id}")
async def get_user(
    user_id: str,
    if_none_match: Optional[str] = Header(default=None, convert_underscores=False),
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    headers = {}
    if if_none_match:
        headers["If-None-Match"] = if_none_match

    upstream = await request_with_retry(
        client,
        "GET",
        f"{settings.user_svc_base}/users/{user_id}",
        headers=headers,
        retries=settings.http_retries,
    )

    if upstream.status_code == 304:
        return Response(status_code=304)

    if upstream.status_code == 404:
        raise http_error(404, code="USER_NOT_FOUND", message="User not found")

    upstream.raise_for_status()

    etag = upstream.headers.get("etag") or strong_etag_bytes(upstream.content)

    response = Response(
        content=upstream.content,
        media_type=upstream.headers.get("content-type", "application/json"),
        status_code=upstream.status_code,
    )
    response.headers["ETag"] = etag
    copy_headers(
        upstream.headers,
        response.headers,
        allow=["Cache-Control", "Last-Modified"],
    )
    return response
