import base64
import datetime
import sqlite3
import unicodedata
import os
import re
from sqlite3 import IntegrityError
import numpy as np
import pandas as pd
from flask import Flask, json, render_template, request, jsonify, session
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from flask_sqlalchemy import SQLAlchemy
from simplegmail import Gmail
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sentence_transformers import SentenceTransformer, util
from groq import Groq
from proceed import Summarizer
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_core.documents import Document
from dotenv import load_dotenv
from datetime import datetime
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine, text
from flask import send_from_directory
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()
app = Flask(__name__)
app.secret_key = os.urandom(24)
CORS(app)
bcrypt = Bcrypt(app)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///app.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)


class ProcessedEmail(db.Model):
    id = db.Column(db.String(255), primary_key=True) 
    sender = db.Column(db.String(255), nullable=False)
    subject = db.Column(db.String(512), nullable=True)
    date = db.Column(db.String(255), nullable=False)
    summary = db.Column(db.Text, nullable=True)
    matches = db.Column(db.JSON, nullable=True)
    status = db.Column(db.String(20), nullable=False, default="Pending")
    authority_name = db.Column(db.String(255), nullable=False, default="None")  # New field

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(100), nullable=False)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)  # Store hashed password

    def set_password(self, password):
        """Hash password before storing it"""
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        """Check if the password matches the stored hash"""
        return check_password_hash(self.password_hash, password)

class Authority(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)  # Rename to password_hash
    state = db.Column(db.String(50), nullable=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class UserComplaint(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    from_user = db.Column(db.String(255), nullable=False)
    subject = db.Column(db.String(255), nullable=False)
    date = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), nullable=False, default='pending')

class ResolvedComplaint(db.Model):
    id = db.Column(db.String(255), primary_key=True) 
    sender = db.Column(db.String(255), nullable=False)
    subject = db.Column(db.String(512), nullable=True)
    date = db.Column(db.String(255), nullable=False)
    summary = db.Column(db.Text, nullable=True)
    matches = db.Column(db.JSON, nullable=True)
    status = db.Column(db.String(50))
    authority_name = db.Column(db.String(255))

class Report(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(200), nullable=False)
    time = db.Column(db.String(100), nullable=False)
    image_url = db.Column(db.String(255),nullable=True)

    def __repr__(self):
        return f'<Complaint {self.title}>'
    
with app.app_context():
    db.create_all()

gmail = Gmail()

file_path = "BNS_off.xlsx"
df = pd.read_excel(file_path, sheet_name="Sheet1")
df = df[df['chapter'] != 1]
df["combined_text"] = df["title"] + " " + df["description"] + " " + df["keywords"]
df['section'] = df['section'].astype(str).str.strip().str.lower()
df['section'] = df['section'].apply(lambda x: unicodedata.normalize('NFKC', x))
# ✅ Initialize NLP Models
tfidf_vectorizer = TfidfVectorizer(stop_words="english")
tfidf_matrix = tfidf_vectorizer.fit_transform(df["combined_text"])
sbert_model = SentenceTransformer("all-MiniLM-L6-v2")
# ✅ Groq AI for Summarization
API_KEY = "your_api_key"
client = Groq(api_key=API_KEY)
# ✅ Process Emails Storage
processed_emails = []
# -----------------------------
# ✅ Functions
# -----------------------------
def classify_email(user_message):
    """Classifies whether an email is a legal complaint or not."""
    classification = client.chat.completions.create(
        model="llama3-70b-8192",
        messages=[
            {
                "role": "user",
                "content": (
                    "Classify the following email as either 'legal complaint' or 'Other'.\n"
                    "Only output the classification without any explanation.\n"
                    f"Email: {user_message}"
                )
            }
        ],
        temperature=0.2,  # Higher accuracy for classification
        max_tokens=10,
        top_p=1,
        stream=False,
    )
    return classification.choices[0].message.content.strip()


