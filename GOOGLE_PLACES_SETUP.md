# Google Places API Setup Guide

## Required Environment Variables

To fix the placeholder image issue, you need to set up the Google Places API key properly.

### Backend Configuration

1. Set the `GOOGLE_PLACES_API_KEY` environment variable in your backend deployment:
   ```bash
   export GOOGLE_PLACES_API_KEY="your_actual_google_places_api_key"
   ```

2. For Railway deployment, add this environment variable in your Railway dashboard.

### Getting a Google Places API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the "Places API" and "Maps JavaScript API"
4. Go to "Credentials" and create a new API key
5. Restrict the API key to only the Places API and Maps API
6. Copy the API key and set it as your `GOOGLE_PLACES_API_KEY` environment variable

### What Was Fixed

- ✅ Removed Foursquare API integration (not needed)
- ✅ Removed Pexels API integration (not needed) 
- ✅ Removed Unsplash API integration (not needed)
- ✅ Removed placeholder image generation
- ✅ Updated both backend and iOS to only use Google Places API
- ✅ Images will now only show real restaurant photos from Google Places

### Testing

After setting up the API key, restart your backend and test the image functionality. You should now see real restaurant images instead of placeholder images.
