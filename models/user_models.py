from pydantic import BaseModel
class UserView(BaseModel):
    id: str
    email: str
    tier: str
