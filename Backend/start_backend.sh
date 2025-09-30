#!/bin/bash

# D8 Backend Startup Script
echo "Starting D8 Backend..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is not installed. Please install pip3 first."
    exit 1
fi

# Install dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip3 install -r requirements.txt
fi

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: OPENAI_API_KEY environment variable is not set."
    echo "Please set it with: export OPENAI_API_KEY='your_api_key_here'"
    echo "Continuing without OpenAI integration..."
fi

# Start the FastAPI server
echo "Starting FastAPI server on http://localhost:8000"
echo "Press Ctrl+C to stop the server"
python3 main.py
