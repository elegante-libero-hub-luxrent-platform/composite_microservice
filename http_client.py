import asyncio
import random
from typing import Any, Mapping, MutableMapping, Sequence

import httpx

from config import Settings

DEFAULT_BACKOFF_SECONDS = 0.05


def create_async_client(settings: Settings) -> httpx.AsyncClient:
    """Return a shared AsyncClient honoring repo timeouts."""

    return httpx.AsyncClient(
        timeout=settings.http_timeout_seconds,
        limits=httpx.Limits(max_keepalive_connections=20, max_connections=100),
    )


def create_sync_client(settings: Settings) -> httpx.Client:
    return httpx.Client(
        timeout=settings.http_timeout_seconds,
        limits=httpx.Limits(max_keepalive_connections=10, max_connections=40),
    )


async def request_with_retry(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    *,
    retries: int,
    backoff: float = DEFAULT_BACKOFF_SECONDS,
    **kwargs: Any,
) -> httpx.Response:
    attempt = 0
    while True:
        try:
            response = await client.request(method, url, **kwargs)
        except httpx.RequestError:
            if attempt >= retries:
                raise
            await asyncio.sleep(_backoff_delay(backoff, attempt))
            attempt += 1
            continue

        if response.status_code >= 500 and attempt < retries:
            await asyncio.sleep(_backoff_delay(backoff, attempt))
            attempt += 1
            continue

        return response


def request_with_retry_sync(
    client: httpx.Client,
    method: str,
    url: str,
    *,
    retries: int,
    backoff: float = DEFAULT_BACKOFF_SECONDS,
    **kwargs: Any,
) -> httpx.Response:
    attempt = 0
    while True:
        try:
            response = client.request(method, url, **kwargs)
        except httpx.RequestError:
            if attempt >= retries:
                raise
            _sleep(_backoff_delay(backoff, attempt))
            attempt += 1
            continue

        if response.status_code >= 500 and attempt < retries:
            _sleep(_backoff_delay(backoff, attempt))
            attempt += 1
            continue
        return response


def copy_headers(
    src: Mapping[str, str],
    dest: MutableMapping[str, str],
    *,
    allow: Sequence[str],
) -> None:
    for name in allow:
        value = src.get(name)
        if value is not None:
            dest[name] = value


def _backoff_delay(base: float, attempt: int) -> float:
    jitter = random.uniform(0.0, base)
    return base * (2**attempt) + jitter


def _sleep(seconds: float) -> None:
    """Separate function purely to help with monkeypatching in tests."""

    import time

    time.sleep(seconds)

