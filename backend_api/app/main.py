# app/main.py
from fastapi import FastAPI, HTTPException, Header
from app.core.firebase_admin import initialize_firebase, verify_token
from pydantic import BaseModel

# 1. Initialize Firebase when app starts
initialize_firebase()

app = FastAPI(title="Loan Utilization Tracker API")

class TransactionData(BaseModel):
    loan_id: str
    amount: float
    vendor: str
    image_url: str  # The URL we got from Flutter upload

@app.get("/")
def read_root():
    return {"status": "online", "system": "Track-1 API"}

@app.post("/verify-transaction")
def verify_transaction(
    data: TransactionData, 
    authorization: str = Header(None)
):
    """
    Receives transaction data. 
    1. Verifies User via Firebase Auth Token
    2. Logs the receipt URL (which points to Firebase Storage)
    """
    
    # Check Auth Header
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    
    token = authorization.split(" ")[1]
    user_decoded = verify_token(token)
    
    if not user_decoded:
        raise HTTPException(status_code=401, detail="Invalid Firebase Token")

    uid = user_decoded['uid']
    
    # (Here you would add logic to save to PostgreSQL)
    
    return {
        "status": "success",
        "message": "Transaction verified and logged",
        "user_id": uid,
        "receipt_stored_at": data.image_url
    }

# Run with: uvicorn app.main:app --reload