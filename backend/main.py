import os
import json
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional

# LangChain / Gemini imports
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma
from langchain_google_genai import GoogleGenerativeAIEmbeddings, ChatGoogleGenerativeAI
from langchain.prompts import PromptTemplate

app = FastAPI(title="Personalized Medicine API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
DATA_DIR = "data/literature"
CHROMA_DB_DIR = "/tmp/chroma_db" if os.environ.get('FUNCTION_TARGET') or os.environ.get('FUNCTIONS_WORKER_RUNTIME') else "chroma_db"
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

class ChatRequest(BaseModel):
    query: str
    biomarkers: dict

@app.get("/health")
def health_check():
    return {"status": "ok", "message": "Personalized Medicine API is running"}

@app.post("/ingest")
def ingest_documents():
    """Ingests all PDFs from data/literature into the Vector DB."""
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not set")
    
    embeddings = GoogleGenerativeAIEmbeddings(model="models/embedding-001", google_api_key=GEMINI_API_KEY)
    
    docs = []
    if not os.path.exists(DATA_DIR):
        raise HTTPException(status_code=404, detail=f"Directory {DATA_DIR} not found")
        
    for filename in os.listdir(DATA_DIR):
        if filename.endswith(".pdf"):
            try:
                loader = PyPDFLoader(os.path.join(DATA_DIR, filename))
                docs.extend(loader.load())
            except Exception as e:
                print(f"Error loading {filename}: {e}")
            
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    splits = text_splitter.split_documents(docs)
    
    # Create or update VectorDB
    vectorstore = Chroma.from_documents(documents=splits, embedding=embeddings, persist_directory=CHROMA_DB_DIR)
    
    return {"status": "success", "message": f"Ingested {len(docs)} pages into {len(splits)} chunks."}


@app.post("/upload-report")
async def upload_report(file: UploadFile = File(...)):
    """Uploads a blood report (PDF/Image) and extracts biomarkers using Gemini Vision."""
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not set")
        
    content = await file.read()
    import google.generativeai as genai
    import json
    import io
    
    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel('gemini-1.5-pro-latest')
    
    prompt = (
        "Extract all biomarkers from this blood report. Return ONLY a valid JSON object where "
        "keys are biomarker names (e.g., 'Vitamin D') and values are objects with 'value' "
        "(number or string), 'unit' (string), and 'status' (string, e.g., 'High', 'Low', 'Normal'). "
        "Do not include markdown formatting like ```json."
    )
    
    try:
        if file.filename.lower().endswith(".pdf"):
            import PyPDF2
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(content))
            text = ""
            for page in pdf_reader.pages:
                extracted = page.extract_text()
                if extracted:
                    text += extracted + "\n"
            response = model.generate_content([prompt, text])
        else:
            import PIL.Image
            image = PIL.Image.open(io.BytesIO(content))
            response = model.generate_content([prompt, image])
            
        raw_text = response.text.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:-3]
        elif raw_text.startswith("```"):
            raw_text = raw_text[3:-3]
            
        biomarkers = json.loads(raw_text.strip())
        return {"status": "success", "biomarkers": biomarkers}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
def chat_with_advisor(req: ChatRequest):
    """Generates personalized advice using RAG and explains reasoning."""
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not set")
        
    embeddings = GoogleGenerativeAIEmbeddings(model="models/embedding-001", google_api_key=GEMINI_API_KEY)
    vectorstore = Chroma(persist_directory=CHROMA_DB_DIR, embedding_function=embeddings)
    retriever = vectorstore.as_retriever(search_kwargs={"k": 3})
    
    llm = ChatGoogleGenerativeAI(model="gemini-1.5-pro-latest", google_api_key=GEMINI_API_KEY, temperature=0.2)
    
    biomarkers_text = json.dumps(req.biomarkers, indent=2)
    docs = retriever.invoke(req.query + " " + biomarkers_text)
    context = "\n\n".join([f"Source: {doc.metadata.get('source', 'Unknown')} (Page {doc.metadata.get('page', 'Unknown')})\n{doc.page_content}" for doc in docs])
    
    prompt = PromptTemplate.from_template(
        """You are a personalized medicine AI advisor. 
        Given the user's blood report biomarkers and a question, provide evidence-based advice using the provided medical literature context.
        Also, provide an "explanation" (Chain of Thought) detailing why you are giving this advice based on the specific biomarkers.
        
        Biomarkers:
        {biomarkers}
        
        Context (from Medical Books):
        {context}
        
        User Query: {query}
        
        Respond ONLY in valid JSON format with the following keys, without markdown backticks:
        - "advice": The main advice string (markdown supported)
        - "explanation": XAI chain of thought explaining the reasoning
        - "citations": Array of sources cited (strings)
        """
    )
    
    chain = prompt | llm
    
    try:
        res = chain.invoke({
            "biomarkers": biomarkers_text,
            "context": context,
            "query": req.query
        })
        
        import json
        raw_text = res.content.strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:-3]
        elif raw_text.startswith("```"):
            raw_text = raw_text[3:-3]
            
        parsed_response = json.loads(raw_text.strip())
        return {"status": "success", "response": parsed_response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

# Firebase Functions Export
from firebase_functions import https_fn, options
from a2wsgi import ASGIMiddleware
from werkzeug.test import run_wsgi_app

wsgi_app = ASGIMiddleware(app)

@https_fn.on_request(timeout_sec=300, memory=options.MemoryOption.GB_1)
def api(req: https_fn.Request) -> https_fn.Response:
    app_iter, status, headers = run_wsgi_app(wsgi_app, req.environ)
    return https_fn.Response(app_iter, status=status, headers=headers)