def summarize_legal(user_message):
    """Generates a concise legal summary and precise legal keywords for matching with Bharatiya Nyaya Sanhita sections."""
    completion = client.chat.completions.create(
        model="llama3-70b-8192",  
        messages=[
            {
                "role": "user",
                "content": (
                    "Analyze the following complaint and provide: \n"
                    "1. Summary: A concise summary that reflects the core of the user's query.\n"
                    "2. Inferred legal terms: Provide only the most relevant legal keywords (5 atleast) that accurately match Bharatiya Nyaya Sanhita section wordings and can guide the complainee's next steps.\n"
                    "Output only the summary and inferred legal terms without additional explanations.\n\n"
                    "Output is formatted as 'Inferred legal terms' then 'Summary'"
                    f"{user_message}"
                )
            }
        ],
        temperature=0.3,  # Ensures fact-based accuracy
        max_tokens=300,
        top_p=1,
        stream=False,  
    )
    return completion.choices[0].message.content

def split_legal_output(response_text):
    # Handle case when response doesn't contain expected format
    if "Summary:" not in response_text:
        # Try to extract terms if they exist
        if "Inferred legal terms:" in response_text:
            legal_terms_section = response_text.replace("Relevant legal terms:", "").strip()
            legal_terms = [term.strip() for term in legal_terms_section.split("\n") if term.strip()]
            return legal_terms, ""
        else:
            # If no structured format, return the whole text as summary
            return [], response_text.strip()
    parts = response_text.split("Summary:")
    legal_terms_section = parts[0].replace("Inferred legal terms:", "").strip()
    legal_terms = [term.strip() for term in legal_terms_section.split("\n") if term.strip()]
    summary = parts[1].strip() if len(parts) > 1 else ""
    return legal_terms, summary


class LegalAssistant:
    def __init__(self, excel_file_path, api_key):
        self.excel_file_path = excel_file_path
        self.api_key = api_key
        self.client = Groq(api_key=self.api_key)
        self.embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
        self.load_data()

    def load_data(self):
        """Load legal data and create vector store using FAISS."""
        df = pd.read_excel(self.excel_file_path, engine='openpyxl')
        documents = []

        for idx, row in df.iterrows():
            content = " ".join([f"{col}: {str(val) if not pd.isna(val) else ''}" for col, val in row.items()])
            documents.append(Document(page_content=content, metadata={"source": f"legal_entry_{idx}"}))

        print(f"Loaded {len(documents)} legal entries.")

        # Split documents for vectorization
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        chunks = text_splitter.split_documents(documents)

        # Store vectors using FAISS
        self.vector_store = FAISS.from_documents(chunks, self.embeddings)
        print("Vector store created.")

    def retrieve_context(self, query, k=10):
        """Retrieve relevant legal context from the vector store."""
        docs = self.vector_store.similarity_search(query, k=k)
        return "\n\n".join([doc.page_content for doc in docs])

    def generate_response(self, query):
        """Generate legal response using LLaMA with Groq."""
        context = self.retrieve_context(query)

        system_prompt = """You are a legal assistant providing answers using only the given context.
        Provide exactly 4 most relevant legal sections.
        Format:
        - [Section 1]
        - [Section 2]
        - [Section 3]
        - [Section 4]
        """

        full_prompt = f"""
        Legal Context:
        {context}

        User's legal question: {query}
        """

        response = self.client.chat.completions.create(
            model="llama3-70b-8192",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": full_prompt}
            ],
            temperature=0.2,
            max_tokens=1024,
        )

        # Parse LLaMA's response
        llama_response = response.choices[0].message.content
        #print("LLaMA Output:", llama_response)

        # Return exactly 4 sections
        sections = [line for line in llama_response.split("\n") if line.strip().startswith("-")]
        return sections[:4]


assistant = LegalAssistant("BNS_off.xlsx", api_key=API_KEY)

