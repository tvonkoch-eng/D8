"""
User Profiling System for D8 Backend
This module handles user preference learning and personalization
"""

from typing import Dict, List, Optional, Set
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
import json
import os

@dataclass
class UserPreferences:
    """User preference data structure"""
    user_id: str
    
    # Food preferences
    favorite_cuisines: Dict[str, float]  # cuisine -> preference score (0-1)
    avoided_cuisines: Set[str]
    preferred_price_ranges: Dict[str, float]  # price_range -> preference score
    dietary_restrictions: Set[str]
    meal_time_preferences: Dict[str, float]  # meal_time -> preference score
    
    # Activity preferences
    favorite_activity_types: Dict[str, float]  # activity_type -> preference score
    preferred_activity_intensity: Dict[str, float]  # intensity -> preference score
    avoided_activities: Set[str]
    
    # Location preferences
    preferred_neighborhoods: Dict[str, float]  # neighborhood -> preference score
    preferred_cities: Dict[str, float]  # city -> preference score
    max_travel_distance: int  # in miles
    
    # Date preferences
    preferred_date_types: Dict[str, float]  # date_type -> preference score
    special_occasions: Dict[str, List[str]]  # occasion -> preferred options
    
    # Behavioral data
    total_recommendations_viewed: int = 0
    total_recommendations_clicked: int = 0
    total_feedback_given: int = 0
    last_active: Optional[datetime] = None
    
    # Learning data
    feedback_history: List[Dict] = None  # List of feedback entries
    search_history: List[Dict] = None  # List of search queries
    
    def __post_init__(self):
        if self.feedback_history is None:
            self.feedback_history = []
        if self.search_history is None:
            self.search_history = []

