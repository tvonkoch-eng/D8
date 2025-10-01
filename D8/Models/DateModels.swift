//
//  DateModels.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

// MARK: - Date Type
enum DateType: CaseIterable, Hashable {
    case meal, activity
    
    var displayName: String {
        switch self {
        case .meal: return "MEAL"
        case .activity: return "ACTIVITY"
        }
    }
    
    var description: String {
        switch self {
        case .meal: return "Restaurants, cafes, and dining experiences"
        case .activity: return "Bowling, hiking, sports, and fun activities"
        }
    }
    
    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .activity: return "figure.run"
        }
    }
}

// MARK: - Meal Time
enum MealTime: CaseIterable, Hashable {
    case breakfast, lunch, dinner, notSure
    
    var displayName: String {
        switch self {
        case .breakfast: return "BREAKFAST"
        case .lunch: return "LUNCH"
        case .dinner: return "DINNER"
        case .notSure: return "NOT SURE"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "sunset"
        case .notSure: return "questionmark.circle"
        }
    }
}

// MARK: - Price Range
enum PriceRange: CaseIterable, Hashable {
    case free, low, medium, high, luxury, notSure
    
    var displayName: String {
        switch self {
        case .free: return "FREE"
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        case .luxury: return "LUXURY"
        case .notSure: return "NOT SURE"
        }
    }
    
    var description: String? {
        switch self {
        case .free: return "$0"
        case .low: return "$1-25"
        case .medium: return "$26-75"
        case .high: return "$76-150"
        case .luxury: return "$150+"
        case .notSure: return nil
        }
    }
    
    var icon: String {
        switch self {
        case .free: return "gift"
        case .low: return "dollarsign.circle"
        case .medium: return "dollarsign.circle.fill"
        case .high: return "banknote"
        case .luxury: return "crown"
        case .notSure: return "questionmark.circle"
        }
    }
}

// MARK: - Activity Type
enum ActivityType: CaseIterable, Hashable {
    case sports, outdoor, indoor, entertainment, fitness, notSure
    
    var displayName: String {
        switch self {
        case .sports: return "SPORTS"
        case .outdoor: return "OUTDOOR"
        case .indoor: return "INDOOR"
        case .entertainment: return "ENTERTAINMENT"
        case .fitness: return "FITNESS"
        case .notSure: return "NOT SURE"
        }
    }
    
    var description: String {
        switch self {
        case .sports: return "Bowling, tennis, golf, etc."
        case .outdoor: return "Hiking, biking, parks, etc."
        case .indoor: return "Museums, escape rooms, etc."
        case .entertainment: return "Movies, shows, games, etc."
        case .fitness: return "Gym, yoga, rock climbing, etc."
        case .notSure: return "I'm open to anything"
        }
    }
    
    var icon: String {
        switch self {
        case .sports: return "sportscourt"
        case .outdoor: return "leaf"
        case .indoor: return "house"
        case .entertainment: return "tv"
        case .fitness: return "figure.strengthtraining.traditional"
        case .notSure: return "questionmark.circle"
        }
    }
}

// MARK: - Activity Intensity
enum ActivityIntensity: CaseIterable, Hashable {
    case low, medium, high, notSure
    
    var displayName: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        case .notSure: return "NOT SURE"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Relaxed, easy activities"
        case .medium: return "Moderate effort required"
        case .high: return "High energy, intense activities"
        case .notSure: return "I'm flexible"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "figure.walk"
        case .medium: return "figure.run"
        case .high: return "figure.strengthtraining.traditional"
        case .notSure: return "questionmark.circle"
        }
    }
}

// MARK: - Cuisine
enum Cuisine: CaseIterable, Hashable {
    case italian, mexican, american, japanese, chinese, indian, thai, french, mediterranean, notSure
    
    var displayName: String {
        switch self {
        case .italian: return "ITALIAN"
        case .mexican: return "MEXICAN"
        case .american: return "AMERICAN"
        case .japanese: return "JAPANESE"
        case .chinese: return "CHINESE"
        case .indian: return "INDIAN"
        case .thai: return "THAI"
        case .french: return "FRENCH"
        case .mediterranean: return "MEDITERRANEAN"
        case .notSure: return "NOT SURE"
        }
    }
    
    var emoji: String {
        switch self {
        case .italian: return "🍝"
        case .mexican: return "🌮"
        case .american: return "🍔"
        case .japanese: return "🍣"
        case .chinese: return "🥢"
        case .indian: return "🍛"
        case .thai: return "🌶️"
        case .french: return "🥐"
        case .mediterranean: return "🫒"
        case .notSure: return "❓"
        }
    }
}

// MARK: - Date Recommendation
struct DateRecommendation: Identifiable {
    let id = UUID()
    let place: OSMPlace
    let dateType: DateType
    let mealTime: MealTime?
    let priceRange: PriceRange?
    let cuisines: Set<Cuisine>
    let activityTypes: Set<ActivityType>?
    let activityIntensity: ActivityIntensity?
    let distance: Double? // in meters
    let matchScore: Double // 0.0 to 1.0
    
    var title: String {
        place.displayName
    }
    
    var subtitle: String {
        var components: [String] = []
        
        if let cuisine = place.cuisine, !cuisine.isEmpty {
            components.append(cuisine.capitalized)
        }
        
        if let distance = distance {
            let distanceKm = distance / 1000
            if distanceKm < 1 {
                components.append("\(Int(distance))m away")
            } else {
                components.append("\(String(format: "%.1f", distanceKm))km away")
            }
        }
        
        return components.joined(separator: " • ")
    }
    
    var icon: String {
        switch place.amenity {
        case "restaurant": return "🍽️"
        case "cafe": return "☕"
        case "bar": return "🍸"
        case "fast_food": return "🍔"
        default: return "📍"
        }
    }
}

// MARK: - Scheduled Event
struct ScheduledEvent: Identifiable, Codable {
    let id = UUID()
    let userId: String // Link to user profile
    let name: String
    let description: String
    let location: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String // "restaurant" or "activity"
    let cuisineType: String?
    let activityType: String?
    let priceLevel: String
    let rating: Double
    let estimatedCost: String
    let duration: String?
    let scheduledDate: Date
    let scheduledTime: Date
    let notes: String?
    let isCompleted: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId, name, description, location, address, latitude, longitude
        case category, cuisineType, activityType, priceLevel, rating
        case estimatedCost, duration, scheduledDate, scheduledTime
        case notes, isCompleted, createdAt
    }
    
    init(userId: String, name: String, description: String, location: String, address: String, 
         latitude: Double, longitude: Double, category: String, 
         cuisineType: String?, activityType: String?, priceLevel: String, 
         rating: Double, estimatedCost: String, duration: String?, 
         scheduledDate: Date, scheduledTime: Date, notes: String? = nil) {
        self.userId = userId
        self.name = name
        self.description = description
        self.location = location
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.cuisineType = cuisineType
        self.activityType = activityType
        self.priceLevel = priceLevel
        self.rating = rating
        self.estimatedCost = estimatedCost
        self.duration = duration
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.notes = notes
        self.isCompleted = false
        self.createdAt = Date()
    }
    
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: scheduledDate)
    }
    
    var categoryIcon: String {
        switch category {
        case "restaurant": return "fork.knife"
        case "activity": return "figure.run"
        default: return "calendar"
        }
    }
    
    var categoryColor: String {
        switch category {
        case "restaurant": return "blue"
        case "activity": return "purple"
        default: return "gray"
        }
    }
}
