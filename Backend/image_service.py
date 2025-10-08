"""
Enhanced Image Service with Foursquare Integration
Provides location-specific restaurant images and fallback options
"""

import os
import requests
import random
from typing import Optional, Dict, Any
import time

class EnhancedImageService:
    def __init__(self):
        # Only use Google Places API for restaurant images
        self.google_places_api_key = os.getenv("GOOGLE_PLACES_API_KEY")
        
        # Rate limiting tracking
        self.google_places_calls = 0
        self.last_google_places_reset = time.time()
        
        # Cache for image URLs to avoid repeated API calls
        self.image_cache = {}
    
    def get_restaurant_image_url(self, name: str, cuisine_type: str, location: str = "", 
                               latitude: float = None, longitude: float = None, address: str = "") -> str:
        """
        Get restaurant image URL using Google Places API only
        """
        print(f"🖼️ [ImageService] Getting image for: {name} in {location}")
        print(f"🔑 [ImageService] Google Places API key configured: {bool(self.google_places_api_key)}")
        print(f"📍 [ImageService] Coordinates: {latitude}, {longitude}")
        print(f"🏠 [ImageService] Address: {address}")
        
        # Create cache key
        cache_key = f"{name}_{cuisine_type}_{location}_{latitude}_{longitude}_{address}"
        
        # Check cache first
        if cache_key in self.image_cache:
            print(f"💾 [ImageService] Using cached image for: {name}")
            return self.image_cache[cache_key]
        
        image_url = None
        
        # Try Google Places API (only source for restaurant images)
        if self.google_places_api_key and (latitude and longitude):
            print(f"🔍 [ImageService] Fetching Google Places image for: {name}")
            # Try multiple search strategies
            image_url = self._fetch_google_places_image_with_fallbacks(name, location, latitude, longitude, address, cuisine_type)
        else:
            print(f"❌ [ImageService] Cannot fetch image - API key: {bool(self.google_places_api_key)}, Coords: {bool(latitude and longitude)}")
        
        # If no image found, return empty string (no placeholder images)
        if not image_url:
            image_url = ""
            print(f"❌ [ImageService] No image found for: {name}")
        else:
            print(f"✅ [ImageService] Found image for: {name} - {image_url[:50]}...")
        
        # Cache the result
        self.image_cache[cache_key] = image_url
        return image_url
    
    def _fetch_google_places_image_with_fallbacks(self, name: str, location: str, latitude: float, longitude: float, address: str, cuisine_type: str) -> Optional[str]:
        """
        Try multiple search strategies to find restaurant images
        """
        print(f"🔄 [ImageService] Trying multiple search strategies for: {name}")
        
        # Strategy 1: Search by exact restaurant name + location
        image_url = self._fetch_google_places_image(name, location, latitude, longitude)
        if image_url:
            return image_url
        
        # Strategy 2: Search by restaurant name + address city
        if address:
            # Extract city from address
            address_parts = address.split(',')
            if len(address_parts) >= 2:
                city = address_parts[-2].strip()
                print(f"🏙️ [ImageService] Trying search with address city: {city}")
                image_url = self._fetch_google_places_image(name, city, latitude, longitude)
                if image_url:
                    return image_url
        
        # Strategy 3: Search by cuisine type + location (for generic restaurant images)
        print(f"🍽️ [ImageService] Trying cuisine-based search: {cuisine_type} restaurant")
        image_url = self._fetch_google_places_image(f"{cuisine_type} restaurant", location, latitude, longitude)
        if image_url:
            return image_url
        
        # Strategy 4: Search by cuisine type + address city
        if address:
            address_parts = address.split(',')
            if len(address_parts) >= 2:
                city = address_parts[-2].strip()
                print(f"🏙️ [ImageService] Trying cuisine search with address city: {city}")
                image_url = self._fetch_google_places_image(f"{cuisine_type} restaurant", city, latitude, longitude)
                if image_url:
                    return image_url
        
        print(f"❌ [ImageService] All search strategies failed for: {name}")
        return None
    
    def _fetch_google_places_image(self, name: str, location: str, latitude: float, longitude: float) -> Optional[str]:
        
        if not self._check_google_places_rate_limit():
            print(f"❌ [GooglePlaces] Rate limit exceeded")
            return None
        
        try:
            # Step 1: Search for the place to get place_id
            search_url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
            search_params = {
                "query": f"{name} {location}",
                "location": f"{latitude},{longitude}",
                "radius": 1000,  # 1km radius
                "key": self.google_places_api_key
            }
            
            print(f"🌐 [GooglePlaces] Making search request to: {search_url}")
            print(f"🔑 [GooglePlaces] Using API key: {self.google_places_api_key[:10]}...")
            
            search_response = requests.get(search_url, params=search_params, timeout=5)
            print(f"📡 [GooglePlaces] Search response status: {search_response.status_code}")
            
            if search_response.status_code == 200:
                search_data = search_response.json()
                results = search_data.get("results", [])
                print(f"📊 [GooglePlaces] Found {len(results)} results")
                
                if results:
                    # Get the most relevant place (first result)
                    place_id = results[0].get("place_id")
                    print(f"🏢 [GooglePlaces] Found place_id: {place_id}")
                    
                    if place_id:
                        # Step 2: Get place details with photo references
                        details_url = "https://maps.googleapis.com/maps/api/place/details/json"
                        details_params = {
                            "place_id": place_id,
                            "fields": "photos",
                            "key": self.google_places_api_key
                        }
                        
                        print(f"🔍 [GooglePlaces] Getting place details...")
                        details_response = requests.get(details_url, params=details_params, timeout=5)
                        print(f"📡 [GooglePlaces] Details response status: {details_response.status_code}")
                        
                        if details_response.status_code == 200:
                            details_data = details_response.json()
                            result = details_data.get("result", {})
                            photos = result.get("photos", [])
                            print(f"📸 [GooglePlaces] Found {len(photos)} photos")
                            
                            if photos:
                                # Step 3: Construct the photo URL
                                photo_reference = photos[0].get("photo_reference")
                                if photo_reference:
                                    photo_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference={photo_reference}&key={self.google_places_api_key}"
                                    self.google_places_calls += 2  # Search + details call
                                    print(f"✅ [GooglePlaces] Generated photo URL: {photo_url[:50]}...")
                                    return photo_url
                                else:
                                    print(f"❌ [GooglePlaces] No photo reference found")
                            else:
                                print(f"❌ [GooglePlaces] No photos found for place")
                        else:
                            print(f"❌ [GooglePlaces] Details request failed: {details_response.status_code}")
                    else:
                        print(f"❌ [GooglePlaces] No place_id found")
                else:
                    print(f"❌ [GooglePlaces] No search results found")
            else:
                print(f"❌ [GooglePlaces] Search request failed: {search_response.status_code}")
                print(f"📄 [GooglePlaces] Response: {search_response.text[:200]}...")
            
        except Exception as e:
            print(f"❌ [GooglePlaces] API error: {e}")
        
        return None
    
    
    
    
    
    
    def _check_google_places_rate_limit(self) -> bool:
        """
        Check Google Places rate limits (100,000 requests/month free tier)
        """
        current_time = time.time()
        
        # Reset monthly counter (approximate)
        if current_time - self.last_google_places_reset > 2592000:  # 30 days
            self.google_places_calls = 0
            self.last_google_places_reset = current_time
        
        return self.google_places_calls < 100000
    
    def get_api_status(self) -> Dict[str, Any]:
        """
        Get status of Google Places API
        """
        return {
            "google_places": {
                "configured": bool(self.google_places_api_key),
                "calls_this_month": self.google_places_calls,
                "rate_limit": 100000,
                "period": "monthly"
            }
        }

# Global instance
image_service = EnhancedImageService()