# Step 3: Process Emails
def process_unread_emails(min_content_length=50):
    try:
        # Get unread messages
        messages = gmail.get_unread_inbox()

        if not messages:
            print("No emails found in the inbox.")
            return 0

        # Track stats
        skipped_classification = 0
        skipped_length = 0
        new_email_count = 0

        # Preload existing email IDs to avoid duplicate processing
        existing_ids = {email.id for email in ProcessedEmail.query.all()}
        resolved_ids = {complaint.id for complaint in db.session.query(ResolvedComplaint).all()} 

        for message in messages:
            email_id = message.id

            # Skip already processed emails
            if email_id in existing_ids or email_id in resolved_ids:
                continue

            # Extract email content
            email_subject = message.subject if message.subject else ""
            email_body = message.plain if message.plain else ""
            email_text = email_subject + " " + email_body

            if not email_text.strip():
                email_text = "No content"

            # Check minimum content length
            if len(email_text.strip()) < min_content_length and email_text != "No content":
                skipped_length += 1
                continue

            classification = classify_email(email_text)
            if classification.lower() != "legal complaint":
                skipped_classification += 1
                continue

            # Process the email content
            try:
                legal_summary = summarize_legal(email_text) if email_text != "No content" else None
                legal_terms, summary = split_legal_output(legal_summary) if legal_summary else ([], "No content")

                # Get matched IPC sections
                matched_ipc_sections = None
                if summary and summary != "No content":
                    matched_ipc_sections = assistant.generate_response(legal_summary)

                matches = []
                if matched_ipc_sections is not None and len(matched_ipc_sections) > 0:
                    matches = [{"section": section} for section in matched_ipc_sections]
                else:
                    print("No sections matched")

                # Store directly in the database
                new_email = ProcessedEmail(
                    id=email_id,
                    sender=message.sender,
                    subject=email_subject,
                    date=message.date,
                    summary=summary if summary else "No content",
                    matches=matches,
                    status="Pending"
                )
                db.session.add(new_email)
                db.session.commit()
                new_email_count += 1

            except Exception as e:
                print(f"Error processing email content: {e}")
                continue

        print(f"Added {new_email_count} new emails to the database")
        print(f"Skipped {skipped_classification} emails due to content restrictions")
        print(f"Skipped {skipped_length} emails due to minimum content length")
        return new_email_count

    except Exception as e:
        print(f"Error in process_unread_emails: {e}")
        return 0


DATABASE_PATH = 'instance/app.db'
engine = create_engine(f'sqlite:///{DATABASE_PATH}')
Session = sessionmaker(bind=engine)

def process_messages_from_db(min_content_length=50):
    sqlalchemy_session = None
    try:
        sqlalchemy_session = Session()

        # Properly wrap the SQL statement using text()
        query = text("SELECT id, from_user, subject, description, date FROM user_complaint;")
        messages = sqlalchemy_session.execute(query).fetchall()

        if not messages:
            print("No messages found in the database.")
            return 0

        # Track processing stats
        skipped_classification = 0
        skipped_length = 0
        new_email_count = 0

        # Fetch existing email IDs
        existing_ids = {email.id for email in sqlalchemy_session.query(ProcessedEmail).all()}
        resolved_ids = {complaint.id for complaint in sqlalchemy_session.query(ResolvedComplaint).all()}

        for email_id, sender, subject, body, email_date in messages:
            # Skip already processed messages
            if email_id in existing_ids or email_id in resolved_ids:
                continue

            email_subject = subject if subject else ""
            email_body = body if body else ""
            email_text = email_subject + " " + email_body
            email_date = email_date if email_date else ""

            # Skip empty content
            if not email_text.strip():
                email_text = "No content"

            # Check content length
            if len(email_text.strip()) < min_content_length and email_text != "No content":
                skipped_length += 1
                continue

            # Classify email content
            classification = classify_email(email_text)
            if classification.lower() != "legal complaint":
                skipped_classification += 1
                continue

            try:
                # Summarize and match legal sections
                legal_summary = summarize_legal(email_text) if email_text != "No content" else None
                legal_terms, summary = split_legal_output(legal_summary) if legal_summary else ([], "No content")

                # Get matched sections from LLaMA
                matched_ipc_sections = []
                if summary != "No content":
                    matched_ipc_sections = assistant.generate_response(legal_summary)

                # Transform to the expected format
                matches = [{"section": section} for section in matched_ipc_sections] if matched_ipc_sections else []

                # Create and store new entry
                new_email = ProcessedEmail(
                    id=email_id,
                    sender=sender,
                    subject=email_subject,
                    date=email_date,
                    summary=summary if summary else "No content",
                    matches=matches,
                    status="Pending"
                )
                
                sqlalchemy_session.add(new_email)
                sqlalchemy_session.commit()
                new_email_count += 1

            except Exception as e:
                print(f"Error processing message content: {e}")
                sqlalchemy_session.rollback()  # Rollback if error occurs
                continue

        print(f"Added {new_email_count} new messages to the database")
        print(f"Skipped {skipped_length} messages due to minimum content length")
        print(f"Skipped {skipped_classification} messages due to content restrictions")
        return new_email_count

    except Exception as e:
        print(f"Error in process_messages_from_db: {e}")
        return 0

    finally:
        if sqlalchemy_session:
            sqlalchemy_session.close()


