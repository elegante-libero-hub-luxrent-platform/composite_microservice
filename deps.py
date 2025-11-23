from fastapi import Request

from composite.config import Settings, get_settings


def get_http_client(request: Request):
    client = getattr(request.app.state, "http_client", None)
    if client is None:
        raise RuntimeError("HTTP client not configured on application state")
    return client


def get_settings_from_app(request: Request) -> Settings:
    settings = getattr(request.app.state, "settings", None)
    if settings is None:
        settings = get_settings()
        request.app.state.settings = settings
    return settings

