"""Shared pytest fixtures for the composite service."""

import sys
from pathlib import Path
from typing import Generator

import pytest
from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from composite.app import app


@pytest.fixture(scope="session")
def client() -> Generator[TestClient, None, None]:
    """Return a FastAPI TestClient backed by the real application instance."""
    with TestClient(app) as test_client:
        yield test_client