class UserProfilingSystem:
    """Manages user preference learning and personalization"""
    
    def __init__(self, data_dir: str = "user_data"):
        self.data_dir = data_dir
        self.users: Dict[str, UserPreferences] = {}
        self._ensure_data_dir()
        self._load_existing_users()
    
    def _ensure_data_dir(self):
        """Create data directory if it doesn't exist"""
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
    
    def _load_existing_users(self):
        """Load existing user data from files"""
        for filename in os.listdir(self.data_dir):
            if filename.endswith('.json'):
                user_id = filename[:-5]  # Remove .json extension
                try:
                    with open(os.path.join(self.data_dir, filename), 'r') as f:
                        data = json.load(f)
                        self.users[user_id] = self._dict_to_preferences(data)
                except Exception as e:
                    print(f"Error loading user {user_id}: {e}")
    
    def _dict_to_preferences(self, data: dict) -> UserPreferences:
        """Convert dictionary to UserPreferences object"""
        # Convert sets back from lists
        for field in ['avoided_cuisines', 'dietary_restrictions', 'avoided_activities']:
            if field in data and isinstance(data[field], list):
                data[field] = set(data[field])
        
        # Convert datetime strings back to datetime objects
        if 'last_active' in data and data['last_active']:
            data['last_active'] = datetime.fromisoformat(data['last_active'])
        
        return UserPreferences(**data)
    
    def _preferences_to_dict(self, prefs: UserPreferences) -> dict:
        """Convert UserPreferences object to dictionary for JSON serialization"""
        data = asdict(prefs)
        
        # Convert sets to lists for JSON serialization
        for field in ['avoided_cuisines', 'dietary_restrictions', 'avoided_activities']:
            if field in data and isinstance(data[field], set):
                data[field] = list(data[field])
        
        # Convert datetime to string for JSON serialization
        if data['last_active']:
            data['last_active'] = data['last_active'].isoformat()
        
        return data
    
    def get_or_create_user(self, user_id: str) -> UserPreferences:
        """Get existing user or create new one"""
        if user_id not in self.users:
            self.users[user_id] = UserPreferences(
                user_id=user_id,
                favorite_cuisines={},
                avoided_cuisines=set(),
                preferred_price_ranges={},
                dietary_restrictions=set(),
                meal_time_preferences={},
                favorite_activity_types={},
                preferred_activity_intensity={},
                avoided_activities=set(),
                preferred_neighborhoods={},
                preferred_cities={},
                max_travel_distance=10,
                preferred_date_types={},
                special_occasions={}
            )
        return self.users[user_id]
    
    def save_user(self, user_id: str):
        """Save user preferences to file"""
        if user_id in self.users:
            filename = os.path.join(self.data_dir, f"{user_id}.json")
            with open(filename, 'w') as f:
                json.dump(self._preferences_to_dict(self.users[user_id]), f, indent=2)
    
    def record_search(self, user_id: str, search_data: dict):
        """Record a search query for learning"""
        user = self.get_or_create_user(user_id)
        user.search_history.append({
            'timestamp': datetime.now().isoformat(),
            'query': search_data
        })
        user.last_active = datetime.now()
        self.save_user(user_id)
    
    def record_feedback(self, user_id: str, recommendation_id: str, feedback_type: str, 
                       rating: Optional[float] = None, comments: Optional[str] = None):
        """Record user feedback on a recommendation"""
        user = self.get_or_create_user(user_id)
        user.feedback_history.append({
            'timestamp': datetime.now().isoformat(),
            'recommendation_id': recommendation_id,
            'feedback_type': feedback_type,  # 'positive', 'negative', 'neutral'
            'rating': rating,
            'comments': comments
        })
        user.total_feedback_given += 1
        user.last_active = datetime.now()
        self.save_user(user_id)
    
    def record_interaction(self, user_id: str, interaction_type: str, data: dict):
        """Record user interactions (views, clicks, etc.)"""
        user = self.get_or_create_user(user_id)
        
        if interaction_type == 'view':
            user.total_recommendations_viewed += 1
        elif interaction_type == 'click':
            user.total_recommendations_clicked += 1
        
        user.last_active = datetime.now()
        self.save_user(user_id)
    
    def learn_from_feedback(self, user_id: str):
        """Update preferences based on feedback history"""
        user = self.get_or_create_user(user_id)
        
        # Analyze recent feedback (last 30 days)
        recent_feedback = [
            fb for fb in user.feedback_history
            if datetime.fromisoformat(fb['timestamp']) > datetime.now() - timedelta(days=30)
        ]
        
        if not recent_feedback:
            return
        
        # Learn from positive feedback
        positive_feedback = [fb for fb in recent_feedback if fb['feedback_type'] == 'positive']
        negative_feedback = [fb for fb in recent_feedback if fb['feedback_type'] == 'negative']
        
        # Update preferences based on feedback patterns
        self._update_cuisine_preferences(user, positive_feedback, negative_feedback)
        self._update_price_preferences(user, positive_feedback, negative_feedback)
        self._update_activity_preferences(user, positive_feedback, negative_feedback)
        
        self.save_user(user_id)
    
    def _update_cuisine_preferences(self, user: UserPreferences, positive: List[dict], negative: List[dict]):
        """Update cuisine preferences based on feedback"""
        # This would analyze the recommendations that got positive/negative feedback
        # and update the user's cuisine preferences accordingly
        # For now, this is a placeholder for the learning logic
        pass
    
    def _update_price_preferences(self, user: UserPreferences, positive: List[dict], negative: List[dict]):
        """Update price preferences based on feedback"""
        # Similar to cuisine preferences
        pass
    
    def _update_activity_preferences(self, user: UserPreferences, positive: List[dict], negative: List[dict]):
        """Update activity preferences based on feedback"""
        # Similar to cuisine preferences
        pass
    
    def get_personalized_recommendations(self, user_id: str, base_recommendations: List[dict]) -> List[dict]:
        """Apply personalization to recommendations based on user preferences"""
        user = self.get_or_create_user(user_id)
        
        # Apply personalization scoring
        personalized = []
        for rec in base_recommendations:
            score = self._calculate_personalization_score(user, rec)
            rec['personalization_score'] = score
            personalized.append(rec)
        
        # Sort by personalization score
        personalized.sort(key=lambda x: x['personalization_score'], reverse=True)
        return personalized
    
    def _calculate_personalization_score(self, user: UserPreferences, recommendation: dict) -> float:
        """Calculate how well a recommendation matches user preferences"""
        score = 0.0
        
        # Cuisine preference scoring
        cuisine = recommendation.get('cuisine_type', '').lower()
        if cuisine in user.favorite_cuisines:
            score += user.favorite_cuisines[cuisine] * 0.3
        elif cuisine in user.avoided_cuisines:
            score -= 0.5
        
        # Price preference scoring
        price_level = recommendation.get('price_level', 'medium')
        if price_level in user.preferred_price_ranges:
            score += user.preferred_price_ranges[price_level] * 0.2
        
        # Location preference scoring
        location = recommendation.get('location', '').lower()
        for neighborhood in user.preferred_neighborhoods:
            if neighborhood.lower() in location:
                score += user.preferred_neighborhoods[neighborhood] * 0.2
        
        # Activity preference scoring (for activity recommendations)
        activity_type = recommendation.get('cuisine_type', '').lower()  # Using cuisine_type field for activity type
        if activity_type in user.favorite_activity_types:
            score += user.favorite_activity_types[activity_type] * 0.3
        elif activity_type in user.avoided_activities:
            score -= 0.5
        
        return max(0.0, min(1.0, score))  # Clamp between 0 and 1

