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
        # API Keys from environment variables
        self.foursquare_api_key = os.getenv("FOURSQUARE_API_KEY")
        self.pexels_api_key = os.getenv("PEXELS_API_KEY")
        self.unsplash_api_key = os.getenv("UNSPLASH_API_KEY")
        self.google_places_api_key = os.getenv("GOOGLE_PLACES_API_KEY", "AIzaSyCz7OlK0dpbMuX1FLQXpUjKUMJQf0XzTkY")
        
        # Rate limiting tracking
        self.foursquare_calls = 0
        self.pexels_calls = 0
        self.unsplash_calls = 0
        self.google_places_calls = 0
        self.last_foursquare_reset = time.time()
        self.last_pexels_reset = time.time()
        self.last_unsplash_reset = time.time()
        self.last_google_places_reset = time.time()
        
        # Cache for image URLs to avoid repeated API calls
        self.image_cache = {}
    
    def get_restaurant_image_url(self, name: str, cuisine_type: str, location: str = "", 
                               latitude: float = None, longitude: float = None) -> str:
        """
        Get the best available image URL for a restaurant/activity
        Priority: Foursquare (location-specific) -> Pexels -> Unsplash -> Lorem Picsum
        """
        # Create cache key
        cache_key = f"{name}_{cuisine_type}_{location}_{latitude}_{longitude}"
        
        # Check cache first
        if cache_key in self.image_cache:
            return self.image_cache[cache_key]
        
        image_url = None
        
        # 1. Try Google Places API first (most relevant for restaurants)
        if self.google_places_api_key and (latitude and longitude):
            image_url = self._fetch_google_places_image(name, location, latitude, longitude)
        
        # 2. Try Foursquare (location-specific, real restaurant photos)
        if not image_url and self.foursquare_api_key and (latitude and longitude):
            image_url = self._fetch_foursquare_image(name, location, latitude, longitude)
        
        # 3. Fallback to Pexels (high-quality, free)
        if not image_url and self.pexels_api_key:
            search_query = self._create_search_query(name, cuisine_type, location)
            image_url = self._fetch_pexels_image(search_query)
        
        # 4. Fallback to Unsplash (high-quality, free)
        if not image_url and self.unsplash_api_key:
            search_query = self._create_search_query(name, cuisine_type, location)
            image_url = self._fetch_unsplash_image(search_query)
        
        # 5. Final fallback to Lorem Picsum (current system)
        if not image_url:
            image_url = self._get_lorem_picsum_url(cuisine_type, name)
        
        # Cache the result
        self.image_cache[cache_key] = image_url
        return image_url
    
    def _fetch_foursquare_image(self, name: str, location: str, latitude: float, longitude: float) -> Optional[str]:
        """
        Fetch restaurant image from Foursquare Places API
        """
        if not self._check_foursquare_rate_limit():
            return None
        
        try:
            # First, search for the venue using the new Places API
            search_url = "https://api.foursquare.com/v3/places/search"
            search_params = {
                "query": name,
                "ll": f"{latitude},{longitude}",
                "radius": 1000,  # 1km radius
                "limit": 5
            }
            search_headers = {
                "Authorization": f"FSQ3 {self.foursquare_api_key}",
                "Accept": "application/json"
            }
            
            search_response = requests.get(search_url, params=search_params, headers=search_headers, timeout=5)
            
            if search_response.status_code == 200:
                search_data = search_response.json()
                venues = search_data.get("results", [])
                
                if venues:
                    # Get the most relevant venue (first result)
                    venue = venues[0]
                    venue_id = venue.get("fsq_id")
                    
                    if venue_id:
                        # Get venue details including photos
                        details_url = f"https://api.foursquare.com/v3/places/{venue_id}"
                        details_params = {"fields": "photos"}
                        details_headers = {
                            "Authorization": f"FSQ3 {self.foursquare_api_key}",
                            "Accept": "application/json"
                        }
                        
                        details_response = requests.get(details_url, params=details_params, headers=details_headers, timeout=5)
                        
                        if details_response.status_code == 200:
                            details_data = details_response.json()
                            photos = details_data.get("photos", [])
                            
                            if photos:
                                # Get the first photo
                                photo = photos[0]
                                photo_url = photo.get("prefix") + "400x300" + photo.get("suffix")
                                self.foursquare_calls += 2  # Search + details call
                                return photo_url
            
        except Exception as e:
            print(f"Foursquare API error: {e}")
        
        return None
    
    def _fetch_google_places_image(self, name: str, location: str, latitude: float, longitude: float) -> Optional[str]:
        """
        Fetch restaurant image from Google Places API
        """
        if not self._check_google_places_rate_limit():
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
            
            search_response = requests.get(search_url, params=search_params, timeout=5)
            
            if search_response.status_code == 200:
                search_data = search_response.json()
                results = search_data.get("results", [])
                
                if results:
                    # Get the most relevant place (first result)
                    place_id = results[0].get("place_id")
                    
                    if place_id:
                        # Step 2: Get place details with photo references
                        details_url = "https://maps.googleapis.com/maps/api/place/details/json"
                        details_params = {
                            "place_id": place_id,
                            "fields": "photos",
                            "key": self.google_places_api_key
                        }
                        
                        details_response = requests.get(details_url, params=details_params, timeout=5)
                        
                        if details_response.status_code == 200:
                            details_data = details_response.json()
                            result = details_data.get("result", {})
                            photos = result.get("photos", [])
                            
                            if photos:
                                # Step 3: Construct the photo URL
                                photo_reference = photos[0].get("photo_reference")
                                if photo_reference:
                                    photo_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference={photo_reference}&key={self.google_places_api_key}"
                                    self.google_places_calls += 2  # Search + details call
                                    return photo_url
            
        except Exception as e:
            print(f"Google Places API error: {e}")
        
        return None
    
    def _fetch_pexels_image(self, query: str) -> Optional[str]:
        """
        Fetch image from Pexels API
        """
        if not self._check_pexels_rate_limit():
            return None
        
        try:
            url = "https://api.pexels.com/v1/search"
            params = {
                "query": query,
                "per_page": 1,
                "orientation": "landscape"
            }
            headers = {
                "Authorization": self.pexels_api_key
            }
            
            response = requests.get(url, params=params, headers=headers, timeout=5)
            
            if response.status_code == 200:
                data = response.json()
                photos = data.get("photos", [])
                
                if photos:
                    self.pexels_calls += 1
                    return photos[0]["src"]["medium"]
            
        except Exception as e:
            print(f"Pexels API error: {e}")
        
        return None
    
    def _fetch_unsplash_image(self, query: str) -> Optional[str]:
        """
        Fetch image from Unsplash API
        """
        if not self._check_unsplash_rate_limit():
            return None
        
        try:
            url = "https://api.unsplash.com/search/photos"
            params = {
                "query": query,
                "per_page": 1,
                "orientation": "landscape"
            }
            headers = {
                "Authorization": f"Client-ID {self.unsplash_api_key}"
            }
            
            response = requests.get(url, params=params, headers=headers, timeout=5)
            
            if response.status_code == 200:
                data = response.json()
                results = data.get("results", [])
                
                if results:
                    self.unsplash_calls += 1
                    return results[0]["urls"]["regular"]
            
        except Exception as e:
            print(f"Unsplash API error: {e}")
        
        return None
    
    def _create_search_query(self, name: str, cuisine_type: str, location: str) -> str:
        """
        Create optimized search query for image APIs
        """
        cuisine_keywords = {
            "italian": "italian restaurant pasta food",
            "mexican": "mexican restaurant tacos food",
            "american": "american restaurant burger food",
            "japanese": "japanese restaurant sushi food",
            "chinese": "chinese restaurant food",
            "indian": "indian restaurant curry food",
            "thai": "thai restaurant food",
            "french": "french restaurant food",
            "mediterranean": "mediterranean restaurant food",
            "seafood": "seafood restaurant fish food",
            "steakhouse": "steakhouse restaurant steak food",
            "contemporary": "modern restaurant fine dining food",
            "sports": "sports fitness activity",
            "outdoor": "outdoor nature activity",
            "indoor": "indoor activity entertainment",
            "entertainment": "entertainment venue activity",
            "fitness": "fitness gym workout"
        }
        
        base_query = cuisine_keywords.get(cuisine_type.lower(), f"{cuisine_type} restaurant")
        
        # Add location context if available
        if location:
            location_part = location.split(',')[0].strip()
            return f"{base_query} {location_part}"
        
        return base_query
    
    def _get_lorem_picsum_url(self, cuisine_type: str, name: str) -> str:
        """
        Fallback to Lorem Picsum (current system)
        """
        cuisine_keywords = {
            "italian": "pasta",
            "mexican": "tacos",
            "american": "burger",
            "japanese": "sushi",
            "chinese": "dim+sum",
            "indian": "curry",
            "thai": "pad+thai",
            "french": "french+cuisine",
            "mediterranean": "mediterranean+food",
            "seafood": "seafood",
            "steakhouse": "steak",
            "contemporary": "fine+dining",
            "sports": "sports+activity",
            "outdoor": "outdoor+activity",
            "indoor": "indoor+activity",
            "entertainment": "entertainment",
            "fitness": "fitness"
        }
        
        keyword = cuisine_keywords.get(cuisine_type.lower(), "restaurant")
        width = 400
        height = 300
        random_id = random.randint(1, 1000)
        
        return f"https://picsum.photos/{width}/{height}?random={random_id}&blur=1"
    
    def _check_foursquare_rate_limit(self) -> bool:
        """
        Check Foursquare rate limits (1,000 requests/day free tier)
        """
        current_time = time.time()
        
        # Reset daily counter
        if current_time - self.last_foursquare_reset > 86400:  # 24 hours
            self.foursquare_calls = 0
            self.last_foursquare_reset = current_time
        
        return self.foursquare_calls < 1000
    
    def _check_pexels_rate_limit(self) -> bool:
        """
        Check Pexels rate limits (200 requests/hour)
        """
        current_time = time.time()
        
        # Reset hourly counter
        if current_time - self.last_pexels_reset > 3600:  # 1 hour
            self.pexels_calls = 0
            self.last_pexels_reset = current_time
        
        return self.pexels_calls < 200
    
    def _check_unsplash_rate_limit(self) -> bool:
        """
        Check Unsplash rate limits (50 requests/hour)
        """
        current_time = time.time()
        
        # Reset hourly counter
        if current_time - self.last_unsplash_reset > 3600:  # 1 hour
            self.unsplash_calls = 0
            self.last_unsplash_reset = current_time
        
        return self.unsplash_calls < 50
    
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
        Get status of all image APIs
        """
        return {
            "google_places": {
                "configured": bool(self.google_places_api_key),
                "calls_this_month": self.google_places_calls,
                "rate_limit": 100000,
                "period": "monthly"
            },
            "foursquare": {
                "configured": bool(self.foursquare_api_key),
                "calls_today": self.foursquare_calls,
                "rate_limit": 1000,
                "period": "daily"
            },
            "pexels": {
                "configured": bool(self.pexels_api_key),
                "calls_this_hour": self.pexels_calls,
                "rate_limit": 200,
                "period": "hourly"
            },
            "unsplash": {
                "configured": bool(self.unsplash_api_key),
                "calls_this_hour": self.unsplash_calls,
                "rate_limit": 50,
                "period": "hourly"
            }
        }

# Global instance
image_service = EnhancedImageService()
