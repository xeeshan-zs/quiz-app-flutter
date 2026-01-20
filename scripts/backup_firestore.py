import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import json
import os
from datetime import datetime

# Configuration
SERVICE_ACCOUNT_KEY = 'service_account.json'
BACKUP_DIR = 'backups'
COLLECTIONS_TO_BACKUP = [
    'users', 
    'quizzes', 
    'results', 
    'app_settings', 
    'team_members', 
    'settings'
]

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_KEY):
        print(f"Error: {SERVICE_ACCOUNT_KEY} not found.")
        print("Please download it from Firebase Console -> Project Settings -> Service Accounts")
        return None

    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    try:
        app = firebase_admin.initialize_app(cred)
        return firestore.client()
    except ValueError:
        # App already initialized
        return firestore.client()

def backup_collection(db, collection_name, timestamp_dir):
    print(f"Backing up '{collection_name}'...")
    collection_ref = db.collection(collection_name)
    docs = collection_ref.stream()
    
    data = {}
    count = 0
    for doc in docs:
        data[doc.id] = doc.to_dict()
        count += 1
        
    if count > 0:
        filepath = os.path.join(timestamp_dir, f"{collection_name}.json")
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2, default=str)
        print(f"  Saved {count} documents to {filepath}")
    else:
        print(f"  Collection '{collection_name}' is empty or does not exist.")

def main():
    db = initialize_firebase()
    if not db:
        return

    # Create backup directory with timestamp
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    timestamp_dir = os.path.join(BACKUP_DIR, timestamp)
    os.makedirs(timestamp_dir, exist_ok=True)
    
    print(f"Starting backup to: {timestamp_dir}")
    
    for collection in COLLECTIONS_TO_BACKUP:
        backup_collection(db, collection, timestamp_dir)
        
    print("\nBackup completed successfully!")
    print(f"Location: {os.path.abspath(timestamp_dir)}")

if __name__ == "__main__":
    main()