# Step 4: Get Section Summary
def get_summary_for_section(section):
    match = re.search(r"Section (\d+\(?\d*\)?)", section)
    
    if not match:
        print("Section number not found")
        return "Invalid section format"

    section_number = match.group(1)  # Extract section number
    print(f"Extracted Section Number: {section_number}")

    # Ensure section_number is found before filtering the DataFrame
    row = df[df['section'] == section_number]

    if not row.empty:
        description = row.iloc[0]['description']
        summarizer = Summarizer()
        return summarizer.summarize(description)
    else:
        return f"No description found for section {section_number}"


# -----------------------------
# ✅ Routes
# ----------------------------

@app.route('/emails', methods=['GET'])
def get_emails():
    """Fetch processed emails from the database, sorted by date (newest first)."""
    # Fetch the remaining processed emails (those not resolved)
    emails = ProcessedEmail.query.order_by(ProcessedEmail.date.desc()).all()
    
    # Format the emails for response
    email_list = [{
        "id": email.id,
        "sender": email.sender,
        "subject": email.subject,
        "date": email.date,
        "summary": email.summary,
        "matches": email.matches,
        "status": email.status,
    } for email in emails]

    return jsonify({"emails": email_list, "count": len(email_list)})


@app.route('/update_status/<email_id>', methods=['POST'])
def update_email_status(email_id):
    """Update the status of an email"""
    email = db.session.get(ProcessedEmail, email_id)
    if not email:
        return jsonify({"error": "Email not found"}), 404

    data = request.json
    new_status = data.get("status")
    authority_name = data.get("authority")  # Use "authority" instead of "authority_name" to match frontend

    valid_statuses = ["Pending", "Forwarded"]
    if new_status not in valid_statuses:
        return jsonify({"error": f"Invalid status. Allowed values: {', '.join(valid_statuses)}"}), 400

    email.status = new_status

    # If status is "Forwarded", update authority_name
    if new_status == "Forwarded":
        if not authority_name:
            return jsonify({"error": "Authority name is required when forwarding"}), 400
        email.authority_name = authority_name  # Store the selected authority name

    db.session.commit()

    # Update status in UserComplaint table if an entry exists
    complaint = UserComplaint.query.filter_by(subject=email.subject, from_user=email.sender).first()
    if complaint:
        complaint.status = new_status
        db.session.commit()

    return jsonify({"message": f"Email {email_id} status updated to {new_status} with authority {authority_name}"}), 200



@app.route('/reload', methods=['GET'])
def reload_emails():
    """Reload emails from both Gmail and SQLite database, then store in the database."""
    email_count_gmail = process_unread_emails()
    email_count_db = process_messages_from_db()  # New function for SQLite

    total_count = email_count_gmail + email_count_db
    return jsonify({
        "success": True,
        "message": f"Processed {total_count} new emails/messages",
        "gmail_count": email_count_gmail,
        "db_count": email_count_db
})

@app.route('/get_summary', methods=['GET'])
def get_summary():
    """Returns summary for a given BNS section."""
    section = request.args.get('section')
    return jsonify({"summary": get_summary_for_section(section)})

@app.route('/debug', methods=['GET'])
def debug_info():
    """Returns debugging info about emails and database."""
    return jsonify({
        "email_count": len(processed_emails),
        "processed_email_subjects": [email["subject"] for email in processed_emails[:5]] if processed_emails else []
    })


# ----------------------
# ✅ ADMIN SIDE ROUTES
#-----------------------

