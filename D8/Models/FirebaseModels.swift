//
//  FirebaseModels.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import FirebaseFirestore

// MARK: - User Profile
struct UserProfile: Codable {
    let userId: String
    var preferences: UserPreferences
    var diningHistory: [DiningExperience]
    var favoriteCuisines: [String] // Store as strings for Firestore
    var preferredPriceRange: String
    var lastUpdated: Date
    var totalRecommendations: Int
    var totalFeedback: Int
    
    // Onboarding data
    var ageRange: String?
    var relationshipStatus: String?
    var hobbies: [String]
    var budget: String?
    var cuisines: [String]
    var transportation: [String]
    var hasCompletedOnboarding: Bool
    
    init(userId: String) {
        self.userId = userId
        self.preferences = UserPreferences()
        self.diningHistory = []
        self.favoriteCuisines = []
        self.preferredPriceRange = "not_sure"
        self.lastUpdated = Date()
        self.totalRecommendations = 0
        self.totalFeedback = 0
        
        // Initialize onboarding data
        self.ageRange = nil
        self.relationshipStatus = nil
        self.hobbies = []
        self.budget = nil
        self.cuisines = []
        self.transportation = []
        self.hasCompletedOnboarding = false
    }
    
    // Initialize from onboarding data
    init(userId: String, onboardingData: OnboardingData) {
        self.userId = userId
        self.preferences = UserPreferences()
        self.diningHistory = []
        self.favoriteCuisines = []
        self.preferredPriceRange = "not_sure"
        self.lastUpdated = Date()
        self.totalRecommendations = 0
        self.totalFeedback = 0
        
        // Set onboarding data
        self.ageRange = onboardingData.ageRange?.rawValue
        self.relationshipStatus = onboardingData.relationshipStatus?.rawValue
        self.hobbies = onboardingData.hobbies.map { $0.rawValue }
        self.budget = onboardingData.budget?.rawValue
        self.cuisines = onboardingData.cuisines.map { $0.rawValue }
        self.transportation = onboardingData.transportation.map { $0.rawValue }
        self.hasCompletedOnboarding = true
    }
}

// MARK: - Onboarding Data Extension
extension OnboardingData {
    func toUserProfile(userId: String) -> UserProfile {
        print("🔄 Converting OnboardingData to UserProfile...")
        print("📊 OnboardingData: ageRange=\(ageRange?.rawValue ?? "nil"), relationshipStatus=\(relationshipStatus?.rawValue ?? "nil"), hobbies=\(hobbies.map { $0.rawValue }), budget=\(budget?.rawValue ?? "nil"), cuisines=\(cuisines.map { $0.rawValue }), transportation=\(transportation.map { $0.rawValue })")
        
        let userProfile = UserProfile(userId: userId, onboardingData: self)
        print("👤 Created UserProfile: hasCompletedOnboarding=\(userProfile.hasCompletedOnboarding), ageRange=\(userProfile.ageRange ?? "nil")")
        
        return userProfile
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var cuisineWeights: [String: Double] = [:]
    var priceWeights: [String: Double] = [:]
    var locationWeights: [String: Double] = [:]
    var mealTimeWeights: [String: Double] = [:]
    var averageSpending: Double = 0.0
    var preferredDistance: Double = 5000.0 // meters
}

// MARK: - Dining Experience
struct DiningExperience: Codable, Identifiable {
    let id = UUID()
    let restaurantId: String
    let restaurantName: String
    let date: Date
    let rating: Double
    let mealTime: String
    let companions: Int
    let occasion: String
    let feedback: String?
    let photos: [String]?
    let totalCost: Double?
    let wasRecommended: Bool
    let recommendationId: String?
}

// MARK: - Feedback Data
struct FeedbackData: Codable, Identifiable {
    let id = UUID()
    let userId: String
    let restaurantId: String
    let restaurantName: String
    let rating: Double
    let feedback: String?
    let wasVisited: Bool
    let visitDate: Date?
    let recommendationId: String?
    let timestamp: Date
    let feedbackAspects: [String]
}

// MARK: - Recommendation Tracking
struct RecommendationTracking: Codable {
    let id: String
    let userId: String
    let recommendations: [String] // restaurant IDs
    let timestamp: Date
    let preferences: UserPreferences
    let context: RecommendationContext
}

struct RecommendationContext: Codable {
    let location: String
    let dateType: String
    let mealTimes: [String]
    let priceRange: String
    let cuisines: [String]
    let weather: String?
    let timeOfDay: String
}

// MARK: - Explore Ideas
struct ExploreIdeas: Codable, Identifiable {
    let id: String // Format: "location_date" (e.g., "los_angeles_2025-01-15")
    let location: String // City/metro area (e.g., "Los Angeles", "Salt Lake City")
    let date: String // YYYY-MM-DD format
    let ideas: [ExploreIdea]
    let generatedAt: Date
    let expiresAt: Date // Ideas expire after 24 hours
    
    init(location: String, date: String, ideas: [ExploreIdea]) {
        self.id = "\(location.lowercased().replacingOccurrences(of: " ", with: "_"))_\(date)"
        self.location = location
        self.date = date
        self.ideas = ideas
        self.generatedAt = Date()
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
}

struct ExploreIdea: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let location: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String // "restaurant" or "activity"
    let cuisineType: String? // For restaurants
    let activityType: String? // For activities
    let priceLevel: String
    let rating: Double
    let whyRecommended: String
    let estimatedCost: String
    let bestTime: String
    let duration: String? // For activities
    let isOpen: Bool
    let openHours: String
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name, description, location, address, latitude, longitude
        case category, cuisineType, activityType, priceLevel, rating
        case whyRecommended, estimatedCost, bestTime, duration
        case isOpen, openHours, imageURL
    }
}

// MARK: - Feedback Aspect
enum FeedbackAspect: String, CaseIterable {
    case foodQuality = "food_quality"
    case atmosphere = "atmosphere"
    case service = "service"
    case value = "value"
    case location = "location"
    case cleanliness = "cleanliness"
    
    var displayName: String {
        switch self {
        case .foodQuality: return "Food Quality"
        case .atmosphere: return "Atmosphere"
        case .service: return "Service"
        case .value: return "Value for Money"
        case .location: return "Location"
        case .cleanliness: return "Cleanliness"
        }
    }
}
