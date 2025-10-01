# D8 - AI-Powered Date Planning App

A complete iOS app with Python backend for intelligent date recommendations using AI and location services.

## Project Structure

```
D8/
├── D8/                          # iOS Swift/SwiftUI App
│   ├── Models/                  # Data models
│   ├── Services/                # Location and API services
│   ├── Views/                   # SwiftUI views and components
│   │   ├── DateCreationFlow/    # Date planning flow views
│   │   └── Shared/              # Reusable UI components
│   ├── Assets.xcassets/         # App assets and colors
│   ├── ContentView.swift        # Main app view
│   └── D8App.swift             # App entry point
├── Backend/                     # Python FastAPI Backend
│   ├── main.py                 # FastAPI application
│   ├── requirements.txt        # Python dependencies
│   ├── config.py               # Configuration settings
│   └── test_backend.py         # Backend tests
├── D8.xcodeproj/               # Xcode project file
└── README.md                   # This file
```

## Features

### iOS App (Swift/SwiftUI)
- **Location Services**: GPS-based location detection and permission handling
- **Date Planning Flow**: Multi-step wizard for creating date preferences
- **Cuisine Selection**: Choose from various cuisine types
- **Price Range Selection**: Set budget preferences
- **Meal Time Selection**: Choose breakfast, lunch, dinner, or drinks
- **Date Type Selection**: Casual, romantic, adventurous, etc.
- **Results Display**: AI-filtered restaurant recommendations

### Backend (Python/FastAPI)
- **REST API**: FastAPI-based backend service
- **AI Integration**: OpenAI GPT for intelligent recommendations
- **OpenStreetMap Integration**: Location-based restaurant search
- **Smart Filtering**: AI-powered recommendation scoring
- **Location Services**: Coordinate-based search capabilities

## Setup Instructions

### iOS App Setup

1. **Open in Xcode**:
   ```bash
   open D8.xcodeproj
   ```

2. **Configure Location Services**:
   - Add location usage descriptions in Info.plist
   - Ensure location permissions are properly configured

3. **Build and Run**:
   - Select your target device or simulator
   - Build and run the project (⌘+R)

### Backend Setup

1. **Navigate to Backend Directory**:
   ```bash
   cd D8/Backend
   ```

2. **Install Python Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Set Environment Variables**:
   ```bash
   export OPENAI_API_KEY="your_openai_api_key_here"
   ```

4. **Run the Backend Server**:
   ```bash
   python main.py
   ```
   
   The API will be available at `http://localhost:8000`

### Development Workflow

1. **Start Backend**: Run the Python backend server
2. **Start iOS App**: Build and run in Xcode
3. **Test Integration**: Use the app to create date preferences and see AI recommendations

## API Endpoints

- `GET /` - Health check
- `GET /health` - Detailed health status
- `POST /recommendations` - Get AI-powered date recommendations

### Example API Request

```json
{
  "location": "San Francisco, CA",
  "date_type": "romantic",
  "meal_times": ["dinner"],
  "price_range": "high",
  "cuisines": ["italian", "french"],
  "date": "2024-02-14",
  "latitude": 37.7749,
  "longitude": -122.4194
}
```

## Technologies Used

### iOS App
- **SwiftUI**: Modern declarative UI framework
- **Core Location**: GPS and location services
- **Combine**: Reactive programming framework
- **URLSession**: HTTP networking

### Backend
- **FastAPI**: Modern Python web framework
- **OpenAI API**: AI-powered recommendation filtering
- **Pydantic**: Data validation and serialization
- **Uvicorn**: ASGI server

## Development Notes

- The iOS app communicates with the backend via HTTP requests
- Location permissions are required for the app to function
- The backend uses mock data currently - replace with real OpenStreetMap API calls
- AI recommendations are powered by OpenAI's GPT models

## Contributing

1. Make changes to the iOS app in the `D8/` directory
2. Make changes to the backend in the `D8/Backend/` directory
3. Test both components together
4. Ensure the API contract between frontend and backend remains consistent

## License

This project is for educational and development purposes.
