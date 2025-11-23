from pydantic import BaseModel
from typing import Optional
class ItemView(BaseModel):
    id: str
    name: str
    brand: str
    pricePerDay: float
    status: str
class Availability(BaseModel):
    available: bool
    reason: Optional[str]=None
