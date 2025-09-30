from fastapi import FastAPI
from datetime import datetime

app = FastAPI(title="D8 Backend API Test", version="1.0.0")

@app.get("/")
def root():
    return {"message": "D8 Backend API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().timestamp()}

@app.get("/test")
def test_endpoint():
    return {"test": "success", "message": "Backend is working!"}

if __name__ == "__main__":
    import uvicorn
    print("Starting D8 Backend API Test...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
