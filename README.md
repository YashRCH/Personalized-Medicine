# Personalized Medicine AI Advisor

An intelligent, full-stack application designed to provide personalized medical advice and insights. The app combines a cross-platform Flutter frontend with a powerful Python FastAPI backend, utilizing Google's Gemini 1.5 Pro and Retrieval-Augmented Generation (RAG) to analyze medical literature and patient blood reports.

## 🚀 Key Features

*   **Intelligent Chat Interface:** Conversational AI that uses medical literature as a context base to answer health-related queries.
*   **Automated Report Parsing:** Upload blood reports (PDF or images), and the backend uses Gemini Vision to automatically extract and structure biomarkers (e.g., Vitamin D, Cholesterol).
*   **Evidence-Based Advice:** Uses a local vector database (ChromaDB) loaded with medical texts to ensure the AI's advice is grounded in actual medical literature.
*   **Explainable AI (XAI):** The AI separates its final advice from its internal chain-of-thought, displaying its reasoning and citations clearly in the UI.

## 🛠️ Tech Stack

### Frontend
*   **Framework:** Flutter (Dart) - Cross-platform UI compilation (Web, Android, iOS).
*   **State & Networking:** `http` for REST API communication.
*   **File Handling:** `file_picker` for cross-platform document and image selection.
*   **Configuration:** `flutter_dotenv` for environment variable management.
*   **Hosting:** Firebase Hosting.

### Backend
*   **API Framework:** FastAPI (Python) - High-performance asynchronous API.
*   **AI & LLM:** Google Generative AI (`gemini-1.5-pro-latest`) via `langchain-google-genai`.
*   **RAG Pipeline:** LangChain for orchestration, RecursiveCharacterTextSplitter for chunking.
*   **Vector Database:** ChromaDB for storing and retrieving document embeddings.
*   **Document Processing:** `PyPDF2` (PDF extraction) and `Pillow` (Image processing).
*   **Serverless Adapter:** `a2wsgi` and `werkzeug` to adapt the ASGI FastAPI app for Firebase Cloud Functions.

## 📁 Project Structure

```text
.
├── backend/                  # Python FastAPI Backend
│   ├── data/                 # Raw medical literature (PDFs)
│   ├── chroma_db/            # Local Vector Database (Embeddings)
│   ├── main.py               # Main API endpoints and Firebase Function wrapper
│   ├── fetch_literature.py   # Utility script to scrape medical PDFs from Europe PMC
│   ├── requirements.txt      # Python dependencies
│   └── firebase.json         # Firebase Functions deployment config
│
└── frontend/                 # Flutter Web/Mobile App
    ├── lib/                  # Dart source code (UI & Chat Logic)
    ├── pubspec.yaml          # Flutter dependencies
    ├── .env                  # API URL configuration
    └── firebase.json         # Firebase Hosting deployment config
```

## ⚙️ Local Development Setup

### 1. Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Set up environment variables:
   Copy `.env.example` to `.env` and add your Gemini API Key.
   ```env
   GEMINI_API_KEY=your_actual_api_key
   ```
5. Run the development server:
   ```bash
   python main.py
   ```
   *The API will be available at `http://127.0.0.1:8000`*

### 2. Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Set up environment variables:
   Copy `.env.example` to `.env` and configure your local backend URL.
   ```env
   API_URL=http://127.0.0.1:8000
   ```
4. Run the app:
   ```bash
   flutter run -d chrome
   ```

## ☁️ Deployment

### Frontend (Firebase Hosting)
The frontend is pre-configured for Firebase Hosting.
```bash
cd frontend
flutter build web
firebase deploy --only hosting
```

### Backend (Firebase Functions)
The backend is wrapped with a Serverless adapter for Firebase Functions (2nd Gen). 
*Note: Deploying Cloud Functions requires the Firebase Blaze (Pay-as-you-go) plan.*
```bash
cd backend
firebase deploy --only functions
```
Once deployed, update the `frontend/.env` file with your new live `API_URL` and redeploy the frontend.
