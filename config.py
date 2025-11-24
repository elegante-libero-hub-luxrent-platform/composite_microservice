"""Configuration settings for the composite microservice."""
import os
from typing import Optional
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    user_svc_base: str = os.getenv(
        'USER_SVC_BASE',
        'https://microservices1iter2-314897419193.europe-west1.run.app'
    )
    catalog_svc_base: str = os.getenv(
        'CAT_SVC_BASE',
        'https://catalog-and-inventory-service-314897419193.europe-west1.run.app'
    )
    order_svc_base: str = os.getenv(
        'ORD_SVC_BASE',
        'https://order-and-rental-service-314897419193.europe-west1.run.app'
    )
    http_timeout_seconds: float = float(os.getenv('HTTP_TIMEOUT_SECONDS', '5'))
    http_retries: int = int(os.getenv('RETRY_ATTEMPTS', '2'))
    max_page_size: int = int(os.getenv('MAX_PAGE_SIZE', '100'))
    default_page_size: int = int(os.getenv('DEFAULT_PAGE_SIZE', '10'))

    def clamp_page_size(self, size: Optional[int]) -> int:
        """Clamp page size to valid range."""
        if size is None:
            return self.default_page_size
        return min(max(1, size), self.max_page_size)

    class Config:
        """Pydantic configuration."""
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
