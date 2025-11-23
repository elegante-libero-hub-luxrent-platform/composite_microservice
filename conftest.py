import os


def pytest_sessionstart(session):  # noqa: D401
    """Configure default downstream base URLs before the app imports settings."""

    os.environ.setdefault("USER_SVC_BASE", "https://users.service.test")
    os.environ.setdefault("CAT_SVC_BASE", "https://catalog.service.test")
    os.environ.setdefault("ORD_SVC_BASE", "https://orders.service.test")

