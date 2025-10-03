#!/bin/bash

# D8 Local Backend Startup Script
# This script starts the backend server locally for development

echo "🚀 Starting D8 Local Backend Server"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "Backend/main.py" ]; then
    echo "❌ Error: Please run this script from the D8 project root directory"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed or not in PATH"
    exit 1
fi

# Navigate to backend directory
cd Backend

# Check if requirements are installed
if [ ! -d "venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install/update requirements
echo "📥 Installing Python dependencies..."
pip install -r requirements.txt

# Check for OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
    echo "⚠️  Warning: OPENAI_API_KEY environment variable is not set"
    echo "   Set it with: export OPENAI_API_KEY='your_key_here'"
    echo "   Or add it to your shell profile (.zshrc, .bashrc, etc.)"
    echo "   The app will use fallback ideas without the API key"
fi

# Start the backend server
echo "🌐 Starting backend server on http://localhost:8000"
echo "   Press Ctrl+C to stop the server"
echo ""

python main.py
