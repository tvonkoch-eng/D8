from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict
import openai
import os
from datetime import datetime
import json
import requests

app = FastAPI(title="D8 Backend API", version="2.0.0")

# Configure OpenAI
openai_api_key = os.getenv("OPENAI_API_KEY")
if openai_api_key:
    openai.api_key = openai_api_key
    print(f"OpenAI API key loaded from environment (length: {len(openai_api_key)})")
    print(f"API key starts with: {openai_api_key[:10]}...")
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
    pros: List[str]
    cons: List[str]
    rating: float
    why_recommended: str
    estimated_cost: str
    best_time: str

class RestaurantResponse(BaseModel):
    recommendations: List[RestaurantRecommendation]
    total_found: int
    query_used: str
    processing_time: float

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
    return {"message": "D8 Backend API v2.0 - OpenAI Powered"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().timestamp()}

@app.post("/recommendations", response_model=RestaurantResponse)
async def get_restaurant_recommendations(request: RestaurantRequest):
    """
    Get AI-powered restaurant recommendations using OpenAI
    """
    import time
    start_time = time.time()
    
    try:
        print(f"Received request: {request}")
        
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
    
    prompt = f"""
You are an expert restaurant recommendation specialist with deep knowledge of dining scenes across major cities. You understand the nuances of what makes a perfect date restaurant, considering atmosphere, service, food quality, and romantic appeal.

CONTEXT & REQUIREMENTS:
- Date: {formatted_date} ({day_of_week})
- Location: {actual_location}
- Date Type: {request.date_type}
- Meal Time: {meal_times_str}
- Price Range: {price_desc}
- Cuisine Preferences: {cuisines_str}

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
    "pros": ["Specific pro 1", "Specific pro 2", "Specific pro 3", "Specific pro 4"],
    "cons": ["Honest con 1", "Honest con 2"],
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
    
    prompt = f"""
You are an expert activity recommendation specialist with deep knowledge of entertainment, recreation, and date-worthy activities across major cities. You understand what makes activities perfect for dates, considering engagement, conversation opportunities, and shared experiences.

CONTEXT & REQUIREMENTS:
- Date: {formatted_date} ({day_of_week})
- Location: {actual_location}
- Date Type: {request.date_type}
- Activity Types: {activity_types_str}
- Activity Intensity: {intensity_desc}
- Price Range: {price_desc}

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
    "description": "Detailed 2-3 sentence description highlighting what makes this activity special for dates",
    "location": "Specific neighborhood, City",
    "address": "Full street address with city and state",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "cuisine_type": "Activity type (sports/outdoor/indoor/entertainment/fitness)",
    "price_level": "low/medium/high/luxury",
    "is_open": true/false,
    "open_hours": "Specific hours of operation",
    "pros": ["Specific pro 1", "Specific pro 2", "Specific pro 3", "Specific pro 4"],
    "cons": ["Honest con 1", "Honest con 2"],
    "rating": 4.5,
    "why_recommended": "Detailed explanation of why this activity is perfect for this specific date occasion",
    "estimated_cost": "Specific cost range per person",
    "best_time": "Optimal time to visit for this activity"
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
        print(f"Creating OpenAI client with API key: {openai_api_key[:10] if openai_api_key else 'None'}...")
        client = openai.OpenAI(api_key=openai_api_key)
        
        print("Making OpenAI API call...")
        system_message = """You are an expert restaurant recommendation specialist with extensive knowledge of dining scenes across major cities. You understand what makes restaurants perfect for dates, considering atmosphere, food quality, service, and romantic appeal. Always respond with valid JSON arrays containing detailed restaurant recommendations. Be specific about real, well-known restaurants and their actual details. Focus on establishments that locals would genuinely recommend to friends for special occasions."""
        if request.date_type == "activity":
            system_message = """You are an expert activity recommendation specialist with extensive knowledge of entertainment, recreation, and date-worthy activities across major cities. You understand what makes activities perfect for dates, considering engagement, conversation opportunities, and shared experiences. Always respond with valid JSON arrays containing detailed activity recommendations. Be specific about real, well-known venues and activities and their actual details. Focus on experiences that locals would genuinely recommend to friends for special occasions."""
        
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system", 
                    "content": system_message
                },
                {"role": "user", "content": prompt}
            ],
            max_tokens=2000,
            temperature=0.7
        )
        print("OpenAI API call successful!")
        
        # Parse the AI response
        ai_response = response.choices[0].message.content.strip()
        print(f"OpenAI response: {ai_response[:200]}...")
        
        # Extract JSON from the response
        import re
        json_match = re.search(r'\[.*\]', ai_response, re.DOTALL)
        if json_match:
            restaurants_data = json.loads(json_match.group())
        else:
            # Try to find any JSON array in the response
            json_match = re.search(r'\{.*\}', ai_response, re.DOTALL)
            if json_match:
                restaurants_data = [json.loads(json_match.group())]
            else:
                raise Exception("No valid JSON found in OpenAI response")
        
        # Convert to our model
        recommendations = []
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
                    pros=restaurant_data.get("pros", []),
                    cons=restaurant_data.get("cons", []),
                    rating=restaurant_data.get("rating", 4.0),
                    why_recommended=restaurant_data.get("why_recommended", ""),
                    estimated_cost=restaurant_data.get("estimated_cost", ""),
                    best_time=restaurant_data.get("best_time", "")
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
