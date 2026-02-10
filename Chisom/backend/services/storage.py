from google.cloud import firestore

db = firestore.Client()

def save_data(collection: str, records: list):
    for record in records:
        db.collection(collection).add(record)