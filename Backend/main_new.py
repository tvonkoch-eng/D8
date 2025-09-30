from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict
import openai
import os
from datetime import datetime
import json

app = FastAPI(title="D8 Backend API", version="2.0.0")

# Configure OpenAI
openai_api_key = os.getenv("OPENAI_API_KEY")
if openai_api_key:
    openai.api_key = openai_api_key
    print("OpenAI API key loaded from environment")
else:
    print("Warning: No OpenAI API key found in environment variables")

class RestaurantRequest(BaseModel):
    date_type: str
    meal_times: List[str]
    price_range: str
    cuisines: List[str]
    date: str
    location: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class RestaurantRecommendation(BaseModel):
    name: str
    description: str
    location: str
    cuisine_type: str
    price_level: str
    is_open: bool
    open_hours: str
    rating: float
    why_recommended: str
    estimated_cost: str
    best_time: str

class RestaurantResponse(BaseModel):
    recommendations: List[RestaurantRecommendation]
    total_found: int
    query_used: str
    processing_time: float

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
            raise HTTPException(status_code=500, detail="OpenAI API key not configured")
        
        # Create natural language prompt
        prompt = create_restaurant_prompt(request)
        print(f"Generated prompt: {prompt[:200]}...")
        
        # Get recommendations from OpenAI
        recommendations = await get_openai_recommendations(prompt, request)
        
        processing_time = time.time() - start_time
        
        response = RestaurantResponse(
            recommendations=recommendations,
            total_found=len(recommendations),
            query_used=f"OpenAI-powered recommendations for {request.date_type} {request.meal_times[0] if request.meal_times else 'meal'}",
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
    Create a natural language prompt for restaurant recommendations
    """
    # Format the date
    try:
        date_obj = datetime.strptime(request.date, "%Y-%m-%d")
        formatted_date = date_obj.strftime("%A, %B %d, %Y")
    except:
        formatted_date = request.date
    
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
    
    prompt = f"""
You are an expert restaurant recommendation assistant. I need restaurant recommendations for a {request.date_type} date on {formatted_date} in {request.location}.

Here are the details:
- Date Type: {request.date_type}
- Meal Time: {meal_times_str}
- Price Range: {price_desc}
- Cuisine Preferences: {cuisines_str}
- Location: {request.location}

Please recommend 5-8 restaurants that would be perfect for this occasion. For each restaurant, provide:

1. Restaurant name
2. Brief description (1-2 sentences)
3. Location/neighborhood
4. Cuisine type
5. Price level (low/medium/high/luxury)
6. Whether it's open on {formatted_date} for {meal_times_str}
7. Opening hours
8. Rating (1-5 stars)
9. Why it's recommended for this specific occasion
10. Estimated cost per person
11. Best time to visit

Focus on restaurants that are:
- Actually open on the requested date/time
- Appropriate for the date type ({request.date_type})
- Match the price range and cuisine preferences
- Have good reviews and reputation
- Are suitable for the meal time requested

Return your response as a JSON array with this exact structure:
[
  {{
    "name": "Restaurant Name",
    "description": "Brief description of the restaurant",
    "location": "Neighborhood, City",
    "cuisine_type": "Type of cuisine",
    "price_level": "low/medium/high/luxury",
    "is_open": true/false,
    "open_hours": "Hours of operation",
    "rating": 4.5,
    "why_recommended": "Why this restaurant is perfect for this occasion",
    "estimated_cost": "$XX per person",
    "best_time": "Best time to visit"
  }}
]

Make sure the restaurants are real, well-known establishments in {request.location} or nearby areas.
"""
    
    return prompt

async def get_openai_recommendations(prompt: str, request: RestaurantRequest) -> List[RestaurantRecommendation]:
    """
    Get restaurant recommendations from OpenAI
    """
    try:
        client = openai.OpenAI()
        
        response = client.chat.completions.create(
            model="gpt-4",
            messages=[
                {
                    "role": "system", 
                    "content": "You are a restaurant recommendation expert. Always respond with valid JSON arrays containing restaurant recommendations. Be specific about real restaurants and their actual details."
                },
                {"role": "user", "content": prompt}
            ],
            max_tokens=3000,
            temperature=0.7
        )
        
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
                    cuisine_type=restaurant_data.get("cuisine_type", ""),
                    price_level=restaurant_data.get("price_level", "medium"),
                    is_open=restaurant_data.get("is_open", True),
                    open_hours=restaurant_data.get("open_hours", ""),
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
