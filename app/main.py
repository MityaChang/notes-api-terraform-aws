import logging
import sys

from fastapi import FastAPI, HTTPException, Depends
from mangum import Mangum
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db, engine, Base
from app.models import Note
from app.schemas import NoteCreate, NoteUpdate, NoteResponse

from pythonjsonlogger import jsonlogger

logger = logging.getLogger()
handler = logging.StreamHandler(sys.stdout)
formatter = jsonlogger.JsonFormatter(
    fmt="%(asctime)s %(levelname)s %(name)s %(message)s"
)
handler.setFormatter(formatter)
logger.handlers = [handler]
logger.setLevel(settings.log_level)

app = FastAPI(title="Notes API", version="1.0.0")

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.post("/notes", response_model=NoteResponse, status_code=201)
def create_note(note: NoteCreate, db: Session = Depends(get_db)):
    db_note = Note(title=note.title, body=note.body)
    db.add(db_note)
    db.commit()
    db.refresh(db_note)
    logger.info("Note created", extra={"note_id": db_note.id})
    return db_note


@app.get("/notes", response_model=list[NoteResponse])
def list_notes(db: Session = Depends(get_db)):
    return db.query(Note).order_by(Note.created_at.desc()).all()


@app.get("/notes/{note_id}", response_model=NoteResponse)
def get_note(note_id: str, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


@app.put("/notes/{note_id}", response_model=NoteResponse)
def update_note(note_id: str, note_update: NoteUpdate, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    if note_update.title is not None:
        note.title = note_update.title
    if note_update.body is not None:
        note.body = note_update.body
    db.commit()
    db.refresh(note)
    logger.info("Note updated", extra={"note_id": note.id})
    return note


@app.delete("/notes/{note_id}", status_code=204)
def delete_note(note_id: str, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    db.delete(note)
    db.commit()
    logger.info("Note deleted", extra={"note_id": note_id})


# Lambda handler
handler = Mangum(app, lifespan="off")
