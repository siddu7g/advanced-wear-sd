from fastapi import APIRouter, UploadFile, File, HTTPException
from services.ingestion import process_file

router = APIRouter(prefix="/ingest", tags = ["ingestion"])

@router.post("/")
async def ingest_data(file: UploadFile = File(...)):
    return await process_file(file)