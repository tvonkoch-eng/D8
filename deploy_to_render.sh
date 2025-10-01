#!/bin/bash

echo "🚀 Deploying D8 Backend to Render..."

# Check if render CLI is installed
if ! command -v render &> /dev/null; then
    echo "❌ Render CLI not found. Please install it first:"
    echo "   brew install render"
    echo "   Then run: render auth login"
    exit 1
fi

# Check if user is logged in
if ! render auth whoami &> /dev/null; then
    echo "❌ Not logged in to Render. Please run: render auth login"
    exit 1
fi

# Deploy the service
echo "📦 Deploying service..."
cd /Users/tvonkoch/Documents/D8/D8/Backend

# Create a new service
render services create \
  --name "d8-backend" \
  --type "web" \
  --env "python" \
  --plan "free" \
  --build-command "pip install -r requirements.txt" \
  --start-command "python main.py" \
  --region "oregon" \
  --branch "main"

echo "✅ Deployment initiated! Check your Render dashboard for the URL."
echo "📱 Once deployed, update your iOS app with the new backend URL."
