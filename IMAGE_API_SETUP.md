# Image API Setup Guide

This guide will help you set up free image APIs for better, more relevant images in your D8 app.

## 🎯 **Recommended Free APIs (in order of preference):**

### 1. **Pexels API** (BEST - Completely Free)
- **Cost**: 100% Free
- **Rate Limit**: 200 requests/hour
- **Quality**: High-quality, professional photos
- **Setup**: 
  1. Go to https://www.pexels.com/api/
  2. Sign up for free account
  3. Get your API key
  4. Replace `YOUR_PEXELS_API_KEY` in `ImageService.swift`

### 2. **Unsplash API** (Good - Free with limits)
- **Cost**: Free
- **Rate Limit**: 50 requests/hour
- **Quality**: High-quality, artistic photos
- **Setup**:
  1. Go to https://unsplash.com/developers
  2. Create new application
  3. Get your Access Key
  4. Replace `YOUR_UNSPLASH_ACCESS_KEY` in `ImageService.swift`

### 3. **Foursquare Places API** (Location-specific)
- **Cost**: Free tier available
- **Rate Limit**: 1,000 requests/day
- **Quality**: Location-specific business photos
- **Setup**:
  1. Go to https://developer.foursquare.com/
  2. Create account and app
  3. Get your API key
  4. Replace `YOUR_FOURSQUARE_API_KEY` in `ImageService.swift`

## 🚀 **Quick Setup (5 minutes):**

1. **Get Pexels API Key** (Recommended):
   - Visit: https://www.pexels.com/api/
   - Click "Get Started" → Sign up
   - Copy your API key
   - Open `D8/Services/ImageService.swift`
   - Replace `YOUR_PEXELS_API_KEY` with your actual key

2. **Test the setup**:
   - Build and run your app
   - Check ExploreView and DateCreationFlow
   - You should see much better, relevant images!

## 💡 **How it works:**

The new `ImageService` will:
1. **Try Pexels first** - Most relevant, free images
2. **Fallback to Unsplash** - If Pexels fails
3. **Location-based search** - Uses your location + activity type
4. **Smart caching** - Avoids repeated API calls
5. **Rate limiting** - Respects API limits automatically

## 🔧 **Current Fallback:**

If no API keys are configured, the app will use:
- **Activities**: Relevant Unsplash images (sports, outdoor, etc.)
- **Restaurants**: Lorem Picsum with consistent seeding

## 📱 **Expected Results:**

- **Sailing activities**: Beautiful outdoor/nature photos
- **Restaurants**: Food photos matching cuisine type
- **Fitness activities**: Gym/workout photos
- **Entertainment**: Venue/activity photos
- **Location-specific**: Images from your actual area

## 🆘 **Troubleshooting:**

- **No images showing**: Check API keys are correctly set
- **Rate limit errors**: Wait an hour or add more API keys
- **Poor image quality**: Try different search terms in `getSearchQuery`

## 💰 **Cost Comparison:**

| API | Cost | Requests/Hour | Quality | Location-Specific |
|-----|------|---------------|---------|-------------------|
| Pexels | Free | 200 | High | No |
| Unsplash | Free | 50 | High | No |
| Foursquare | Free tier | 1,000/day | Medium | Yes |
| Google Places | $29/1,000 | Unlimited | High | Yes |

**Recommendation**: Start with Pexels (free, high quality) and add Foursquare for location-specific images.
