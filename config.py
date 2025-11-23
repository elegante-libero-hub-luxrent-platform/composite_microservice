import os
from dataclasses import dataclass
from functools import lru_cache
from typing import Optional


def _env(key: str, default: str) -> str:
    return os.getenv(key, default).strip()


def _env_float(key: str, default: float) -> float:
    try:
        return float(os.getenv(key, default))
    except (TypeError, ValueError):
        return default


def _env_int(key: str, default: int) -> int:
    try:
        return int(os.getenv(key, default))
    except (TypeError, ValueError):
        return default


@dataclass(frozen=True)
class Settings:
    """Centralized configuration for the composite service."""

    user_svc_base: str
    catalog_svc_base: str
    order_svc_base: str
    http_timeout_seconds: float
    http_retries: int
    thread_timeout_seconds: float
    default_page_size: int
    max_page_size: int
    pagination_token_version: str = "v1"

    def clamp_page_size(self, requested: Optional[int]) -> int:
        if requested is None:
            return self.default_page_size
        return max(1, min(self.max_page_size, requested))


def _build_settings() -> Settings:
    return Settings(
        user_svc_base=_env("USER_SVC_BASE", "http://localhost:7001"),
        catalog_svc_base=_env("CAT_SVC_BASE", "http://localhost:7002"),
        order_svc_base=_env("ORD_SVC_BASE", "http://localhost:7003"),
        http_timeout_seconds=_env_float("HTTP_TIMEOUT_SECONDS", 5.0),
        http_retries=_env_int("HTTP_RETRIES", 2),
        thread_timeout_seconds=_env_float("THREAD_TIMEOUT_SECONDS", 2.0),
        default_page_size=_env_int("DEFAULT_PAGE_SIZE", 20),
        max_page_size=_env_int("MAX_PAGE_SIZE", 100),
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached Settings instance."""

    return _build_settings()
