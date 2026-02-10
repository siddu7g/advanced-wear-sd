from fastapi import FastAPI, UploadFile, File, HTTPException
import threading
from pubsub import start_subscriber, publish_message
from routing.health import router as health_router
from routing.ingest import router as ingest_router
from routing.upload import router as upload_router


app = FastAPI()

app.include_router(health_router)
app.include_router(ingest_router)
app.include_router(upload_router)

@app.on_event("startup")
def startup_event():
    threading.Thread(target=start_subscriber, daemon=True).start()