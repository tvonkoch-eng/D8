from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict
import requests
import openai
import os
from datetime import datetime

app = FastAPI(title="D8 Backend API", version="1.0.0")

# Configure OpenAI
openai.api_key = os.getenv("OPENAI_API_KEY")

class DateRequest(BaseModel):
    query: str
    location: str
    date_type: str
    meal_times: List[str]
    price_range: Optional[str] = None
    cuisines: List[str]
    date: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class PlaceRecommendation(BaseModel):
    name: str
    description: str
    location: dict  # Will contain lat, lon, display_name, place_id, type, importance
    category: str  # Maps to cuisine
    estimated_cost: str  # Maps to price_level
    best_time: str
    why_recommended: str
    ai_confidence: float  # Maps to match_score

class DateResponse(BaseModel):
    recommendations: List[PlaceRecommendation]
    total_found: int
    query_used: str
    processing_time: float

@app.get("/")
def root():
    return {"message": "D8 Backend API is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().timestamp()}

@app.post("/recommendations", response_model=DateResponse)
async def get_date_recommendations(request: DateRequest):
    """
    Get AI-powered date recommendations based on user preferences
    """
    import time
    start_time = time.time()
    
    try:
        print(f"Received request: {request}")  # Debug log
        
        # 1. Search OpenStreetMap for locations
        print("Starting OSM search...")  # Debug log
        places = await search_openstreetmap(request)
        print(f"Found {len(places)} places from OSM")  # Debug log
        
        # 2. Use OpenAI to filter and enhance recommendations
        print("Starting AI filtering...")  # Debug log
        recommendations = await filter_with_ai(places, request)
        print(f"AI filtering complete, {len(recommendations)} recommendations")  # Debug log
        
        # Use the query from the request
        query_used = request.query
        
        processing_time = time.time() - start_time
        
        response = DateResponse(
            recommendations=recommendations,
            total_found=len(recommendations),
            query_used=query_used,
            processing_time=processing_time
        )
        
        print(f"Returning response: {response}")  # Debug log
        return response
        
    except Exception as e:
        print(f"Error in get_date_recommendations: {e}")  # Debug log
        import traceback
        traceback.print_exc()  # Print full stack trace
        raise HTTPException(status_code=500, detail=str(e))

async def search_openstreetmap(request: DateRequest):
    """
    Search OpenStreetMap for places based on location and criteria
    """
    try:
        # Get coordinates for the location
        lat, lon = await get_coordinates(request.location, request.latitude, request.longitude)
        
        # Search OpenStreetMap using Overpass API
        places = await search_osm_places(lat, lon, request)
        
        # If no results, try a broader search
        if not places:
            places = await search_osm_places_broad(lat, lon, request)
        
        # If still no results, use fallback data
        if not places:
            places = generate_fallback_places(lat, lon, request)
        
        return places
        
    except Exception as e:
        print(f"Error searching OpenStreetMap: {e}")
        # Return fallback data on error
        lat = request.latitude or 37.7749  # Default to San Francisco
        lon = request.longitude or -122.4194
        return generate_fallback_places(lat, lon, request)

async def filter_with_ai(places: List[dict], request: DateRequest):
    """
    Use OpenAI to filter and enhance the place recommendations
    """
    if not places:
        return []
    
    # Create a prompt for OpenAI to analyze and score the places
    prompt = f"""
    You are a date recommendation expert. Analyze these restaurants and rank them for a date based on these criteria:
    
    Date Type: {request.date_type}
    Meal Times: {', '.join(request.meal_times)}
    Price Range: {request.price_range or 'Any'}
    Cuisines: {', '.join(request.cuisines)}
    Date: {request.date}
    
    For each restaurant, consider:
    1. How well it matches the cuisine preferences
    2. How appropriate it is for the meal time(s)
    3. How well it fits the price range
    4. How romantic/date-appropriate the atmosphere is
    5. Overall quality and reputation
    
    Rate each place from 0.0 to 1.0 and provide a brief enhanced description.
    
    Restaurants to analyze:
    """
    
    for i, place in enumerate(places):
        prompt += f"\n{i+1}. {place['name']} - {place['cuisine']} - {place['price_level']} - {place.get('description', 'No description')}"
    
    prompt += "\n\nReturn your analysis in this exact JSON format:\n"
    prompt += '{"recommendations": [{"name": "Restaurant Name", "match_score": 0.85, "enhanced_description": "Your enhanced description here"}]}'
    
    try:
        # Use OpenAI to analyze and score the places
        client = openai.OpenAI()
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant that analyzes restaurants for date recommendations. Always respond with valid JSON."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=2000,
            temperature=0.7
        )
        
        # Parse the AI response
        ai_response = response.choices[0].message.content.strip()
        print(f"OpenAI response: {ai_response}")  # Debug log
        
        # Extract JSON from the response (in case there's extra text)
        import json
        import re
        
        # Find JSON in the response
        json_match = re.search(r'\{.*\}', ai_response, re.DOTALL)
        if json_match:
            ai_data = json.loads(json_match.group())
            ai_recommendations = ai_data.get('recommendations', [])
            print(f"Parsed AI recommendations: {len(ai_recommendations)}")  # Debug log
        else:
            print("No JSON found in AI response")  # Debug log
            ai_recommendations = []
        
        # Create a mapping of names to AI scores
        ai_scores = {rec['name']: rec.get('match_score', 0.5) for rec in ai_recommendations}
        ai_descriptions = {rec['name']: rec.get('enhanced_description', '') for rec in ai_recommendations}
        
    except Exception as e:
        print(f"OpenAI error: {e}")
        # Fallback to basic scoring if OpenAI fails
        ai_scores = {}
        ai_descriptions = {}
    
    # Create the final recommendations with AI enhancement
    recommendations = []
    for place in places:
        # Get AI score or calculate basic score
        ai_score = ai_scores.get(place['name'], 0.5)
        enhanced_description = ai_descriptions.get(place['name'], place.get('description', ''))
        
        # Basic scoring based on preferences
        basic_score = 0.3  # Start lower for better differentiation
        
        # Cuisine match (most important)
        if request.cuisines and place['cuisine'] in [c.lower() for c in request.cuisines]:
            basic_score += 0.4
        elif request.cuisines and place['cuisine'] != 'various':
            # Partial match for different cuisines
            basic_score += 0.1
        
        # Price range match
        if request.price_range:
            price_match = {
                'low': ['low'],
                'medium': ['medium'],
                'high': ['high'],
                'luxury': ['luxury']
            }
            if place['price_level'] in price_match.get(request.price_range, []):
                basic_score += 0.2
        
        # Restaurant type bonus
        if place.get('amenity') == 'restaurant':
            basic_score += 0.1
        elif place.get('amenity') in ['cafe', 'bistro']:
            basic_score += 0.05
        
        # Combine AI and basic scores (use more basic scoring if AI failed)
        if ai_scores:
            final_score = (ai_score * 0.7) + (basic_score * 0.3)
        else:
            final_score = basic_score
        
        # Create location object for iOS compatibility
        location_obj = {
            "name": place['name'],
            "display_name": place['address'],
            "lat": place['latitude'],
            "lon": place['longitude'],
            "place_id": hash(place['name'] + str(place['latitude']) + str(place['longitude'])),
            "type": place.get('amenity', 'restaurant'),
            "importance": min(final_score, 1.0)
        }
        
        # Determine best time based on meal times
        best_time = "Anytime"
        if request.meal_times:
            if "breakfast" in request.meal_times:
                best_time = "Morning (8AM-11AM)"
            elif "lunch" in request.meal_times:
                best_time = "Afternoon (12PM-3PM)"
            elif "dinner" in request.meal_times:
                best_time = "Evening (6PM-10PM)"
        
        # Create better why_recommended text
        why_recommended = f"Great for {request.date_type}"
        if place['cuisine'] != 'various':
            why_recommended += f" with {place['cuisine']} cuisine"
        if place.get('amenity') == 'restaurant':
            why_recommended += " in a restaurant setting"
        elif place.get('amenity') in ['cafe', 'bistro']:
            why_recommended += f" in a cozy {place.get('amenity')} atmosphere"
        
        recommendation = PlaceRecommendation(
            name=place['name'],
            description=enhanced_description or place.get('description', ''),
            location=location_obj,
            category=place['cuisine'],
            estimated_cost=place['price_level'],
            best_time=best_time,
            why_recommended=why_recommended,
            ai_confidence=min(final_score, 1.0)
        )
        recommendations.append(recommendation)
    
    # Sort by AI confidence and limit to 10
    recommendations.sort(key=lambda x: x.ai_confidence, reverse=True)
    return recommendations[:10]

