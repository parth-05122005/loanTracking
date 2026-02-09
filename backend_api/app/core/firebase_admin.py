# app/core/firebase_admin.py
import firebase_admin
from firebase_admin import credentials, storage, auth

# Path to the service account key file you downloaded
CRED_PATH = "serviceAccountKey.json"

def initialize_firebase():
    """Initializes the Firebase Admin SDK"""
    if not firebase_admin._apps:
        cred = credentials.Certificate(CRED_PATH)
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'YOUR_PROJECT_ID.appspot.com' 
        })
        print("✅ Firebase Admin SDK Initialized")

def verify_token(id_token):
    """Verifies a Firebase ID token sent from Flutter"""
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        print(f"Token verification failed: {e}")
        return None