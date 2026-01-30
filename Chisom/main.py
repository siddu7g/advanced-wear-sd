from fastapi import FastAPI, Request, UploadFile, File
from pydantic import BaseModel
from typing import Optional
import csv
import io

app = FastAPI()

@app.get("/")
def check():
    return {"status": "ok"}

class IngestJSON(BaseModel):
    user_id: str
    hr: int
    timestamp: str
    device_id: str

@app.post("/ingest")
async def ingest_data(request: Request, file: Optional[UploadFile] = File(None)):
    if file:
        content = await file.read()
        decoded = content.decode("utf-8")
        csv_reader = csv.DictReader(io.StringIO(decoded))
        rows = [row for row in csv_reader]

        return {"status": "received CSV", "rows": len(rows)}

    data = await request.json()
    payload = IngestJSON(**data)
    return {"status": "received JSON"}