@app.route('/api/admin/login', methods=['POST'])
def login_admin():
    """Handles admin login."""
    data = request.json

    # Hardcoded credentials for testing
    hardcoded_email = "akhil.com"
    hardcoded_password = "5223"

    if data['email'] == hardcoded_email and data['password'] == hardcoded_password:
        return jsonify({"message": "Login successful!"}), 200

    return jsonify({"message": "Invalid credentials"}), 401

# Add a new authority
@app.route('/add_authority', methods=['POST'])
def add_authority():
    data = request.json

    # Validate required fields
    required_fields = ["name", "email", "password", "state"]
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400

    # Hash the password before storing
    hashed_password = generate_password_hash(data["password"])  # Ensure it's a string

    new_authority = Authority(
        name=data["name"],
        email=data["email"],
        password_hash=hashed_password,  # ✅ Corrected field name
        state=data["state"]
    )

    try:
        db.session.add(new_authority)
        db.session.commit()
        return jsonify({"message": "Authority added successfully"}), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": "Authority ID or Email already exists"}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"An error occurred: {str(e)}"}), 500
    
@app.route('/get_authorities', methods=['GET'])
def get_authorities():
    authorities = Authority.query.all()
    return jsonify([
        {
            "id": a.id,
            "name": a.name,
            "email": a.email,
            "state": a.state
        }
        for a in authorities
    ])


# ------------------
# ✅ USER SIDE ROUTES
# ------------------
@app.route('/register_user', methods=['POST'])
def register_user():
    data = request.get_json()
    full_name = data.get('full_name')
    username = data.get('username')
    email = data.get('email')
    password = data.get('password')

    if not full_name or not username or not email or not password:
        return jsonify({'error': 'Please provide all required fields'}), 400

    user_exists = User.query.filter((User.username == username) | (User.email == email)).first()
    if user_exists:
        return jsonify({'error': 'Username or email already exists'}), 400

    # Hash the password before saving
    new_user = User(full_name=full_name, username=username, email=email,)
    new_user.set_password(password)  # Hashing password before storing

    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': 'User registered successfully'}), 201


@app.route('/login_user', methods=['POST'])
def login_user():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': 'Please provide both username and password'}), 400

    # Retrieve user by username
    user = User.query.filter_by(username=username).first()
    
    # Check if user exists and password matches
    if not user or not user.check_password(password):
        return jsonify({'error': 'Invalid username or password'}), 401

    # Save session
    session['username'] = username

    return jsonify({'message': 'Login successful', 'username': username}), 200


@app.route('/verify_user', methods=['POST'])
def verify_user():
    data = request.get_json()
    username = data.get('username')

    user = User.query.filter_by(username=username).first()
    if user:
        return jsonify({'message': 'User verified'}), 200
    else:
        return jsonify({'error': 'User not found'}), 404

@app.route('/reset_password', methods=['POST'])
def reset_password():
    data = request.get_json()
    username = data.get('username')
    new_password = data.get('new_password')

    user = User.query.filter_by(username=username).first()
    if user:
        user.set_password(new_password)  # Hash new password before saving
        db.session.commit()
        return jsonify({'message': 'Password reset successfully'}), 200
    else:
        return jsonify({'error': 'User not found'}), 404
    
