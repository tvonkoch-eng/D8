//
//  RestaurantDatabaseService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

class RestaurantDatabaseService: ObservableObject {
    static let shared = RestaurantDatabaseService()
    
    private let firebaseService = FirebaseService.shared
    private let openAIService = OpenAIService.shared
    
    // Cache for quick access
    private var restaurantCache: [String: RestaurantDatabaseEntry] = [:]
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save or update restaurant details in the database
    func saveRestaurant(_ restaurant: RestaurantRecommendation) async throws {
        let entry = RestaurantDatabaseEntry(from: restaurant)
        let restaurantId = generateRestaurantId(from: restaurant)
        
        // Update cache
        restaurantCache[restaurantId] = entry
        
        // Save to Firebase
        try await firebaseService.saveRestaurantDatabaseEntry(entry, restaurantId: restaurantId)
        
        print("✅ [RestaurantDatabaseService] Saved restaurant: \(restaurant.name)")
    }
    
    /// Batch save multiple restaurants
    func saveRestaurants(_ restaurants: [RestaurantRecommendation]) async throws {
        print("🔄 [RestaurantDatabaseService] Batch saving \(restaurants.count) restaurants...")
        
        for restaurant in restaurants {
            try await saveRestaurant(restaurant)
        }
        
        print("✅ [RestaurantDatabaseService] Batch save completed")
    }
    
    /// Get restaurant details from database
    func getRestaurantDetails(for restaurant: RestaurantRecommendation) async throws -> RestaurantDatabaseEntry? {
        let restaurantId = generateRestaurantId(from: restaurant)
        
        // Check cache first
        if let cachedEntry = restaurantCache[restaurantId] {
            return cachedEntry
        }
        
        // Check Firebase
        if let entry = try await firebaseService.getRestaurantDatabaseEntry(for: restaurantId) {
            restaurantCache[restaurantId] = entry
            return entry
        }
        
        return nil
    }
    
    /// Get restaurant details by ID
    func getRestaurantDetails(byId restaurantId: String) async throws -> RestaurantDatabaseEntry? {
        // Check cache first
        if let cachedEntry = restaurantCache[restaurantId] {
            return cachedEntry
        }
        
        // Check Firebase
        if let entry = try await firebaseService.getRestaurantDatabaseEntry(for: restaurantId) {
            restaurantCache[restaurantId] = entry
            return entry
        }
        
        return nil
    }
    
    /// Check if restaurant exists in database
    func restaurantExists(_ restaurant: RestaurantRecommendation) async throws -> Bool {
        let restaurantId = generateRestaurantId(from: restaurant)
        
        // Check cache first
        if restaurantCache[restaurantId] != nil {
            return true
        }
        
        // Check Firebase
        return try await firebaseService.restaurantDatabaseEntryExists(for: restaurantId)
    }
    
    /// Get restaurants by location (for ExploreView)
    func getRestaurantsByLocation(location: String, limit: Int = 50) async throws -> [RestaurantDatabaseEntry] {
        return try await firebaseService.getRestaurantsByLocation(location: location, limit: limit)
    }
    
    /// Get restaurants by cuisine type
    func getRestaurantsByCuisine(cuisine: String, limit: Int = 50) async throws -> [RestaurantDatabaseEntry] {
        return try await firebaseService.getRestaurantsByCuisine(cuisine: cuisine, limit: limit)
    }
    
    /// Search restaurants by name
    func searchRestaurants(query: String, limit: Int = 20) async throws -> [RestaurantDatabaseEntry] {
        return try await firebaseService.searchRestaurants(query: query, limit: limit)
    }
    
    /// Get popular restaurants (based on views/feedback)
    func getPopularRestaurants(limit: Int = 20) async throws -> [RestaurantDatabaseEntry] {
        return try await firebaseService.getPopularRestaurantsFromDatabase(limit: limit)
    }
    
    /// Update restaurant details (when user views details)
    func updateRestaurantViewCount(_ restaurant: RestaurantRecommendation) async throws {
        let restaurantId = generateRestaurantId(from: restaurant)
        
        // Update in Firebase
        try await firebaseService.incrementRestaurantViewCount(restaurantId: restaurantId)
        
        // Update cache if exists
        if var cachedEntry = restaurantCache[restaurantId] {
            cachedEntry.viewCount += 1
            cachedEntry.lastViewed = Date()
            restaurantCache[restaurantId] = cachedEntry
        }
    }
    
    /// Get restaurant statistics
    func getRestaurantStats() async throws -> RestaurantDatabaseStats {
        return try await firebaseService.getRestaurantDatabaseStats()
    }
    
    /// Clean up old entries (for maintenance)
    func cleanupOldEntries() async throws {
        try await firebaseService.cleanupOldRestaurantDatabaseEntries()
    }
    
    // MARK: - Private Methods
    
