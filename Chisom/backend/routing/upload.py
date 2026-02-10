from fastapi import APIRouter
from pubsub import start_subscriber, publish_message

router = APIRouter(prefix="/upload", tags=["pubsub"])
       
@router.post("/upload")
def upload_data(data: str):
    publish_message(data)
    return {"status": "published", "data": data}