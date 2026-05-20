from datetime import datetime
from pydantic import BaseModel, ConfigDict


class NoteCreate(BaseModel):
    title: str
    body: str


class NoteUpdate(BaseModel):
    title: str | None = None
    body: str | None = None


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    body: str
    created_at: datetime
