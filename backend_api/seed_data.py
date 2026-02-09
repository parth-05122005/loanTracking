import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# 1. Initialize Firebase Admin (Same as your main app)
# Make sure 'serviceAccountKey.json' is in the same folder
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

print("🚀 Starting Data Seed...")

# --- DATASETS ---

# 1. Sample Users (Beneficiaries)
users_data = [
    {
        "uid": "user_001",
        "name": "Rajesh Kumar",
        "phone": "+919876543210",
        "district": "Vellore",
        "risk_profile": "low",
        "created_at": datetime.now()
    },
    {
        "uid": "user_002",
        "name": "Anita Desai",
        "phone": "+919876543211",
        "district": "Kanchipuram",
        "risk_profile": "medium",
        "created_at": datetime.now()
    }
]

# 2. Sample Loans (Sanctioned Amounts)
loans_data = [
    {
        "loan_id": "loan_101",
        "beneficiary_uid": "user_001",
        "scheme_name": "PM Mudra Yojana",
        "sanctioned_amount": 50000,
        "balance_amount": 50000,
        "status": "active",
        "approved_category": ["equipment", "raw_material"],
        "disbursement_date": datetime.now()
    },
    {
        "loan_id": "loan_102",
        "beneficiary_uid": "user_002",
        "scheme_name": "Agri-Infrastructure Fund",
        "sanctioned_amount": 100000,
        "balance_amount": 95000, # 5000 already spent
        "status": "active",
        "approved_category": ["machinery", "seeds"],
        "disbursement_date": datetime.now()
    }
]

# 3. Sample Transaction (One existing spending record)
transactions_data = [
    {
        "transaction_id": "tx_555",
        "loan_id": "loan_102",
        "amount": 5000,
        "vendor_name": "Vellore Agro Supplies",
        "category": "seeds",
        "status": "verified", # verified by OCR
        "timestamp": datetime.now(),
        "geo_location": {"lat": 12.9165, "lng": 79.1325} # Vellore coordinates
    }
]

# --- UPLOAD FUNCTION ---

def upload_collection(collection_name, data, id_field):
    collection_ref = db.collection(collection_name)
    for item in data:
        # Use the specific ID (e.g., user_001) as the document ID
        doc_id = item.pop(id_field) 
        collection_ref.document(doc_id).set(item)
        print(f"   ✅ Added {collection_name}: {doc_id}")

# Run Uploads
upload_collection("users", users_data, "uid")
upload_collection("loans", loans_data, "loan_id")
upload_collection("transactions", transactions_data, "transaction_id")

print("🎉 Database seeded successfully!")