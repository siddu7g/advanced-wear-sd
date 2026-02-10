import csv
import io
import json
from fastapi import UploadFile,HTTPException
from services.storage import save_data

async def process_file(file: UploadFile):
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
            save_data("csv_uploads", rows)
            print(f"Received {len(rows)} rows from {file.filename}")
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
            records = data if isinstance(data, list) else [data]
            save_data("json_uploads", records)
            count = len(records)
            print(f"Received {count} records from {file.filename}")
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
