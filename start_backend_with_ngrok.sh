#!/bin/bash

# Start the backend server
echo "Starting D8 Backend..."
cd /Users/tvonkoch/Documents/D8/D8/Backend
python3 main.py &
BACKEND_PID=$!

# Wait for backend to start
sleep 3

# Check if backend is running
if curl -s http://localhost:8000/health > /dev/null; then
    echo "Backend started successfully on localhost:8000"
    
    # Start ngrok tunnel
    echo "Starting ngrok tunnel..."
    ngrok http 8000 --log=stdout &
    NGROK_PID=$!
    
    # Wait for ngrok to start
    sleep 3
    
    # Get the public URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'])")
    
    if [ ! -z "$NGROK_URL" ]; then
        echo "✅ Backend is now accessible at: $NGROK_URL"
        echo "📱 Update your iOS app to use this URL: $NGROK_URL"
        echo ""
        echo "Press Ctrl+C to stop both services"
        
        # Keep the script running
        wait
    else
        echo "❌ Failed to get ngrok URL"
        kill $BACKEND_PID 2>/dev/null
        kill $NGROK_PID 2>/dev/null
        exit 1
    fi
else
    echo "❌ Failed to start backend"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi
