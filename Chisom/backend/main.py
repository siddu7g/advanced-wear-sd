from fastapi import FastAPI, UploadFile, File, HTTPException
import csv
import io
import json
import threading
from pubsub import start_subscriber, publish_message

app = FastAPI()

@app.get("/")
def check():
    return {"status": "ok"}

@app.post("/ingest")
async def ingest_data(file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file uploaded")

    filename = file.filename.lower()
    content = await file.read()

    # Handle CSV
    if filename.endswith(".csv"):
        try:
            decoded = content.decode("utf-8")
            csv_reader = csv.DictReader(io.StringIO(decoded))
            rows = list(csv_reader)
            return {
                "status": "received CSV",
                "filename": file.filename,
                "rows": len(rows)
            }
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid CSV file")

    # Handle JSON
    if filename.endswith(".json"):
        try:
            decoded = content.decode("utf-8")
            data = json.loads(decoded)
            count = len(data) if isinstance(data, list) else 1
            return {
                "status": "received JSON",
                "filename": file.filename,
                "records": count
            }
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid JSON file")

    raise HTTPException(
        status_code=400,
        detail="Unsupported file type. Upload CSV or JSON only."
    )

@app.post("/upload")
def upload_data(data: str):
    publish_message(data)
    return {"status": "published", "data": data}

@app.on_event("startup")
def startup_event():
    threading.Thread(target=start_subscriber, daemon=True).start()
