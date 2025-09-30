import os
from typing import Optional

class Config:
    # API Configuration
    OPENAI_API_KEY: Optional[str] = os.getenv("OPENAI_API_KEY")
    
    # Server Configuration
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    
    # OpenStreetMap Configuration
    OVERPASS_API_URLS: list = [
        "https://overpass-api.de/api/interpreter",
        "https://lz4.overpass-api.de/api/interpreter",
        "https://z.overpass-api.de/api/interpreter"
    ]
    NOMINATIM_API_URL: str = "https://nominatim.openstreetmap.org"
    
    # Search Configuration
    DEFAULT_SEARCH_RADIUS: int = 5000  # meters
    MAX_RESULTS: int = 20
    
    # AI Configuration
    AI_MODEL: str = "gpt-3.5-turbo"
    MAX_TOKENS: int = 3000
    TEMPERATURE: float = 0.7
    
    @classmethod
    def validate(cls) -> bool:
        """Validate configuration"""
        if not cls.OPENAI_API_KEY:
            print("Warning: OPENAI_API_KEY not set. AI features will be disabled.")
            return False
        return True
