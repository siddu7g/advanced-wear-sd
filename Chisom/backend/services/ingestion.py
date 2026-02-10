from fastapi import UploadFile,HTTPException
import csv
import io
import json

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
            count = len(data) if isinstance(data, list) else 1
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
