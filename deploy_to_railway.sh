#!/bin/bash

# D8 Backend Railway Deployment Script
# This script helps deploy the backend to Railway

echo "🚀 Deploying D8 Backend to Railway"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "Backend/main.py" ]; then
    echo "❌ Error: Please run this script from the D8 project root directory"
    exit 1
fi

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Error: Railway CLI is not installed"
    echo "   Install it with: npm install -g @railway/cli"
    echo "   Or visit: https://docs.railway.app/develop/cli"
    exit 1
fi

# Navigate to backend directory
cd Backend

# Check if user is logged in to Railway
if ! railway whoami &> /dev/null; then
    echo "🔐 Please log in to Railway first:"
    railway login
fi

echo "📦 Deploying to Railway..."
railway up

echo "✅ Deployment complete!"
echo "🌐 Your backend should be available at your Railway URL"