# Data Collection Strategies
class DataCollectionStrategies:
    """Strategies for collecting user preference data"""
    
    @staticmethod
    def implicit_data_collection():
        """Collect data without explicit user input"""
        return {
            "search_patterns": "Track what users search for most",
            "click_behavior": "See which recommendations get clicked",
            "time_spent": "How long users spend viewing recommendations",
            "return_visits": "Track if users return to same recommendations",
            "session_length": "How long users spend in the app",
            "abandonment_points": "Where users drop off in the flow"
        }
    
    @staticmethod
    def explicit_data_collection():
        """Collect data through direct user input"""
        return {
            "onboarding_survey": "Initial preference questionnaire",
            "feedback_buttons": "Like/dislike buttons on recommendations",
            "rating_system": "Star ratings for recommendations",
            "preference_updates": "Settings page to update preferences",
            "special_occasions": "Ask about upcoming special dates",
            "dietary_restrictions": "Food allergies and dietary preferences"
        }
    
    @staticmethod
    def progressive_profiling():
        """Gradually build user profile over time"""
        return {
            "step_1": "Basic preferences (cuisine, price, location)",
            "step_2": "Activity preferences and intensity",
            "step_3": "Special occasions and dietary needs",
            "step_4": "Advanced preferences (atmosphere, timing)",
            "step_5": "Feedback and refinement"
        }

# Usage Examples
def example_usage():
    """Example of how to use the user profiling system"""
    
    # Initialize the system
    profiling = UserProfilingSystem()
    
    # Get or create a user
    user_id = "user_123"
    user = profiling.get_or_create_user(user_id)
    
    # Record a search
    search_data = {
        "location": "San Francisco",
        "date_type": "meal",
        "cuisines": ["italian", "french"],
        "price_range": "high"
    }
    profiling.record_search(user_id, search_data)
    
    # Record feedback
    profiling.record_feedback(user_id, "rec_456", "positive", rating=4.5, comments="Great atmosphere!")
    
    # Record interactions
    profiling.record_interaction(user_id, "view", {"recommendation_id": "rec_456"})
    profiling.record_interaction(user_id, "click", {"recommendation_id": "rec_456"})
    
    # Learn from feedback
    profiling.learn_from_feedback(user_id)
    
    # Get personalized recommendations
    base_recommendations = [
        {"name": "Restaurant A", "cuisine_type": "italian", "price_level": "high"},
        {"name": "Restaurant B", "cuisine_type": "mexican", "price_level": "medium"}
    ]
    
    personalized = profiling.get_personalized_recommendations(user_id, base_recommendations)
    print("Personalized recommendations:", personalized)

if __name__ == "__main__":
    example_usage()