# Helper functions for OpenStreetMap integration
async def get_coordinates(location: str, lat: Optional[float], lon: Optional[float]):
    """Get coordinates from location string or use provided coordinates"""
    if lat is not None and lon is not None:
        return lat, lon
    
    # Geocode the location using Nominatim
    try:
        import aiohttp
        async with aiohttp.ClientSession() as session:
            url = f"https://nominatim.openstreetmap.org/search?q={location}&format=json&limit=1"
            headers = {"User-Agent": "D8-Backend/1.0"}
            async with session.get(url, headers=headers) as response:
                if response.status == 200:
                    data = await response.json()
                    if data:
                        return float(data[0]["lat"]), float(data[0]["lon"])
    except Exception as e:
        print(f"Geocoding error: {e}")
    
    # Fallback to San Francisco coordinates
    return 37.7749, -122.4194

async def search_osm_places(lat: float, lon: float, request: DateRequest):
    """Search OpenStreetMap for places using Overpass API"""
    try:
        import aiohttp
        import json
        
        # Build cuisine filter
        cuisine_filter = ""
        if request.cuisines:
            cuisine_list = [f'"{c.lower()}"' for c in request.cuisines]
            cuisine_filter = f'["cuisine"~"{"|".join(cuisine_list)}",i]'
        
        # Overpass query for restaurants and cafes - prioritize restaurants
        query = f"""
        [out:json][timeout:25];
        (
          node["amenity"="restaurant"]{cuisine_filter}(around:1000,{lat},{lon});
          way["amenity"="restaurant"]{cuisine_filter}(around:1000,{lat},{lon});
          relation["amenity"="restaurant"]{cuisine_filter}(around:1000,{lat},{lon});
          node["amenity"~"cafe|bar|bistro"]{cuisine_filter}(around:1000,{lat},{lon});
          way["amenity"~"cafe|bar|bistro"]{cuisine_filter}(around:1000,{lat},{lon});
          relation["amenity"~"cafe|bar|bistro"]{cuisine_filter}(around:1000,{lat},{lon});
        );
        out center meta tags;
        """
        
        async with aiohttp.ClientSession() as session:
            url = "https://overpass-api.de/api/interpreter"
            data = {"data": query}
            headers = {"User-Agent": "D8-Backend/1.0"}
            
            async with session.post(url, data=data, headers=headers) as response:
                if response.status == 200:
                    result = await response.json()
                    return convert_osm_to_places(result.get("elements", []))
    
    except Exception as e:
        print(f"OSM search error: {e}")
    
    return []