    private func generateRestaurantId(from restaurant: RestaurantRecommendation) -> String {
        // Use address + coordinates for unique identification
        let address = restaurant.address.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        let coordinates = "\(restaurant.latitude),\(restaurant.longitude)"
        
        return "\(address)_\(coordinates)".hashValue.description
    }
}

// MARK: - Restaurant Database Entry Model
struct RestaurantDatabaseEntry: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let location: String
    let address: String
    let latitude: Double
    let longitude: Double
    let cuisineType: String
    let priceLevel: String
    let rating: Double
    let whyRecommended: String
    let estimatedCost: String
    let bestTime: String
    let duration: String?
    let isOpen: Bool
    let openHours: String?
    let imageURL: String?
    let websiteURL: String?
    let menuURL: String?
    
    // Database-specific fields
    var viewCount: Int
    var lastViewed: Date?
    let createdAt: Date
    var lastUpdated: Date
    
    // Enhanced details (populated later)
    var enhancedDescription: String?
    var operatingHours: [String]?
    var additionalInfo: String?
    var hasEnhancedDetails: Bool
    
    init(from restaurant: RestaurantRecommendation) {
        self.id = ""
        self.name = restaurant.name
        self.description = restaurant.description
        self.location = restaurant.location
        self.address = restaurant.address
        self.latitude = restaurant.latitude
        self.longitude = restaurant.longitude
        self.cuisineType = restaurant.cuisineType
        self.priceLevel = restaurant.priceLevel
        self.rating = restaurant.rating
        self.whyRecommended = restaurant.whyRecommended
        self.estimatedCost = restaurant.estimatedCost
        self.bestTime = restaurant.bestTime
        self.duration = restaurant.duration
        self.isOpen = restaurant.isOpen
        self.openHours = restaurant.openHours
        self.imageURL = restaurant.imageURL
        self.websiteURL = restaurant.websiteURL
        self.menuURL = restaurant.menuURL
        
        // Database fields
        self.viewCount = 0
        self.lastViewed = nil
        self.createdAt = Date()
        self.lastUpdated = Date()
        
        // Enhanced details (initially empty)
        self.enhancedDescription = nil
        self.operatingHours = nil
        self.additionalInfo = nil
        self.hasEnhancedDetails = false
    }
    
    init(
        id: String,
        name: String,
        description: String,
        location: String,
        address: String,
        latitude: Double,
        longitude: Double,
        cuisineType: String,
        priceLevel: String,
        rating: Double,
        whyRecommended: String,
        estimatedCost: String,
        bestTime: String,
        duration: String?,
        isOpen: Bool,
        openHours: String?,
        imageURL: String?,
        websiteURL: String?,
        menuURL: String?,
        viewCount: Int,
        lastViewed: Date?,
        createdAt: Date,
        lastUpdated: Date,
        enhancedDescription: String?,
        operatingHours: [String]?,
        additionalInfo: String?,
        hasEnhancedDetails: Bool
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.location = location
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.cuisineType = cuisineType
        self.priceLevel = priceLevel
        self.rating = rating
        self.whyRecommended = whyRecommended
        self.estimatedCost = estimatedCost
        self.bestTime = bestTime
        self.duration = duration
        self.isOpen = isOpen
        self.openHours = openHours
        self.imageURL = imageURL
        self.websiteURL = websiteURL
        self.menuURL = menuURL
        self.viewCount = viewCount
        self.lastViewed = lastViewed
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.enhancedDescription = enhancedDescription
        self.operatingHours = operatingHours
        self.additionalInfo = additionalInfo
        self.hasEnhancedDetails = hasEnhancedDetails
    }
    
    /// Update with enhanced details
    func withEnhancedDetails(
        enhancedDescription: String,
        operatingHours: [String],
        additionalInfo: String
    ) -> RestaurantDatabaseEntry {
        return RestaurantDatabaseEntry(
            id: self.id,
            name: self.name,
            description: self.description,
            location: self.location,
            address: self.address,
            latitude: self.latitude,
            longitude: self.longitude,
            cuisineType: self.cuisineType,
            priceLevel: self.priceLevel,
            rating: self.rating,
            whyRecommended: self.whyRecommended,
            estimatedCost: self.estimatedCost,
            bestTime: self.bestTime,
            duration: self.duration,
            isOpen: self.isOpen,
            openHours: self.openHours,
            imageURL: self.imageURL,
            websiteURL: self.websiteURL,
            menuURL: self.menuURL,
            viewCount: self.viewCount,
            lastViewed: self.lastViewed,
            createdAt: self.createdAt,
            lastUpdated: Date(),
            enhancedDescription: enhancedDescription,
            operatingHours: operatingHours,
            additionalInfo: additionalInfo,
            hasEnhancedDetails: true
        )
    }
}

// MARK: - Restaurant Database Stats
struct RestaurantDatabaseStats: Codable {
    let totalRestaurants: Int
    let restaurantsWithEnhancedDetails: Int
    let totalViews: Int
    let averageRating: Double
    let mostPopularCuisine: String
    let lastUpdated: Date
}
