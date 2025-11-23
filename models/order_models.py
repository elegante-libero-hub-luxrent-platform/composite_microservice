from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class OrderCreate(BaseModel):
    model_config = ConfigDict(extra="allow")

    userId: str = Field(..., min_length=1)
    itemId: str = Field(..., min_length=1)
    startDate: Optional[str] = None
    endDate: Optional[str] = None
    notes: Optional[str] = None
    metadata: Optional[dict[str, Any]] = None


class OrderView(BaseModel):
    model_config = ConfigDict(extra="allow")

    id: str
    status: str
    userId: str
    itemId: str
