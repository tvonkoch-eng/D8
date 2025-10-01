from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict
import openai
import os
from datetime import datetime
import json
import requests
import random
from image_service import image_service

app = FastAPI(title="D8 Backend API", version="2.0.1")

# Configure OpenAI
openai_api_key = os.getenv("OPENAI_API_KEY")
if openai_api_key:
    openai.api_key = openai_api_key
    print(f"OpenAI API key loaded from environment (length: {len(openai_api_key)})")
    print("OpenAI API key is configured")
else:
    print("Warning: No OpenAI API key found in environment variables")
    print("Available environment variables:")
    for key in sorted(os.environ.keys()):
        if 'openai' in key.lower() or 'api' in key.lower():
            print(f"  {key}: {os.environ[key][:10]}...")

class RestaurantRequest(BaseModel):
    date_type: str
    meal_times: Optional[List[str]] = None
    price_range: str
    cuisines: Optional[List[str]] = None
    activity_types: Optional[List[str]] = None
    activity_intensity: Optional[str] = None
    date: str
    location: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    page: Optional[int] = 1
    
    # User profile data for personalization
    user_id: Optional[str] = None
    user_age_range: Optional[str] = None
    user_relationship_status: Optional[str] = None
    user_hobbies: Optional[List[str]] = None
    user_budget: Optional[str] = None
    user_cuisines: Optional[List[str]] = None
    user_transportation: Optional[List[str]] = None
    user_favorite_cuisines: Optional[List[str]] = None
    user_preferred_price_range: Optional[str] = None

class RestaurantRecommendation(BaseModel):
    name: str
    description: str
    location: str
    address: str
    latitude: float
    longitude: float
    cuisine_type: str
    price_level: str
    is_open: bool
    open_hours: str
    rating: float
    why_recommended: str
    estimated_cost: str
    best_time: str
    image_url: Optional[str] = None

class RestaurantResponse(BaseModel):
    recommendations: List[RestaurantRecommendation]
    total_found: int
    query_used: str
    processing_time: float

def get_image_url(cuisine_type: str, name: str, location: str = "", latitude: float = None, longitude: float = None) -> str:
    """
    Get enhanced image URL using Foursquare, Pexels, Unsplash, or fallback
    """
    return image_service.get_restaurant_image_url(
        name=name,
        cuisine_type=cuisine_type,
        location=location,
        latitude=latitude,
        longitude=longitude
    )

def reverse_geocode(latitude: float, longitude: float) -> str:
    """
    Convert coordinates to a location name using OpenStreetMap Nominatim API
    """
    try:
        url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={latitude}&lon={longitude}&zoom=10&addressdetails=1"
        headers = {
            'User-Agent': 'D8-Restaurant-App/1.0'
        }
        
        response = requests.get(url, headers=headers, timeout=5)
        if response.status_code == 200:
            data = response.json()
            address = data.get('address', {})
            
            # Try to get city and state/country
            city = address.get('city') or address.get('town') or address.get('village') or address.get('hamlet')
            state = address.get('state') or address.get('county')
            country = address.get('country')
            
            if city and state:
                return f"{city}, {state}"
            elif city and country:
                return f"{city}, {country}"
            elif city:
                return city
            else:
                # Fallback to display name
                return data.get('display_name', 'Unknown Location').split(',')[0]
        else:
            print(f"Reverse geocoding failed with status {response.status_code}")
            return "Unknown Location"
    except Exception as e:
        print(f"Reverse geocoding error: {e}")
        return "Unknown Location"

@app.get("/")
def root():
    return {"message": "D8 Backend API v2.1 - OpenAI Powered with Explore"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().timestamp()}

@app.get("/image-service-status")
def image_service_status():
    """Check the status of all image services"""
    return image_service.get_api_status()

@app.post("/explore", response_model=RestaurantResponse)
async def get_explore_ideas(request: RestaurantRequest):
    """
    Get curated explore ideas for a location and date
    """
    import time
    start_time = time.time()
    
    try:
        print(f"Received explore request: {request}")
        
        # Reject requests with "Unknown Location" - user needs to enable location or connect to WiFi
        if request.location == "Unknown Location":
            print("Rejecting request with Unknown Location")
            processing_time = time.time() - start_time
            
            response = RestaurantResponse(
                recommendations=[],
                total_found=0,
                query_used="Location unavailable - please enable location services or connect to WiFi",
                processing_time=processing_time
            )
            return response
        
        # Check if OpenAI API key is available
        if not openai_api_key:
            print("No OpenAI API key available")
            processing_time = time.time() - start_time
            
            response = RestaurantResponse(
                recommendations=[],
                total_found=0,
                query_used=f"No API key available for explore ideas",
                processing_time=processing_time
            )
            return response
        
        # Create a special explore prompt that generates a mix of restaurants and activities
        prompt = create_explore_prompt(request)
        print(f"Generated explore prompt: {prompt[:200]}...")
        
        # Try to get recommendations from OpenAI
        try:
            all_recommendations = await get_openai_recommendations(prompt, request)
        except Exception as e:
            print(f"OpenAI failed: {e}")
            processing_time = time.time() - start_time
            
            response = RestaurantResponse(
                recommendations=[],
                total_found=0,
                query_used=f"OpenAI API error: {str(e)}",
                processing_time=processing_time
            )
            return response
        
        processing_time = time.time() - start_time
        
        response = RestaurantResponse(
            recommendations=all_recommendations,
            total_found=len(all_recommendations),
            query_used=f"Explore ideas for {request.location}",
            processing_time=processing_time
        )
        
        print(f"Returning {len(all_recommendations)} explore ideas")
        return response
        
    except Exception as e:
        print(f"Error in get_explore_ideas: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/recommendations", response_model=RestaurantResponse)
