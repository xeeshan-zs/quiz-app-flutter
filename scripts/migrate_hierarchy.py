import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import os

# ------------------------------------------------------------------------------
# MIGRATION SCRIPT
# Goal: Refactor hierarchy to SuperAdmin > Admin > Teacher/Student
# ------------------------------------------------------------------------------

SERVICE_ACCOUNT_KEY = 'service_account.json'
SUPER_ADMIN_EMAIL = 'super@lgite.com'

# Configuration for specific migration rule
TARGET_DOMAIN = 'lgite.com'
TARGET_STUDENT_CLASS = '11'
FLUTTER_QUIZ_KEYWORDS = ['Flutter', 'General Knowledge']
FLUTTER_QUIZ_TARGET_CLASS = '11'

def initialize_firebase():
    if not os.path.exists(SERVICE_ACCOUNT_KEY):
        print(f"Error: {SERVICE_ACCOUNT_KEY} not found.")
        return None
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    try:
        firebase_admin.initialize_app(cred)
    except ValueError:
        pass # App already initialized
    return firestore.client()

def main():
    db = initialize_firebase()
    if not db: 
        return

    print("--- Starting Migration ---")
    batch = db.batch()
    batch_count = 0
    
    # 1. Identify Super Admin
    print(f"Finding Super Admin ({SUPER_ADMIN_EMAIL})...")
    super_query = db.collection('users').where('email', '==', SUPER_ADMIN_EMAIL).limit(1).get()
    
    if not super_query:
        print("CRITICAL ERROR: Super Admin not found!")
        return

    super_admin_doc = super_query[0]
    super_admin_uid = super_admin_doc.id
    print(f"Found Super Admin: {super_admin_uid}")

    # 2. Fetch all users
    all_users = list(db.collection('users').stream())
    print(f"fetched {len(all_users)} users.")

    # 3. Process Admins First (to establish them as creators)
    admin_uids = {} # map domain -> admin_uid
    
    admins = [u for u in all_users if u.get('role') == 'admin']
    
    for admin in admins:
        admin_data = admin.to_dict()
        email = admin_data.get('email', '')
        
        # Link Admin to Super Admin
        updates = {
            'createdBy': super_admin_uid,
            'adminId': admin.id, # Admin is their own silo owner
        }
        
        # Extract domain for mapping
        if '@' in email:
            domain = email.split('@')[1]
            admin_uids[domain] = admin.id
            print(f"  Mapped domain @{domain} to Admin {email}")
            
        print(f"  Updating Admin: {email}")
        batch.update(admin.reference, updates)
        batch_count += 1

    # 4. Process Teachers and Students
    others = [u for u in all_users if u.get('role') in ['teacher', 'student']]
    
    for user in others:
        user_data = user.to_dict()
        email = user_data.get('email', '')
        role = user_data.get('role')
        
        updates = {}
        
        # Assign Hierarchy
        domain = email.split('@')[1] if '@' in email else None
        
        creator_id = super_admin_uid # Default fallback
        admin_id = super_admin_uid   # Default fallback
        
        if domain and domain in admin_uids:
            creator_id = admin_uids[domain]
            admin_id = admin_uids[domain]
        else:
            print(f"  WARN: No Admin found for domain @{domain} (User: {email}). Defaulting to Super Admin.")

        updates['createdBy'] = creator_id
        updates['adminId'] = admin_id
        
        # Disable if created by default fallback (Super Admin) - Optional based on "deactivate others" rule
        # But user said "assign users to each admin according to their email domain"
        
        # Special Rule: Students of lgite.com get Class 11
        if role == 'student' and domain == TARGET_DOMAIN:
            current_metadata = user_data.get('metadata', {})
            current_metadata['classLevel'] = TARGET_STUDENT_CLASS
            updates['metadata'] = current_metadata
            print(f"  Student {email} -> Class {TARGET_STUDENT_CLASS}")

        batch.update(user.reference, updates)
        batch_count += 1
        
        if batch_count >= 400:
            batch.commit()
            batch = db.batch()
            batch_count = 0

    # 5. Process Quizzes (Find Flutter Quiz)
    print("Scanning Quizzes...")
    quizzes = list(db.collection('quizzes').stream())
    
    for quiz in quizzes:
        q_data = quiz.to_dict()
        title = q_data.get('title', '')
        creator_uid = q_data.get('createdByUid', '')
        
        updates = {}
        
        # Determine Admin ID owner
        # We need to look up the creator
        # Optimization: We could cache user map, but for small DB, fetch is okay or just map known ones
        # For now, let's assume we can fetch the user doc quickly or use our local list
        creator_doc = next((u for u in all_users if u.id == creator_uid), None)
        
        if creator_doc:
            c_data = creator_doc.to_dict()
            # If creator is Admin, use their ID. If Teacher, we need their adminId (which we just set or is missing)
            # Since we just batch updated users, we might rely on the logic we just ran:
            c_email = c_data.get('email', '')
            c_domain = c_email.split('@')[1] if '@' in c_email else ''
            
            if c_domain in admin_uids:
                updates['adminId'] = admin_uids[c_domain]
            else:
                updates['adminId'] = super_admin_uid
        
        # Special Quiz Rule
        if any(k.lower() in title.lower() for k in FLUTTER_QUIZ_KEYWORDS):
             updates['classLevel'] = FLUTTER_QUIZ_TARGET_CLASS
             print(f"  Quiz '{title}' assigned to Class {FLUTTER_QUIZ_TARGET_CLASS}")
        
        if updates:
             batch.update(quiz.reference, updates)
             batch_count += 1
             
        if batch_count >= 400:
            batch.commit()
            batch = db.batch()
            batch_count = 0

    if batch_count > 0:
        batch.commit()
        
    print("--- Migration Complete ---")

if __name__ == "__main__":
    main()
