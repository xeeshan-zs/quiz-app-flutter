import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import json
import os
import sys

# Configuration
SERVICE_ACCOUNT_KEY = 'service_account.json'

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_KEY):
        print(f"Error: {SERVICE_ACCOUNT_KEY} not found.")
        return None

    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    try:
        app = firebase_admin.initialize_app(cred)
        return firestore.client()
    except ValueError:
        return firestore.client()

def restore_collection(db, collection_name, json_path, dry_run=True):
    if not os.path.exists(json_path):
        print(f"Skipping {collection_name}: File not found at {json_path}")
        return

    print(f"Reading {collection_name} from {json_path}...")
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading JSON: {e}")
        return

    batch = db.batch()
    count = 0
    batch_limit = 450 # Firestore batch limit is 500
    
    print(f"Found {len(data)} documents to restore.")
    
    for doc_id, doc_data in data.items():
        doc_ref = db.collection(collection_name).doc(doc_id)
        if not dry_run:
            batch.set(doc_ref, doc_data)
        
        count += 1
        if count >= batch_limit:
            if not dry_run:
                batch.commit()
                batch = db.batch()
            count = 0
            
    if count > 0 and not dry_run:
        batch.commit()

    if dry_run:
        print(f"  [DRY RUN] Would restore {len(data)} documents to '{collection_name}'")
    else:
        print(f"  Successfully restored {len(data)} documents to '{collection_name}'")

def main():
    if len(sys.argv) < 2:
        print("Usage: python restore_firestore.py <path_to_backup_folder> [--live]")
        print("Example: python restore_firestore.py backups/2024-05-20_12-00-00")
        return

    backup_folder = sys.argv[1]
    dry_run = True
    if len(sys.argv) > 2 and sys.argv[2] == '--live':
        dry_run = False
        print("!!! LIVE RESTORE MODE - WRITING TO DATABASE !!!")
        confirm = input("Are you sure? This will overwrite data. (y/n): ")
        if confirm.lower() != 'y':
            print("Aborted.")
            return

    db = initialize_firebase()
    if not db:
        return

    # Restore known collections
    collections = ['users', 'quizzes', 'results', 'app_settings', 'team_members', 'settings']
    
    for col in collections:
        json_file = os.path.join(backup_folder, f"{col}.json")
        restore_collection(db, col, json_file, dry_run=dry_run)

    print("\nRestore process finished.")

if __name__ == "__main__":
    main()