async def get_restaurant_recommendations(request: RestaurantRequest):
    """
    Get AI-powered restaurant recommendations using OpenAI
    """
    import time
    start_time = time.time()
    
    try:
        print(f"Received request: {request}")
        
        # Reject requests with "Unknown Location" - user needs to enable location or connect to WiFi
        if request.location == "Unknown Location":
            print("Rejecting request with Unknown Location")
            processing_time = time.time() - start_time
            
            response = RestaurantResponse(
                recommendations=[],
                total_found=0,
                query_used="Location unavailable - please enable location services or connect to WiFi",
                processing_time=processing_time
            )
            return response
        
        # Check if OpenAI API key is available
        if not openai_api_key:
            print("No OpenAI API key available")
            processing_time = time.time() - start_time
            
            query_desc = f"{request.date_type}"
            if request.date_type == "meal" and request.meal_times:
                query_desc += f" {request.meal_times[0]}"
            elif request.date_type == "activity" and request.activity_types:
                query_desc += f" {request.activity_types[0]}"
            
            response = RestaurantResponse(
                recommendations=[],
                total_found=0,
                query_used=f"No API key available for {query_desc}",
                processing_time=processing_time
            )
            return response
        
        # Create natural language prompt
        prompt = create_restaurant_prompt(request)
        print(f"Generated prompt: {prompt[:200]}...")
        
        # Try to get recommendations from OpenAI
        try:
            all_recommendations = await get_openai_recommendations(prompt, request)
        except Exception as e:
            print(f"OpenAI failed: {e}")
            processing_time = time.time() - start_time
            
            # Return empty results with error information
            response = RestaurantResponse(
                recommendations=[],
                total_found=0,
                query_used=f"OpenAI API error: {str(e)}",
                processing_time=processing_time
            )
            return response
        
        # Apply pagination
        page = request.page or 1
        items_per_page = 10
        start_index = (page - 1) * items_per_page
        end_index = start_index + items_per_page
        
        recommendations = all_recommendations[start_index:end_index]
        
        processing_time = time.time() - start_time
        
        query_desc = f"{request.date_type}"
        if request.date_type == "meal" and request.meal_times:
            query_desc += f" {request.meal_times[0]}"
        elif request.date_type == "activity" and request.activity_types:
            query_desc += f" {request.activity_types[0]}"
        
        response = RestaurantResponse(
            recommendations=recommendations,
            total_found=len(all_recommendations),
            query_used=f"OpenAI-powered recommendations for {query_desc} (page {page})",
            processing_time=processing_time
        )
        
        print(f"Returning {len(recommendations)} recommendations")
        return response
        
    except Exception as e:
        print(f"Error in get_restaurant_recommendations: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

def create_explore_prompt(request: RestaurantRequest) -> str:
    """
    Create a special prompt for explore ideas that generates a mix of restaurants and activities
    """
    # Format the date
    try:
        date_obj = datetime.strptime(request.date, "%Y-%m-%d")
        formatted_date = date_obj.strftime("%A, %B %d, %Y")
    except:
        formatted_date = request.date
    
    # Get actual location name from coordinates
    actual_location = request.location
    if request.latitude and request.longitude and request.location == "Current Location":
        actual_location = reverse_geocode(request.latitude, request.longitude)
        print(f"Converted coordinates ({request.latitude}, {request.longitude}) to location: {actual_location}")
    
    # Get day of week for context
    try:
        date_obj = datetime.strptime(request.date, "%Y-%m-%d")
        day_of_week = date_obj.strftime("%A")
        is_weekend = date_obj.weekday() >= 5
    except:
        day_of_week = "unknown"
        is_weekend = False
    
    # Determine date context
    date_context = ""
    if is_weekend:
        date_context = "This is a weekend, so consider places that are popular for weekend outings and may have special weekend hours or events."
    else:
        date_context = "This is a weekday, so consider places that offer good value and aren't overly crowded."
    
    prompt = f"""
You are an expert local guide and recommendation specialist with deep knowledge of entertainment, dining, and recreational scenes across major cities. You understand what makes places perfect for dates, considering atmosphere, engagement opportunities, and shared experiences.

CONTEXT & REQUIREMENTS:
- Date: {formatted_date} ({day_of_week})
- Location: {actual_location}
- Purpose: Generate a curated mix of 6 ideas for exploring the area

{date_context}

EXPLORE IDEAS CRITERIA:
Generate a diverse mix of 6 ideas that include:

1. RESTAURANTS (3 ideas):
   - Mix of cuisines and price ranges
   - Different atmospheres (romantic, casual, trendy, hidden gems)
   - Various meal times (breakfast spots, lunch places, dinner venues)
   - Include both well-known and local favorites

2. ACTIVITIES (3 ideas):
   - Mix of indoor and outdoor activities
   - Different energy levels (relaxed, moderate, high-energy)
   - Various categories (cultural, recreational, entertainment, fitness)
   - Include both popular attractions and unique local experiences

RECOMMENDATION CRITERIA:
For each idea, prioritize places that excel in:

1. ATMOSPHERE & EXPERIENCE:
   - Clean, well-maintained facilities
   - Good lighting and comfortable environment
   - Appropriate noise level for conversation
   - Safe and welcoming atmosphere

2. ENGAGEMENT & INTERACTION:
   - Activities that encourage conversation and connection
   - Shared experiences that create memories
   - Interactive elements that both people can enjoy
   - Appropriate challenge level for both participants

3. TIMING & AVAILABILITY:
   - Places available on {formatted_date}
   - Appropriate duration (not too short, not too long)
   - Good timing for the requested context
   - Flexible scheduling options

4. VALUE & PRICING:
   - Fair pricing for the experience provided
   - Good value within the specified price range
   - Transparent pricing with no hidden fees
   - Worth the investment for a date experience

5. LOCATION & ACCESSIBILITY:
   - Safe, well-lit area
   - Easy to find and access
   - Parking or public transportation nearby
   - Good neighborhood reputation

SPECIFIC INSTRUCTIONS:
- Recommend 6 places that are real, well-established establishments
- Focus on places that are actually available on {formatted_date}
- Prioritize places with consistent quality and good reputations
- Include a mix of popular spots and hidden gems
- Ensure variety in types and price ranges
- Include places that locals would recommend to friends
- Consider weather-appropriate activities for the location and season
- Make sure the mix feels balanced and offers something for everyone

For each place, provide detailed, specific information that helps the user make an informed decision.

Return your response as a JSON array with this exact structure:
[
  {{
    "name": "Place Name",
    "description": "Detailed 2-3 sentence description highlighting what makes this place special for dates",
    "location": "Specific neighborhood, City",
    "address": "Full street address with city and state",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "cuisine_type": "italian" or "mexican" or "american" or "japanese" or "chinese" or "indian" or "thai" or "french" or "mediterranean" or "sports" or "outdoor" or "indoor" or "entertainment" or "fitness",
    "price_level": "free/low/medium/high/luxury",
    "is_open": true/false,
    "open_hours": "Specific hours of operation",
    "rating": 4.5,
    "why_recommended": "Detailed explanation of why this place is perfect for exploring and dating",
    "estimated_cost": "Specific cost range per person",
    "best_time": "Optimal time to visit",
    "duration": "Expected duration (e.g., '1-2 hours', '2-3 hours', 'Half day', 'Full day')"
  }}
]

IMPORTANT: 
- Only recommend real, well-known places that actually exist in {actual_location} or nearby areas
- Do not make up places or provide generic recommendations
- Ensure the mix includes both restaurants and activities
- If you don't know specific places in {actual_location}, recommend well-known chains or popular establishments that are likely to exist there
- Focus on places that are commonly found in most cities (restaurants, parks, museums, entertainment venues)
- Use realistic coordinates within the {actual_location} area
"""
    
    return prompt

def create_restaurant_prompt(request: RestaurantRequest) -> str:
    """
    Create a natural language prompt for restaurant or activity recommendations
    """
    # Format the date
    try:
        date_obj = datetime.strptime(request.date, "%Y-%m-%d")
        formatted_date = date_obj.strftime("%A, %B %d, %Y")
    except:
        formatted_date = request.date
    
    # Get actual location name from coordinates
    actual_location = request.location
    if request.latitude and request.longitude and request.location == "Current Location":
        actual_location = reverse_geocode(request.latitude, request.longitude)
        print(f"Converted coordinates ({request.latitude}, {request.longitude}) to location: {actual_location}")
    
    if request.date_type == "activity":
        return create_activity_prompt(request, actual_location, formatted_date)
    else:
        return create_meal_prompt(request, actual_location, formatted_date)

def create_meal_prompt(request: RestaurantRequest, actual_location: str, formatted_date: str) -> str:
    """
    Create a prompt for restaurant recommendations with enhanced context
    """
    # Format meal times
    meal_times_str = ", ".join(request.meal_times) if request.meal_times else "any time"
    
    # Format cuisines
    cuisines_str = ", ".join(request.cuisines) if request.cuisines else "any cuisine"
    
    # Format price range
    price_descriptions = {
        "low": "budget-friendly (under $15 per person)",
        "medium": "moderate pricing ($15-30 per person)", 
        "high": "upscale ($30-60 per person)",
        "luxury": "fine dining ($60+ per person)"
    }
    price_desc = price_descriptions.get(request.price_range, "any price range")
    
    # Get day of week for context
    try:
        date_obj = datetime.strptime(request.date, "%Y-%m-%d")
        day_of_week = date_obj.strftime("%A")
        is_weekend = date_obj.weekday() >= 5
    except:
        day_of_week = "unknown"
        is_weekend = False
    
    # Determine date context
    date_context = ""
    if is_weekend:
        date_context = "This is a weekend date, so consider restaurants that are popular for weekend dining and may have special brunch or dinner menus."
    else:
        date_context = "This is a weekday date, so consider restaurants that offer good value and aren't overly crowded."
    
    # Build user profile context for personalization
    user_context = ""
    if request.user_id:
        user_context = "\nUSER PROFILE & PREFERENCES:\n"
        
        if request.user_age_range:
            user_context += f"- Age Range: {request.user_age_range}\n"
        
        if request.user_relationship_status:
            user_context += f"- Relationship Status: {request.user_relationship_status}\n"
        
        if request.user_hobbies:
            hobbies_str = ", ".join(request.user_hobbies)
            user_context += f"- Hobbies & Interests: {hobbies_str}\n"
        
        if request.user_budget:
            user_context += f"- General Budget Preference: {request.user_budget}\n"
        
        if request.user_cuisines:
            user_cuisines_str = ", ".join(request.user_cuisines)
            user_context += f"- Preferred Cuisines: {user_cuisines_str}\n"
        
        if request.user_favorite_cuisines:
            favorite_cuisines_str = ", ".join(request.user_favorite_cuisines)
            user_context += f"- Favorite Cuisines: {favorite_cuisines_str}\n"
        
        if request.user_transportation:
            transportation_str = ", ".join(request.user_transportation)
            user_context += f"- Transportation: {transportation_str}\n"
        
        user_context += "\nUse this profile information to personalize recommendations that match the user's lifestyle, preferences, and relationship context.\n"

    prompt = f"""
    You are an expert restaurant recommendation specialist with deep knowledge of dining scenes across major cities. You understand the nuances of what makes a perfect date restaurant, considering atmosphere, service, food quality, and romantic appeal.

    CONTEXT & REQUIREMENTS:
    - Date: {formatted_date} ({day_of_week})
    - Location: {actual_location}
    - Date Type: {request.date_type}
    - Meal Time: {meal_times_str}
    - Price Range: {price_desc}
    - Cuisine Preferences: {cuisines_str}

    {user_context}
    {date_context}

RECOMMENDATION CRITERIA:
For this {request.date_type} date, prioritize restaurants that excel in:

1. ATMOSPHERE & AMBIANCE:
   - Romantic lighting and intimate seating
   - Appropriate noise level for conversation
   - Clean, well-maintained interior
   - Good spacing between tables for privacy

2. FOOD QUALITY & EXPERIENCE:
   - Fresh, high-quality ingredients
   - Well-executed dishes that match the cuisine type
   - Appropriate portion sizes for the meal time
   - Menu variety that accommodates different preferences

3. SERVICE & TIMING:
   - Attentive but not intrusive service
   - Reasonable wait times for the requested meal time
   - Staff knowledgeable about the menu
   - Good pacing of courses

4. LOCATION & ACCESSIBILITY:
   - Safe, well-lit area
   - Easy to find and access
   - Parking or public transportation nearby
   - Good neighborhood reputation

5. VALUE & PRICING:
   - Fair pricing for the quality and experience
   - Good value within the specified price range
   - Transparent pricing with no hidden fees

SPECIFIC INSTRUCTIONS:
- Recommend 6-8 restaurants that are real, well-established establishments
- Focus on restaurants that are actually open on {formatted_date} for {meal_times_str}
- Prioritize restaurants with consistent quality and good reputations
- Include a mix of well-known spots and hidden gems
- Consider the specific meal time (breakfast = casual, lunch = business-friendly, dinner = romantic)
- Ensure variety in cuisine types while respecting preferences
- Include restaurants that locals would recommend to friends

For each restaurant, provide detailed, specific information that helps the user make an informed decision.

Return your response as a JSON array with this exact structure:
[
  {{
    "name": "Restaurant Name",
    "description": "Detailed 2-3 sentence description highlighting what makes this restaurant special for dates",
    "location": "Specific neighborhood, City",
    "address": "Full street address with city and state",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "cuisine_type": "Specific cuisine type",
    "price_level": "low/medium/high/luxury",
    "is_open": true/false,
    "open_hours": "Specific hours of operation",
    "rating": 4.5,
    "why_recommended": "Detailed explanation of why this restaurant is perfect for this specific date occasion",
    "estimated_cost": "Specific cost range per person",
    "best_time": "Optimal time to visit for this meal time"
  }}
]

IMPORTANT: Only recommend real, well-known restaurants that actually exist in {actual_location} or nearby areas. Do not make up restaurants or provide generic recommendations.
"""
    
    return prompt

def create_activity_prompt(request: RestaurantRequest, actual_location: str, formatted_date: str) -> str:
    """
    Create a prompt for activity recommendations with enhanced context
    """
    # Format activity types
    activity_types_str = ", ".join(request.activity_types) if request.activity_types else "any activity type"
    
    # Format activity intensity
    intensity_descriptions = {
        "low": "relaxed, easy activities",
        "medium": "moderate effort activities", 
        "high": "high energy, intense activities",
        "not_sure": "any intensity level"
    }
    intensity_desc = intensity_descriptions.get(request.activity_intensity, "any intensity level")
    
    # Format price range
    price_descriptions = {
        "free": "completely free activities (parks, hiking, museums with free admission, etc.)",
        "low": "budget-friendly (under $20 per person)",
        "medium": "moderate pricing ($20-50 per person)", 
        "high": "upscale ($50-100 per person)",
        "luxury": "premium ($100+ per person)"
    }
    price_desc = price_descriptions.get(request.price_range, "any price range")
    
    # Get day of week for context
    try:
        date_obj = datetime.strptime(request.date, "%Y-%m-%d")
        day_of_week = date_obj.strftime("%A")
        is_weekend = date_obj.weekday() >= 5
    except:
        day_of_week = "unknown"
        is_weekend = False
    
    # Determine date context
    date_context = ""
    if is_weekend:
        date_context = "This is a weekend date, so consider activities that are popular for weekend outings and may have special weekend hours or events."
    else:
        date_context = "This is a weekday date, so consider activities that are available during weekdays and may offer better value or less crowds."
    
    # Build user profile context for personalization
    user_context = ""
    if request.user_id:
        user_context = "\nUSER PROFILE & PREFERENCES:\n"
        
        if request.user_age_range:
            user_context += f"- Age Range: {request.user_age_range}\n"
        
        if request.user_relationship_status:
            user_context += f"- Relationship Status: {request.user_relationship_status}\n"
        
        if request.user_hobbies:
            hobbies_str = ", ".join(request.user_hobbies)
            user_context += f"- Hobbies & Interests: {hobbies_str}\n"
        
        if request.user_budget:
            user_context += f"- General Budget Preference: {request.user_budget}\n"
        
        if request.user_cuisines:
            user_cuisines_str = ", ".join(request.user_cuisines)
            user_context += f"- Preferred Cuisines: {user_cuisines_str}\n"
        
        if request.user_favorite_cuisines:
            favorite_cuisines_str = ", ".join(request.user_favorite_cuisines)
            user_context += f"- Favorite Cuisines: {favorite_cuisines_str}\n"
        
        if request.user_transportation:
            transportation_str = ", ".join(request.user_transportation)
            user_context += f"- Transportation: {transportation_str}\n"
        
        user_context += "\nUse this profile information to personalize activity recommendations that match the user's lifestyle, interests, and relationship context.\n"

    prompt = f"""
    You are an expert activity recommendation specialist with deep knowledge of entertainment, recreation, and date-worthy activities across major cities. You understand what makes activities perfect for dates, considering engagement, conversation opportunities, and shared experiences.

    CONTEXT & REQUIREMENTS:
    - Date: {formatted_date} ({day_of_week})
    - Location: {actual_location}
    - Date Type: {request.date_type}
    - Activity Types: {activity_types_str}
    - Activity Intensity: {intensity_desc}
    - Price Range: {price_desc}

    {user_context}
    {date_context}

RECOMMENDATION CRITERIA:
For this {request.date_type} date, prioritize activities that excel in:

1. ENGAGEMENT & INTERACTION:
   - Activities that encourage conversation and connection
   - Shared experiences that create memories
   - Interactive elements that both people can enjoy
   - Appropriate challenge level for both participants

2. ATMOSPHERE & SETTING:
   - Clean, well-maintained facilities
   - Good lighting and comfortable environment
   - Appropriate noise level for conversation
   - Safe and welcoming atmosphere

3. TIMING & AVAILABILITY:
   - Activities available on {formatted_date}
   - Appropriate duration (not too short, not too long)
   - Good timing for the requested activity types
   - Flexible scheduling options

4. VALUE & PRICING:
   - Fair pricing for the experience provided
   - Good value within the specified price range
   - Transparent pricing with no hidden fees
   - Worth the investment for a date experience

5. LOCATION & ACCESSIBILITY:
   - Safe, well-lit area
   - Easy to find and access
   - Parking or public transportation nearby
   - Good neighborhood reputation

SPECIFIC INSTRUCTIONS:
- Recommend 6-8 activities that are real, well-established venues or experiences
- Focus on activities that are actually available on {formatted_date}
- Prioritize activities with consistent quality and good reputations
- Include a mix of popular spots and hidden gems
- Consider the specific activity intensity and types requested
- Ensure variety while respecting preferences
- Include activities that locals would recommend to friends
- Consider weather-appropriate activities for the location and season

For each activity, provide detailed, specific information that helps the user make an informed decision.

Return your response as a JSON array with this exact structure:
[
  {{
    "name": "Activity Name",
    "description": "Concise 1-2 sentence description highlighting what makes this activity special for dates",
    "location": "Specific neighborhood, City",
    "address": "Full street address with city and state",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "cuisine_type": "Activity type (sports/outdoor/indoor/entertainment/fitness)",
    "price_level": "free/low/medium/high/luxury",
    "is_open": true/false,
    "open_hours": "Specific hours of operation",
    "rating": 4.5,
    "why_recommended": "Brief explanation of why this activity is perfect for this specific date occasion",
    "estimated_cost": "Specific cost range per person",
    "best_time": "Optimal time to visit for this activity",
    "duration": "Expected duration (e.g., '1-2 hours', '2-3 hours', 'Half day', 'Full day')"
  }}
]

IMPORTANT: Only recommend real, well-known activities and venues that actually exist in {actual_location} or nearby areas. Do not make up activities or provide generic recommendations.
"""
    
    return prompt

async def get_openai_recommendations(prompt: str, request: RestaurantRequest) -> List[RestaurantRecommendation]:
    """
    Get restaurant recommendations from OpenAI
    """
    try:
        print(f"Creating OpenAI client with API key: {'configured' if openai_api_key else 'None'}...")
        # Use the older OpenAI client initialization for compatibility
        openai.api_key = openai_api_key
        
        print("Making OpenAI API call...")
        system_message = """You are an expert restaurant recommendation specialist with extensive knowledge of dining scenes across major cities. You understand what makes restaurants perfect for dates, considering atmosphere, food quality, service, and romantic appeal. Always respond with valid JSON arrays containing detailed restaurant recommendations. Be specific about real, well-known restaurants and their actual details. Focus on establishments that locals would genuinely recommend to friends for special occasions."""
        if request.date_type == "activity":
            system_message = """You are an expert activity recommendation specialist with extensive knowledge of entertainment, recreation, and date-worthy activities across major cities. You understand what makes activities perfect for dates, considering engagement, conversation opportunities, and shared experiences. Always respond with valid JSON arrays containing detailed activity recommendations. Be specific about real, well-known venues and activities and their actual details. Focus on experiences that locals would genuinely recommend to friends for special occasions."""
        
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system", 
                    "content": system_message
                },
                {"role": "user", "content": prompt}
            ],
            max_tokens=2000,  # Reduced from 3000 to 2000 for faster processing
            temperature=0.7
        )
        print("OpenAI API call successful!")
        
        # Parse the AI response
        ai_response = response.choices[0].message.content.strip()
        print(f"OpenAI response: {ai_response[:200]}...")
        
        # Extract JSON from the response - handle both ```json and plain JSON
        import re
        
        # First try to extract JSON from markdown code blocks
        json_match = re.search(r'```json\s*(\[.*?\])\s*```', ai_response, re.DOTALL)
        if json_match:
            try:
                restaurants_data = json.loads(json_match.group(1))
            except json.JSONDecodeError as e:
                print(f"JSON decode error in markdown block: {e}")
                # Fall back to other methods
                restaurants_data = None
        else:
            restaurants_data = None
        
        if not restaurants_data:
            # Try to find JSON array in the response
            json_match = re.search(r'(\[.*?\])', ai_response, re.DOTALL)
            if json_match:
                try:
                    restaurants_data = json.loads(json_match.group(1))
                except json.JSONDecodeError as e:
                    print(f"JSON decode error in array match: {e}")
                    # Try to find the first complete JSON array line by line
                    lines = ai_response.split('\n')
                    json_lines = []
                    in_json = False
                    brace_count = 0
                    for line in lines:
                        line = line.strip()
                        if line.startswith('['):
                            in_json = True
                            brace_count = 1
                        if in_json:
                            json_lines.append(line)
                            # Count braces to find the end
                            brace_count += line.count('[') - line.count(']')
                            if brace_count == 0 and line.endswith(']'):
                                break
                    if json_lines:
                        json_str = '\n'.join(json_lines)
                        try:
                            restaurants_data = json.loads(json_str)
                        except json.JSONDecodeError as e:
                            print(f"JSON decode error in line-by-line: {e}")
                            # Last resort: try to extract just the first few objects
                            try:
                                # Find the first complete object
                                first_obj_match = re.search(r'\{[^{}]*\}', ai_response)
                                if first_obj_match:
                                    restaurants_data = [json.loads(first_obj_match.group())]
                                else:
                                    raise Exception("No valid JSON found in OpenAI response")
                            except:
                                raise Exception("No valid JSON found in OpenAI response")
                    else:
                        raise Exception("No valid JSON array found in OpenAI response")
            else:
                # Try to find any JSON object
                json_match = re.search(r'(\{.*?\})', ai_response, re.DOTALL)
                if json_match:
                    try:
                        restaurants_data = [json.loads(json_match.group(1))]
                    except json.JSONDecodeError:
                        raise Exception("No valid JSON found in OpenAI response")
                else:
                    raise Exception("No valid JSON found in OpenAI response")
        
        # Convert to our model
        recommendations = []
        
        # If we couldn't parse any data, create fallback recommendations
        if not restaurants_data or len(restaurants_data) == 0:
            print("No valid data parsed, creating fallback recommendations")
            recommendations = create_fallback_recommendations(actual_location, request.latitude, request.longitude)
        else:
            for restaurant_data in restaurants_data:
                try:
                    recommendation = RestaurantRecommendation(
                        name=restaurant_data.get("name", "Unknown Restaurant"),
                        description=restaurant_data.get("description", ""),
                        location=restaurant_data.get("location", ""),
                        address=restaurant_data.get("address", ""),
                        latitude=restaurant_data.get("latitude", 0.0),
                        longitude=restaurant_data.get("longitude", 0.0),
                        cuisine_type=restaurant_data.get("cuisine_type", ""),
                        price_level=restaurant_data.get("price_level", "medium"),
                        is_open=restaurant_data.get("is_open", True),
                        open_hours=restaurant_data.get("open_hours", ""),
                        rating=restaurant_data.get("rating", 4.0),
                        why_recommended=restaurant_data.get("why_recommended", ""),
                        estimated_cost=restaurant_data.get("estimated_cost", ""),
                        best_time=restaurant_data.get("best_time", ""),
                        image_url=get_image_url(
                            restaurant_data.get("cuisine_type", ""), 
                            restaurant_data.get("name", ""),
                            request.location,
                            request.latitude,
                            request.longitude
                        )
                    )
                    recommendations.append(recommendation)
                except Exception as e:
                    print(f"Error parsing restaurant data: {e}")
                    continue
        
        return recommendations
        
    except Exception as e:
        print(f"OpenAI error: {e}")
        # Provide more specific error messages
        error_msg = str(e)
        if "model" in error_msg.lower() and "not found" in error_msg.lower():
            raise Exception("OpenAI model not available. Please check your API key and model access.")
        elif "quota" in error_msg.lower():
            raise Exception("OpenAI API quota exceeded. Please check your billing.")
        elif "api key" in error_msg.lower():
            raise Exception("OpenAI API key not configured properly.")
        else:
            raise Exception(f"Failed to get recommendations from OpenAI: {e}")

