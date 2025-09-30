#!/usr/bin/env python3
"""
Test script for D8 Backend API
This script helps you test and improve the backend recommendations
"""

import requests
import json
import os
from datetime import datetime, timedelta

# Backend URL
BACKEND_URL = "https://dbbackend-production-2721.up.railway.app"

def test_health():
    """Test the health endpoint"""
    print("🔍 Testing health endpoint...")
    try:
        response = requests.get(f"{BACKEND_URL}/health")
        if response.status_code == 200:
            print("✅ Health check passed:", response.json())
            return True
        else:
            print("❌ Health check failed:", response.status_code)
            return False
    except Exception as e:
        print("❌ Health check error:", e)
        return False

def test_recommendations():
    """Test the recommendations endpoint with different scenarios"""
    print("\n🍽️ Testing recommendations endpoint...")
    
    # Test scenarios
    test_cases = [
        {
            "name": "Romantic Dinner - Italian",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["dinner"],
                "price_range": "high",
                "cuisines": ["italian"],
                "date": (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        },
        {
            "name": "Casual Lunch - Mexican",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["lunch"],
                "price_range": "low",
                "cuisines": ["mexican"],
                "date": (datetime.now() + timedelta(days=3)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        },
        {
            "name": "Luxury Date - French",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["dinner"],
                "price_range": "luxury",
                "cuisines": ["french"],
                "date": (datetime.now() + timedelta(days=14)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        },
        {
            "name": "Breakfast Date - American",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["breakfast"],
                "price_range": "medium",
                "cuisines": ["american"],
                "date": (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n--- Test Case {i}: {test_case['name']} ---")
        
        try:
            response = requests.post(
                f"{BACKEND_URL}/recommendations",
                json=test_case['data'],
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                data = response.json()
                recommendations = data.get('recommendations', [])
                print(f"✅ Success! Found {len(recommendations)} recommendations")
                
                # Show top 3 recommendations
                for j, rec in enumerate(recommendations[:3], 1):
                    print(f"  {j}. {rec['name']} - {rec['cuisine']} - {rec['price_level']}")
                    print(f"     Match Score: {rec['match_score']:.2f}")
                    print(f"     Description: {rec['description'][:100]}...")
                    print()
                
                # Analyze the results
                analyze_recommendations(recommendations, test_case['data'])
                
            else:
                print(f"❌ Failed with status {response.status_code}")
                print(f"Response: {response.text}")
                
        except Exception as e:
            print(f"❌ Error: {e}")

def analyze_recommendations(recommendations, request_data):
    """Analyze the quality of recommendations"""
    if not recommendations:
        print("⚠️ No recommendations returned")
        return
    
    # Check cuisine match
    requested_cuisines = [c.lower() for c in request_data.get('cuisines', [])]
    cuisine_matches = sum(1 for rec in recommendations if rec['cuisine'] in requested_cuisines)
    print(f"📊 Cuisine matches: {cuisine_matches}/{len(recommendations)}")
    
    # Check price range match
    requested_price = request_data.get('price_range')
    if requested_price:
        price_matches = sum(1 for rec in recommendations if rec['price_level'] == requested_price)
        print(f"💰 Price range matches: {price_matches}/{len(recommendations)}")
    
    # Check match scores
    avg_score = sum(rec['match_score'] for rec in recommendations) / len(recommendations)
    print(f"⭐ Average match score: {avg_score:.2f}")
    
    # Check if we have variety
    cuisines = set(rec['cuisine'] for rec in recommendations)
    print(f"🍽️ Cuisine variety: {len(cuisines)} different cuisines")

def test_different_locations():
    """Test with different locations"""
    print("\n🌍 Testing different locations...")
    
    locations = [
        {"name": "New York", "lat": 40.7128, "lon": -74.0060},
        {"name": "Los Angeles", "lat": 34.0522, "lon": -118.2437},
        {"name": "Chicago", "lat": 41.8781, "lon": -87.6298}
    ]
    
    for location in locations:
        print(f"\n--- Testing {location['name']} ---")
        
        data = {
            "location": location['name'],
            "date_type": "meal",
            "meal_times": ["dinner"],
            "price_range": "medium",
            "cuisines": ["italian", "french"],
            "date": (datetime.now() + timedelta(days=5)).strftime("%Y-%m-%d"),
            "latitude": location['lat'],
            "longitude": location['lon']
        }
        
        try:
            response = requests.post(
                f"{BACKEND_URL}/recommendations",
                json=data,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Found {len(result.get('recommendations', []))} recommendations")
            else:
                print(f"❌ Failed: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Error: {e}")

def test_edge_cases():
    """Test edge cases and error handling"""
    print("\n🧪 Testing edge cases...")
    
    edge_cases = [
        {
            "name": "No cuisines specified",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["dinner"],
                "price_range": "medium",
                "cuisines": [],
                "date": (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        },
        {
            "name": "No price range specified",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["lunch"],
                "price_range": None,
                "cuisines": ["mexican"],
                "date": (datetime.now() + timedelta(days=2)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        },
        {
            "name": "Multiple meal times",
            "data": {
                "location": "San Francisco",
                "date_type": "meal",
                "meal_times": ["breakfast", "lunch", "dinner"],
                "price_range": "high",
                "cuisines": ["american", "italian"],
                "date": (datetime.now() + timedelta(days=3)).strftime("%Y-%m-%d"),
                "latitude": 37.7749,
                "longitude": -122.4194
            }
        }
    ]
    
    for case in edge_cases:
        print(f"\n--- {case['name']} ---")
        
        try:
            response = requests.post(
                f"{BACKEND_URL}/recommendations",
                json=case['data'],
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Success: {len(result.get('recommendations', []))} recommendations")
            else:
                print(f"❌ Failed: {response.status_code} - {response.text}")
                
        except Exception as e:
            print(f"❌ Error: {e}")

def main():
    """Run all tests"""
    print("🚀 D8 Backend Testing Suite")
    print("=" * 50)
    
    # Test health
    if not test_health():
        print("❌ Backend is not healthy. Exiting.")
        return
    
    # Test recommendations
    test_recommendations()
    
    # Test different locations
    test_different_locations()
    
    # Test edge cases
    test_edge_cases()
    
    print("\n✅ Testing complete!")
    print("\n💡 Tips for improving the backend:")
    print("1. Check the AI prompt in filter_with_ai() function")
    print("2. Adjust the scoring algorithm in the backend")
    print("3. Add more mock data for different locations")
    print("4. Implement actual OpenStreetMap API integration")
    print("5. Add logging to see what the AI is actually doing")

if __name__ == "__main__":
    main()