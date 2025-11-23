from typing import Any, Optional

from fastapi import HTTPException
from pydantic import BaseModel


class ErrorEnvelope(BaseModel):
    code: str
    message: str
    details: Optional[Any] = None
    traceId: Optional[str] = None

    def as_dict(self) -> dict[str, Any]:
        return self.model_dump(exclude_none=True)


def http_error(
    status_code: int,
    *,
    code: str,
    message: str,
    details: Any | None = None,
    trace_id: str | None = None,
) -> HTTPException:
    envelope = ErrorEnvelope(
        code=code,
        message=message,
        details=details,
        traceId=trace_id,
    )
    return HTTPException(status_code=status_code, detail=envelope.as_dict())