@app.route('/register_complaint', methods=['POST'])
def register_complaint():
    data = request.json
    subject = data.get("subject")
    description = data.get("description")
    status = data.get("status", "pending")

    # Get username from session or request header
    from_user = session.get('username') or request.headers.get("Username")

    if not from_user:
        return jsonify({"message": "User not logged in"}), 401  # Unauthorized

    # Get system's current date and time
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if not all([ subject, description]):
        return jsonify({"message": "All fields are required"}), 400

    try:
        new_complaint = UserComplaint(
            from_user=from_user,
            subject=subject,
            description=description,
            status=status,
            date=current_time
        )
        db.session.add(new_complaint)
        db.session.commit()

        return jsonify({"message": "Complaint registered successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500
    
@app.route('/view_user_complaints', methods=['GET'])
def view_user_complaints():
    # Get logged-in username from request headers
    logged_in_user = request.headers.get('Username')

    if not logged_in_user:
        return jsonify({"message": "User not logged in"}), 401  # Unauthorized

    # Filter complaints for the logged-in user
    complaints = UserComplaint.query.filter_by(from_user=logged_in_user).all()

    complaints_data = [
        {
            'id': c.id,
            'from_user': c.from_user,
            'subject': c.subject,
            'description': c.description,
            'status': c.status
        } for c in complaints
    ]

    return jsonify(complaints_data), 200

# ----------------------
# ✅ AUTHORITY SIDE ROUTES
# ----------------------

@app.route('/login_authority', methods=['POST'])
def login_authority():
    data = request.json
    name = data.get('name')
    password = data.get('password')

    authority = Authority.query.filter_by(name=name).first()
    if authority and authority.check_password(password):
        session['authority_name'] = authority.name
        session['authority_id'] = authority.id  # Store in session

        return jsonify({'message': 'Login successful', 'authority_name': authority.name}), 200

    return jsonify({'message': 'Invalid credentials'}), 401



@app.route('/view_authority_complaints', methods=['GET'])
def view_authority_complaints():
    # Get logged-in authority's name from request headers
    authority_name = request.headers.get('Authority-Name')

    if not authority_name:
        return jsonify({"message": "Authority not logged in"}), 401  # Unauthorized

        # Fetch complaints for the authority
    complaints = ProcessedEmail.query.filter_by(authority_name=authority_name).all()

    if not complaints:
        return jsonify({"message": "No complaints found"}), 200

    complaints_data = [
        {
            'id': c.id,
            'sender': c.sender,
            'subject': c.subject,
            'date': c.date,
            'summary': c.summary,  # Email summary
            'matches': json.loads(c.matches) if isinstance(c.matches, str) else c.matches,  # Ensure JSON format
            'status': c.status
        } for c in complaints
    ]

    return jsonify(complaints_data), 200

def track_status_changes():
    conn = sqlite3.connect('instance/app.db')
    cursor = conn.cursor()
    cursor.execute("SELECT id, sender, subject, date, status from resolved_complaint WHERE status = 'resolved'")
    resolved_rows = cursor.fetchall()

    for row_id, email,sub,date, status in resolved_rows:
        send_email(email,sub,date)
        cursor.execute("UPDATE resolved_complaint SET status = 'notified' WHERE id = ?", (row_id,))
        conn.commit()
        conn.close()

# Function to send email notification
def send_email(email,sub,date):
    REPLY_SUBJECT = "Status Update Notification- ALAAS"
    REPLY_BODY = f"Dear User,\n\nYour complaint of \nSUBJECT '{sub}' dated '{date}'\n status has been updated to resolved.\n\nBest Regards,\nLegal Assistant"

    params = {
        "to": email,
        "sender":"alaas072424@gmail.com",
        "subject": REPLY_SUBJECT ,
        "msg_plain": REPLY_BODY,
    }

    message = gmail.send_message(**params)
    print(f"Notification sent to {email}")


@app.route('/update_authority_complaint_status', methods=['PUT'])
def update_authority_complaint_status():
    data = request.get_json()
    new_status = data.get('status')
    authority_name = data.get('authority_name')

    if not new_status or not authority_name:
        return jsonify({'error': 'Missing required fields'}), 400

    # Fetch the ProcessedEmail based on the authority's name
    processed_email = ProcessedEmail.query.filter_by(authority_name=authority_name).first()

    if not processed_email:
        return jsonify({'error': 'Processed email not found'}), 404

    # Update ProcessedEmail status
    processed_email.status = new_status

    # Fetch the related UserComplaint based on the sender's email
    user_complaint = UserComplaint.query.filter_by(from_user=processed_email.sender).first()

    if user_complaint:
        # Update UserComplaint status
        user_complaint.status = new_status

    # Move the complaint to the ResolvedComplaint table
    resolved_complaint = ResolvedComplaint(
        id=processed_email.id,
        sender=processed_email.sender,
        subject=processed_email.subject,
        date=processed_email.date,
        summary=processed_email.summary,
        matches=processed_email.matches,
        status=new_status,
        authority_name=processed_email.authority_name
    )
    db.session.add(resolved_complaint)
   
    # Delete the processed email after saving it to ResolvedComplaint
    db.session.delete(processed_email)

    # Commit all changes
    db.session.commit()
    track_status_changes()
    
    return jsonify({'message': 'Status updated, complaint resolved and moved to ResolvedComplaint table.'})


#------------
# ✅ CHATBOT
#------------
class LegalChatbot:
    def __init__(self, excel_file_path, api_key=None):
        """
        Initialize the legal chatbot using an Excel knowledge base
        """
        self.excel_file_path = "path_of_dataset file BNS_off.xlsx"
        self.api_key = "your_api_key"
        if not self.api_key:
            raise ValueError("Groq API key not found. Please provide an API key.")
        self.client = Groq(api_key=self.api_key)
        self.embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
        self.load_data()

    def load_data(self):
        """Load legal information from Excel and create a vector store."""
        print(f"Loading data from {self.excel_file_path}...")
        try:
            df = pd.read_excel(self.excel_file_path, engine='openpyxl')
        except FileNotFoundError:
            print(f"ERROR: Excel file not found at {self.excel_file_path}")
            return  # Stop loading if the file isn't found
        except Exception as e:
            print(f"Error with openpyxl: {e}")
            try:
                df = pd.read_excel(self.excel_file_path, engine='xlrd')
            except Exception as e2:
                print(f"Error with xlrd: {e2}")
                df = pd.read_excel(self.excel_file_path)

        print(f"Loaded database with {len(df)} rows and {len(df.columns)} columns")

        documents = []
        for idx, row in df.iterrows():
            try:
                clean_row = {}
                for col, val in row.items():
                    if pd.isna(val):
                        clean_row[col] = ""
                    else:
                        try:
                            clean_row[col] = str(val)
                        except UnicodeEncodeError:
                            clean_row[col] = str(val).encode('utf-8', 'replace').decode('utf-8')

                content = " ".join([f"{col}: {clean_val}" for col, clean_val in clean_row.items()])
                documents.append(Document(page_content=content, metadata={"source": f"legal_entry_{idx}"}))
            except Exception as e:
                print(f"Skipping row {idx} due to error: {e}")

        print(f"Created {len(documents)} documents")

        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
        chunks = text_splitter.split_documents(documents)

        print(f"Split into {len(chunks)} chunks")
        self.vector_store = FAISS.from_documents(chunks, self.embeddings)
        print(f"Created vector store with {len(chunks)} chunks")

    def get_relevant_context(self, query, k=5):
        """Retrieve relevant context from the vector store."""
        docs = self.vector_store.similarity_search(query, k=k)
        contexts = [doc.page_content for doc in docs]
        return "\n\n".join(contexts)

    def generate_response(self, query, system_prompt=None):
        """Generate a legal response, returning a list of points."""
        # Check for greetings
        greeting_patterns = [r"\bhello\b", r"\bhi\b", r"\bgreetings\b", r"\bhey\b"]  # Add more if needed
        if any(re.search(pattern, query.lower()) for pattern in greeting_patterns):
            return ["Hello! How can I assist you with your legal questions today?"]

        context = self.get_relevant_context(query)

        if system_prompt is None:
            system_prompt = """You are a helpful legal assistant that provides information based ONLY on the provided context.
            Format your response like this:

            Here is the answer to the user's legal question:

            **[Legal Topic]:**
            - [Point 1]
            - [Point 2]
            ...
            Remember to extract the topic and create points.
            If the context doesn't contain relevant information, reply with "I don't have enough information to address this question. Please consult with a qualified attorney."
            Do not make up legal information or use external knowledge.
            """

        full_prompt = f"""
        Legal Context:
        {context}

        User's legal question: {query}
        """

        chat_completion = self.client.chat.completions.create(
            model="llama3-70b-8192",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": full_prompt}
            ],
            temperature=0.2,
            max_tokens=1024,
        )

        response_text = chat_completion.choices[0].message.content

        # Parse the response and extract the information
        try:
            # Split by lines
            lines = response_text.split('\n')
            points = []
            topic = None

            # Check if the response starts with "Here is the answer to the user's legal question:"
            if lines and "Here is the answer to the user's legal question:" in lines[0]:
                points.append(lines[0])  # Add the introductory line

                # Extract the topic
                for line in lines[1:]:
                    if line.startswith("**"):
                        topic = line.replace("**", "").strip()
                        points.append(f"* {topic}")  # Add the topic

                # Collect other information
                for line in lines[1:]:
                    line = line.strip()
                    if line.startswith("-"):
                        points.append(line.replace("-", "•").strip())
            else:
                return ["I'm sorry, I couldn't understand the response."]


            return points

        except Exception as e:
            print(f"Error parsing response: {e}")
            return ["I encountered an error processing your request."]

# Initialize the chatbot
excel_file = "path_of_dataset_file BNS_off.xlsx"  # ***DOUBLE CHECK THIS PATH***
legal_chatbot = None

try:
    legal_chatbot = LegalChatbot(excel_file)
    print("Legal chatbot initialized successfully!")
except Exception as e:
    print(f"Error initializing legal chatbot: {e}")
    # Print the exception itself for more details
    print(e)
    
@app.route('/ask', methods=['POST'])
def ask():
    if not legal_chatbot:
        return jsonify({"error": "Legal chatbot not initialized properly"}), 500

    data = request.get_json()
    legal_question = data.get('question', '')

    if not legal_question:
        return jsonify({"error": "No legal question provided"}), 400

    try:
        response = legal_chatbot.generate_response(legal_question)
        
        # If response is a list, join it into a single string
        if isinstance(response, list):
            response = " ".join(response)
        
        return jsonify({"response": response})
    except Exception as e:
        return jsonify({"error": f"Error generating response: {str(e)}"}), 500

# -------------------------------
# ✅ EVIDENCE COLLECTION ROUTES
# -------------------------------
@app.route('/complaints', methods=['GET'])
def get_complaints():
    complaints = Report.query.all()
    return jsonify([{
        "id": c.id,
        "title": c.title,
        "description": c.description,
        "location": c.location,
        "time": c.time,
        "image_url": c.image_url
    } for c in complaints])

@app.route('/complaints/<int:id>', methods=['GET'])
def get_complaint(id):
    complaint = Report.query.get_or_404(id)
    image_url = request.host_url.rstrip('/') + complaint.image_url if complaint.image_url else None
    return jsonify({
        "id": complaint.id,
        "title": complaint.title,
        "description": complaint.description,
        "location": complaint.location,
        "time": complaint.time,
        "image_url": image_url
    })

@app.route('/static/images/<path:filename>')
def serve_image(filename):
    return send_from_directory('static/images', filename)

@app.route('/complaints', methods=['POST'])
def create_complaint():
    data = request.json
    try:
        # Decode the base64 encoded image if it exists
        image_data = data.get('image_url')
        image_path = None
        if image_data:
            decoded_image = base64.b64decode(image_data)
            # Save the image to a file
            image_filename = f"{datetime.now().timestamp()}.png"
            image_path = os.path.join("static/images", image_filename)
            os.makedirs(os.path.dirname(image_path), exist_ok=True)  # Ensure directory exists
            with open(image_path, 'wb') as img_file:
                img_file.write(decoded_image)
            image_url = f"/static/images/{image_filename}"  # Relative path for the image
        else:
            image_url = None

        # Ensure time is in the correct format
        time_obj = datetime.fromisoformat(data['time'])

        # Create and save the complaint in the database
        complaint = Report(
            title=data['title'],
            description=data['description'],
            location=data['location'],
            time=time_obj.isoformat(),  # Store as ISO format string
            image_url=image_url  # Store the relative image URL
        )
        db.session.add(complaint)
        db.session.commit()

        return jsonify({
            "message": "Complaint registered successfully!",
            "complaint_id": complaint.id,
            "image_url": request.host_url.rstrip('/') + image_url if image_url else None  # Full URL for the image
        }), 201
    except Exception as e:
        print(f"Error while creating complaint: {e}")
        return jsonify({"message": "Failed to register complaint."}), 400
    

# Run the Flask app
if __name__ == '__main__':
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port, debug=True)