async def search_osm_places_broad(lat: float, lon: float, request: DateRequest):
    """Broader search without cuisine filter"""
    try:
        import aiohttp
        
        query = f"""
        [out:json][timeout:25];
        (
          node["amenity"="restaurant"](around:2000,{lat},{lon});
          way["amenity"="restaurant"](around:2000,{lat},{lon});
          relation["amenity"="restaurant"](around:2000,{lat},{lon});
          node["amenity"~"cafe|bar|bistro"](around:2000,{lat},{lon});
          way["amenity"~"cafe|bar|bistro"](around:2000,{lat},{lon});
          relation["amenity"~"cafe|bar|bistro"](around:2000,{lat},{lon});
        );
        out center meta tags;
        """
        
        async with aiohttp.ClientSession() as session:
            url = "https://overpass-api.de/api/interpreter"
            data = {"data": query}
            headers = {"User-Agent": "D8-Backend/1.0"}
            
            async with session.post(url, data=data, headers=headers) as response:
                if response.status == 200:
                    result = await response.json()
                    return convert_osm_to_places(result.get("elements", []))
    
    except Exception as e:
        print(f"Broad OSM search error: {e}")
    
    return []

def convert_osm_to_places(elements):
    """Convert OSM elements to our place format"""
    places = []
    
    for element in elements:
        tags = element.get("tags", {})
        
        # Get coordinates
        lat = element.get("lat")
        lon = element.get("lon")
        
        if not lat or not lon:
            center = element.get("center", {})
            lat = center.get("lat")
            lon = center.get("lon")
        
        if not lat or not lon:
            continue
        
        # Build address
        address_parts = []
        if tags.get("addr:street"):
            address_parts.append(tags["addr:street"])
        if tags.get("addr:housenumber"):
            address_parts.append(tags["addr:housenumber"])
        if tags.get("addr:city"):
            address_parts.append(tags["addr:city"])
        if tags.get("addr:state"):
            address_parts.append(tags["addr:state"])
        if tags.get("addr:postcode"):
            address_parts.append(tags["addr:postcode"])
        
        address = ", ".join(address_parts) if address_parts else tags.get("addr:full", "")
        
        # Map price level
        price_level = "medium"  # Default
        if tags.get("price_level"):
            price_map = {"1": "low", "2": "medium", "3": "high", "4": "luxury"}
            price_level = price_map.get(tags["price_level"], "medium")
        
        # Skip non-restaurant places
        amenity = tags.get("amenity", "")
        if amenity not in ["restaurant", "cafe", "bar", "bistro", "pub"]:
            continue
            
        # Create better description
        description = tags.get("description") or tags.get("note") or ""
        if not description:
            cuisine = tags.get("cuisine", "various")
            amenity_name = amenity.title()
            if cuisine != "various":
                description = f"{cuisine.title()} {amenity_name.lower()}"
            else:
                description = f"Local {amenity_name.lower()}"
        
        place = {
            "name": tags.get("name", "Unnamed Place"),
            "description": description,
            "latitude": float(lat),
            "longitude": float(lon),
            "address": address,
            "cuisine": tags.get("cuisine", "various"),
            "price_level": price_level,
            "rating": None,  # OSM doesn't have ratings
            "phone": tags.get("phone"),
            "website": tags.get("website"),
            "opening_hours": tags.get("opening_hours"),
            "amenities": build_amenities_list(tags),
            "amenity": amenity
        }
        
        places.append(place)
    
    return places

