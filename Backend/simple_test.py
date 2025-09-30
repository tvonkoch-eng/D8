#!/usr/bin/env python3
"""
Simple test to check what the current backend expects
"""

import requests
import json

BACKEND_URL = "https://dbbackend-production-2721.up.railway.app"

def test_current_backend():
    print("🔍 Testing current backend structure...")
    
    # Test 1: Check what endpoints exist
    print("\n1. Testing root endpoint:")
    try:
        response = requests.get(f"{BACKEND_URL}/")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"Error: {e}")
    
    # Test 2: Check health endpoint
    print("\n2. Testing health endpoint:")
    try:
        response = requests.get(f"{BACKEND_URL}/health")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"Error: {e}")
    
    # Test 3: Check what the recommendations endpoint expects
    print("\n3. Testing recommendations endpoint with minimal data:")
    try:
        data = {"query": "test"}
        response = requests.post(f"{BACKEND_URL}/recommendations", json=data)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")
    
    # Test 4: Check if there are other endpoints
    print("\n4. Testing other possible endpoints:")
    endpoints = ["/api/recommendations", "/search/locations", "/search/category/restaurant"]
    for endpoint in endpoints:
        try:
            response = requests.get(f"{BACKEND_URL}{endpoint}")
            print(f"{endpoint}: {response.status_code}")
        except Exception as e:
            print(f"{endpoint}: Error - {e}")

if __name__ == "__main__":
    test_current_backend()
