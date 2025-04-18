# Automated Legal Assistance and Advisory System (ALAAS)

## 📚 Project Overview
**ALAAS** is an AI-powered web platform designed to automate and streamline the legal assistance process.  
It filters user complaints submitted via email or app, summarizes the content, identifies relevant sections from the **Bharatiya Nyaya Sanhita (BNS)**, and forwards verified complaints to authorities.  
The system integrates Natural Language Processing (NLP), email automation, a virtual legal assistant, and evidence management to make legal help faster, more accessible, and more efficient for both users and legal professionals.

---

## 🎯 Objectives
- Automate the registration, categorization, and forwarding of legal complaints.
- Provide **real-time legal advice** through an integrated virtual assistant.
- Match grievances to **relevant legal sections** from the BNS database.
- Allow users to submit **evidence** (text + images) securely.
- Enable authorities to **track and resolve complaints** easily.

---

## 🛠️ Technologies Used
- **Python**, **Flask** (Backend Framework)
- **NLP Models**:
  - `Sentence Transformers (all-MiniLM-L6-v2)`
  - `Groq LLaMA3-70B` for summarization and classification
- **Databases**:
  - **SQLite** for storing users, complaints, authorities, and reports
- **Libraries**:
  - `SQLAlchemy`, `Flask-CORS`, `Flask-Bcrypt`
  - `scikit-learn`, `simplegmail`, `dotenv`, `langchain`
- **Other Tools**:
  - **FAISS** for semantic search
  - **Hugging Face Embeddings** for document similarity
  - **BeautifulSoup**, **Pandas**, **NumPy**

---

## 📈 Key Features
- **Complaint Registration** via App or Email.
- **Spam Filtering** and **Minimum Length Checks** for incoming emails.
- **NLP-based Summarization** of complaints.
- **Legal Section Matching** using semantic retrieval.
- **User & Authority Login System** with secure password hashing.
- **Admin Dashboard** to manage users, authorities, and cases.
- **Virtual Legal Assistant** for interactive legal help.
- **Image Proof Upload** and **Storage System**.
- **Status Tracking and Notifications** (users notified when cases are resolved).

---

## 🔥 System Modules
- **User Module**:  
  Register complaints, track case status, interact with chatbot.
- **Authority Module**:  
  Login to view, update, and resolve forwarded complaints.
- **Admin Module**:  
  Manage all users, authorities, complaints, and email processing.
- **Chatbot Module**:  
  Provide legal advice based on a pre-trained legal knowledge base.

---

## 🚀 How to Run
1. Clone the repository.
2. Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3. Ensure your **BNS_off.xlsx** (legal database) and **app.db** (SQLite database) are correctly placed.
4. Run the Flask app:
    ```bash
    flask run
    ```
5. Access via `http://localhost:5000`

---

## 📈 Project Results
- Successfully automated email complaint handling and authority assignment.
- Achieved real-time response generation through an AI virtual assistant.
- Provided efficient grievance redressal with **high accuracy** and **secure evidence management**.

---

> **Developed by**: Akhil C J, Avanthika Kakkadan, Deepika P, Hrithika Pradeep  
> **Under the guidance of**: Ms. Divya B (Associate Professor)  
> **Institution**: Vimal Jyothi Engineering College, Kerala, India (2025)

---

---
