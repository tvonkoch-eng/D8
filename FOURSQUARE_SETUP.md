# Foursquare API Setup Guide

This guide will help you set up the Foursquare Places API for location-specific restaurant images in your D8 app.

## 🎯 **Why Foursquare?**

- **100% Free** - 1,000 requests per day
- **Location-specific** - Real photos from actual restaurants
- **High quality** - Professional photos from the venues themselves
- **Real data** - Hours, ratings, and verified information

## 🚀 **Quick Setup (5 minutes):**

### Step 1: Get Foursquare API Key
1. Go to https://developer.foursquare.com/
2. Click "Get Started" → Sign up for free
3. Create a new app
4. Copy your API Key from the app dashboard

### Step 2: Add to Environment Variables
Add to your deployment environment (Railway/Render):
```bash
FOURSQUARE_API_KEY=your_foursquare_api_key_here
```

### Step 3: Optional - Add Pexels/Unsplash for Fallbacks
```bash
PEXELS_API_KEY=your_pexels_key_here
UNSPLASH_API_KEY=your_unsplash_key_here
```

## 📱 **How It Works:**

The enhanced image service will:

1. **Try Foursquare first** - Search for the actual restaurant by name and location
2. **Get real photos** - Use photos uploaded by the restaurant or customers
3. **Fallback to Pexels** - If Foursquare doesn't have the restaurant
4. **Fallback to Unsplash** - If Pexels fails
5. **Final fallback** - Use Lorem Picsum (current system)

## 🔍 **API Status Endpoint:**

Check your image service status:
```
GET /image-service-status
```

Response:
```json
{
  "foursquare": {
    "configured": true,
    "calls_today": 45,
    "rate_limit": 1000,
    "period": "daily"
  },
  "pexels": {
    "configured": true,
    "calls_this_hour": 12,
    "rate_limit": 200,
    "period": "hourly"
  },
  "unsplash": {
    "configured": false,
    "calls_this_hour": 0,
    "rate_limit": 50,
    "period": "hourly"
  }
}
```

## 💰 **Cost Breakdown:**

| Service | Cost | Requests/Day | Quality | Location-Specific |
|---------|------|--------------|---------|-------------------|
| **Foursquare** | **FREE** | **1,000** | **High** | **Yes** |
| Pexels | FREE | 4,800 | High | No |
| Unsplash | FREE | 1,200 | High | No |
| Google Places | $5/1K | Unlimited | High | Yes |

**Total monthly cost: $0** (with 1,000 requests/day free tier)

## 🎯 **Expected Results:**

- **Real restaurant photos** from Foursquare's database
- **Location-specific images** for restaurants in your area
- **High-quality fallbacks** when Foursquare doesn't have the restaurant
- **Better user engagement** with relevant, professional photos

## 🆘 **Troubleshooting:**

- **No images showing**: Check API key is correctly set
- **Rate limit errors**: Wait until next day or add more API keys
- **Poor image quality**: Foursquare provides real photos, quality depends on what restaurants upload

## 📊 **Usage Monitoring:**

The service automatically tracks:
- Daily Foursquare API calls
- Hourly Pexels/Unsplash calls
- Rate limit status
- Cache hit rates

## 🔧 **Advanced Configuration:**

You can customize the search radius and other parameters in `image_service.py`:

```python
# Search radius in meters (default: 1000m = 1km)
"radius": 1000

# Number of results to check (default: 5)
"limit": 5
```

## ✅ **Testing:**

1. Deploy your backend with the Foursquare API key
2. Make a recommendation request
3. Check the `/image-service-status` endpoint
4. Verify images are loading in your iOS app

Your app will now show real, location-specific restaurant photos!
