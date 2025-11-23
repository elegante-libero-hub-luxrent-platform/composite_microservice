from fastapi import APIRouter, Depends, HTTPException, Response
from httpx import AsyncClient

from config import Settings
from deps import get_http_client, get_settings_from_app
from http_client import request_with_retry

router = APIRouter(tags=["jobs"])


@router.post("/orders/{order_id}/confirm", status_code=202)
async def confirm_order(
    order_id: str,
    response: Response,
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    upstream = await request_with_retry(
        client,
        "POST",
        f"{settings.order_svc_base}/orders/{order_id}/confirm",
        retries=settings.http_retries,
    )
    if upstream.status_code == 404:
        raise HTTPException(status_code=404, detail="Order not found")
    if upstream.status_code != 202:
        upstream.raise_for_status()

    response.headers["Location"] = upstream.headers.get("Location", "/jobs/unknown")
    return upstream.json()


@router.get("/jobs/{job_id}")
async def get_job_status(
    job_id: str,
    client: AsyncClient = Depends(get_http_client),
    settings: Settings = Depends(get_settings_from_app),
):
    upstream = await request_with_retry(
        client,
        "GET",
        f"{settings.order_svc_base}/jobs/{job_id}",
        retries=settings.http_retries,
    )
    if upstream.status_code == 404:
        raise HTTPException(status_code=404, detail="Job not found")
    upstream.raise_for_status()
    return upstream.json()