def create_fallback_recommendations(location: str, latitude: float = None, longitude: float = None) -> List[RestaurantRecommendation]:
    """
    Create fallback recommendations when OpenAI parsing fails
    """
    # Get coordinates for the location (simplified)
    if latitude is None or longitude is None:
        coords = get_location_coordinates(location)
        latitude, longitude = coords
    
    recommendations = [
        # Restaurants (3)
        RestaurantRecommendation(
            name="Local Coffee Shop",
            description="A cozy coffee shop perfect for casual dates and conversation. Great atmosphere for getting to know someone over coffee and pastries.",
            location=location,
            address=f"123 Main St, {location}",
            latitude=coords[0],
            longitude=coords[1],
            cuisine_type="american",
            price_level="low",
            is_open=True,
            open_hours="6:00 AM - 8:00 PM",
            rating=4.2,
            why_recommended="Perfect for casual first dates with great coffee and comfortable seating",
            estimated_cost="$5-12 per person",
            best_time="2:00 PM",
            image_url=get_image_url("american", "coffee shop", location, latitude, longitude)
        ),
        RestaurantRecommendation(
            name="Italian Bistro",
            description="A charming Italian restaurant with romantic ambiance and authentic pasta dishes. Perfect for dinner dates.",
            location=location,
            address=f"456 Oak Ave, {location}",
            latitude=coords[0] + 0.01,
            longitude=coords[1] + 0.01,
            cuisine_type="italian",
            price_level="medium",
            is_open=True,
            open_hours="5:00 PM - 10:00 PM",
            rating=4.5,
            why_recommended="Romantic atmosphere with excellent Italian cuisine perfect for dinner dates",
            estimated_cost="$20-35 per person",
            best_time="7:00 PM",
            image_url=get_image_url("italian", "bistro", location, latitude, longitude)
        ),
        RestaurantRecommendation(
            name="Sushi Bar",
            description="An elegant sushi restaurant with fresh fish and intimate seating. Perfect for sophisticated dates and trying new flavors together.",
            location=location,
            address=f"789 Sushi St, {location}",
            latitude=coords[0] + 0.015,
            longitude=coords[1] - 0.015,
            cuisine_type="japanese",
            price_level="high",
            is_open=True,
            open_hours="5:30 PM - 10:30 PM",
            rating=4.6,
            why_recommended="Sophisticated dining experience perfect for special occasions",
            estimated_cost="$40-60 per person",
            best_time="8:00 PM",
            image_url=get_image_url("japanese", "sushi", location, latitude, longitude)
        ),
        # Activities (3)
        RestaurantRecommendation(
            name="Local Park",
            description="A beautiful park with walking trails, picnic areas, and scenic views. Great for outdoor dates and activities.",
            location=location,
            address=f"789 Park Blvd, {location}",
            latitude=coords[0] - 0.01,
            longitude=coords[1] - 0.01,
            cuisine_type="outdoor",
            price_level="free",
            is_open=True,
            open_hours="6:00 AM - 10:00 PM",
            rating=4.3,
            why_recommended="Perfect for outdoor dates with beautiful scenery and free activities",
            estimated_cost="Free",
            best_time="4:00 PM",
            image_url=get_image_url("outdoor", "park", location, latitude, longitude)
        ),
        RestaurantRecommendation(
            name="Art Museum",
            description="A cultural destination with rotating exhibits and beautiful architecture. Great for intellectual dates and cultural experiences.",
            location=location,
            address=f"321 Culture St, {location}",
            latitude=coords[0] + 0.02,
            longitude=coords[1] - 0.02,
            cuisine_type="entertainment",
            price_level="low",
            is_open=True,
            open_hours="10:00 AM - 6:00 PM",
            rating=4.4,
            why_recommended="Cultural experience perfect for intellectual dates and meaningful conversations",
            estimated_cost="$8-15 per person",
            best_time="2:00 PM",
            image_url=get_image_url("entertainment", "museum", location, latitude, longitude)
        ),
        RestaurantRecommendation(
            name="Escape Room",
            description="An interactive puzzle experience perfect for couples who enjoy challenges and teamwork. Great for building connection through problem-solving.",
            location=location,
            address=f"555 Puzzle Ave, {location}",
            latitude=coords[0] + 0.025,
            longitude=coords[1] + 0.025,
            cuisine_type="entertainment",
            price_level="medium",
            is_open=True,
            open_hours="12:00 PM - 10:00 PM",
            rating=4.5,
            why_recommended="Interactive experience perfect for couples who love puzzles and teamwork",
            estimated_cost="$25-35 per person",
            best_time="7:00 PM",
            image_url=get_image_url("entertainment", "escape room", location, latitude, longitude)
        )
    ]
    
    return recommendations

def get_location_coordinates(location: str) -> tuple:
    """
    Get approximate coordinates for a location
    """
    # Simple coordinate mapping for common cities
    city_coords = {
        "salt lake city": (40.7608, -111.8910),
        "los angeles": (34.0522, -118.2437),
        "new york": (40.7128, -74.0060),
        "chicago": (41.8781, -87.6298),
        "houston": (29.7604, -95.3698),
        "phoenix": (33.4484, -112.0740),
        "philadelphia": (39.9526, -75.1652),
        "san antonio": (29.4241, -98.4936),
        "san diego": (32.7157, -117.1611),
        "dallas": (32.7767, -96.7970)
    }
    
    location_lower = location.lower()
    for city, coords in city_coords.items():
        if city in location_lower:
            return coords
    
    # Default to Salt Lake City if not found
    return (40.7608, -111.8910)

if __name__ == "__main__":
    import uvicorn
    try:
        print("Starting D8 Backend API v2.0...")
        port = int(os.getenv("PORT", 8000))
        print(f"Starting server on port {port}")
        uvicorn.run(app, host="0.0.0.0", port=port)
    except Exception as e:
        print(f"Failed to start server: {e}")
        import traceback
        traceback.print_exc()
