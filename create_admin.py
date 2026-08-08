import urllib.request
import json
import os

API_KEY = os.environ["FIREBASE_WEB_API_KEY"]
PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "tajer-19289")

email = os.environ["TAJER_ADMIN_EMAIL"]
password = os.environ["TAJER_ADMIN_PASSWORD"]

# 1. Create User
signup_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}"
data = json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode()
req = urllib.request.Request(signup_url, data=data, headers={"Content-Type": "application/json"})

try:
    with urllib.request.urlopen(req) as res:
        response = json.loads(res.read().decode())
        uid = response['localId']
        id_token = response['idToken']
        print(f"Created user {email} with UID {uid}")
except urllib.error.HTTPError as e:
    error_msg = e.read().decode()
    if "EMAIL_EXISTS" in error_msg:
        print(f"User {email} already exists. Logging in...")
        login_url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
        data = json.dumps({"email": email, "password": password, "returnSecureToken": True}).encode()
        req = urllib.request.Request(login_url, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req) as res:
            response = json.loads(res.read().decode())
            uid = response['localId']
            id_token = response['idToken']
    else:
        print(f"Error creating user: {error_msg}")
        exit(1)

# 2. Add to admins collection in Firestore
firestore_url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/admins/{uid}?documentId={uid}"
doc_data = json.dumps({"fields": {"role": {"stringValue": "admin"}, "email": {"stringValue": email}}}).encode()

req2 = urllib.request.Request(firestore_url, data=doc_data, headers={"Content-Type": "application/json", "Authorization": f"Bearer {id_token}"}, method="PATCH")
try:
    with urllib.request.urlopen(req2) as res2:
        print("Successfully added to admins collection in Firestore!")
except urllib.error.HTTPError as e:
    print(f"Error adding to firestore: {e.read().decode()}")