def build_amenities_list(tags):
    """Build amenities list from OSM tags"""
    amenities = []
    
    if tags.get("outdoor_seating") == "yes":
        amenities.append("Outdoor Seating")
    if tags.get("takeaway") == "yes":
        amenities.append("Takeaway")
    if tags.get("delivery") == "yes":
        amenities.append("Delivery")
    if tags.get("wheelchair") == "yes":
        amenities.append("Wheelchair Accessible")
    if tags.get("wifi") == "yes":
        amenities.append("WiFi")
    if tags.get("parking") == "yes":
        amenities.append("Parking")
    if tags.get("smoking") == "no":
        amenities.append("Non-Smoking")
    
    return amenities

def generate_fallback_places(lat: float, lon: float, request: DateRequest):
    """Generate fallback places when OSM search fails"""
    import random
    
    # Sample places with realistic coordinates around the location
    base_places = [
        {
            "name": "Local Bistro",
            "description": "Cozy neighborhood restaurant with seasonal menu",
            "cuisine": "american",
            "price_level": "medium",
            "rating": 4.2,
            "amenities": ["Outdoor Seating", "WiFi", "Takeaway"]
        },
        {
            "name": "Corner Cafe",
            "description": "Friendly cafe serving coffee and light meals",
            "cuisine": "coffee",
            "price_level": "low",
            "rating": 4.0,
            "amenities": ["WiFi", "Takeaway", "Outdoor Seating"]
        },
        {
            "name": "Fine Dining",
            "description": "Upscale restaurant with elegant atmosphere",
            "cuisine": "french",
            "price_level": "luxury",
            "rating": 4.6,
            "amenities": ["Fine Dining", "Wine Pairing", "Valet Parking"]
        },
        {
            "name": "Quick Bites",
            "description": "Fast casual restaurant with diverse menu",
            "cuisine": "american",
            "price_level": "low",
            "rating": 3.8,
            "amenities": ["Takeaway", "Delivery", "Quick Service"]
        },
        {
            "name": "Cozy Bar",
            "description": "Neighborhood bar with craft cocktails",
            "cuisine": "cocktails",
            "price_level": "medium",
            "rating": 4.1,
            "amenities": ["Full Bar", "Outdoor Seating", "WiFi"]
        }
    ]
    
    # Filter by cuisine if specified
    if request.cuisines:
        filtered_places = []
        for place in base_places:
            if any(cuisine.lower() in place["cuisine"].lower() for cuisine in request.cuisines):
                filtered_places.append(place)
        if filtered_places:
            base_places = filtered_places
    
    places = []
    for i, place in enumerate(base_places):
        # Generate realistic coordinates around the location
        distance = random.uniform(200, 2000)  # 200m to 2km
        angle = random.uniform(0, 2 * 3.14159)
        
        # Convert distance to lat/lon offset (rough approximation)
        lat_offset = (distance / 111000) * random.uniform(-1, 1)
        lon_offset = (distance / (111000 * 0.7)) * random.uniform(-1, 1)
        
        place_data = {
            "name": place["name"],
            "description": place["description"],
            "latitude": lat + lat_offset,
            "longitude": lon + lon_offset,
            "address": f"{100 + i * 50} Main St, {request.location}",
            "cuisine": place["cuisine"],
            "price_level": place["price_level"],
            "rating": place["rating"],
            "phone": f"+1 555-{1000 + i:04d}",
            "website": None,
            "opening_hours": "Mo-Su 09:00-22:00",
            "amenities": place["amenities"]
        }
        places.append(place_data)
    
    return places

if __name__ == "__main__":
    import uvicorn
    try:
        print("Starting D8 Backend API...")
        uvicorn.run(app, host="0.0.0.0", port=8000)
    except Exception as e:
        print(f"Failed to start server: {e}")
        import traceback
        traceback.print_exc()
