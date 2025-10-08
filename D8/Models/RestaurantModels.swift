//
//  RestaurantModels.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

// MARK: - Restaurant Recommendation
struct RestaurantRecommendation: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let location: String
    let address: String
    let latitude: Double
    let longitude: Double
    let cuisineType: String
    let priceLevel: String
    let isOpen: Bool
    let openHours: String
    let rating: Double
    let whyRecommended: String
    let estimatedCost: String
    let bestTime: String
    let duration: String?
    let imageURL: String?
    let websiteURL: String?
    let menuURL: String?
    
    // Add feedback tracking
    var userRating: Double? = nil
    var userFeedback: String? = nil
    var wasVisited: Bool = false
    var visitDate: Date? = nil
    var feedbackId: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case name, description, location, address, latitude, longitude
        case cuisineType = "cuisine_type"
        case priceLevel = "price_level"
        case isOpen = "is_open"
        case openHours = "open_hours"
        case rating
        case whyRecommended = "why_recommended"
        case estimatedCost = "estimated_cost"
        case bestTime = "best_time"
        case duration
        case imageURL = "image_url"
        case websiteURL = "website_url"
        case menuURL = "menu_url"
    }
    
    // Computed properties for UI
    var displayName: String {
        name
    }
    
    var subtitle: String {
        var components: [String] = []
        components.append(cuisineType.capitalized)
        components.append(location)
        return components.joined(separator: " • ")
    }
    
    var icon: String {
        switch cuisineType.lowercased() {
        case "italian": return "🍝"
        case "mexican": return "🌮"
        case "american": return "🍔"
        case "japanese": return "🍣"
        case "chinese": return "🥢"
        case "indian": return "🍛"
        case "thai": return "🌶️"
        case "french": return "🥐"
        case "mediterranean": return "🫒"
        case "steakhouse": return "🥩"
        case "seafood": return "🐟"
        case "contemporary": return "🍽️"
        default: return "🍽️"
        }
    }
    
    var priceIcon: String {
        switch priceLevel.lowercased() {
        case "free": return "🎁"
        case "low": return "💵"
        case "medium": return "💸"
        case "high": return "💰"
        case "luxury": return "👑"
        default: return "💸"
        }
    }
    
    var ratingStars: String {
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
        
        var stars = String(repeating: "⭐", count: fullStars)
        if hasHalfStar {
            stars += "✨"
        }
        stars += String(repeating: "☆", count: emptyStars)
        return stars
    }
    
    var isOpenStatus: String {
        isOpen ? "Open" : "Closed"
    }
    
    var isOpenColor: String {
        isOpen ? "green" : "red"
    }
}

// MARK: - Restaurant Request
struct RestaurantRequest: Codable {
    let dateType: String
    let mealTimes: [String]
    let priceRange: String
    let cuisines: [String]
    let date: String
    let location: String
    let latitude: Double?
    let longitude: Double?
    
    // User profile data for personalization
    let userId: String?
    let userAgeRange: String?
    let userRelationshipStatus: String?
    let userHobbies: [String]?
    let userBudget: String?
    let userCuisines: [String]?
    let userTransportation: [String]?
    let userFavoriteCuisines: [String]?
    let userPreferredPriceRange: String?
    
    enum CodingKeys: String, CodingKey {
        case dateType = "date_type"
        case mealTimes = "meal_times"
        case priceRange = "price_range"
        case cuisines
        case date, location, latitude, longitude
        case userId = "user_id"
        case userAgeRange = "user_age_range"
        case userRelationshipStatus = "user_relationship_status"
        case userHobbies = "user_hobbies"
        case userBudget = "user_budget"
        case userCuisines = "user_cuisines"
        case userTransportation = "user_transportation"
        case userFavoriteCuisines = "user_favorite_cuisines"
        case userPreferredPriceRange = "user_preferred_price_range"
    }
}

// MARK: - Restaurant Response
struct RestaurantResponse: Codable {
    let recommendations: [RestaurantRecommendation]
    let totalFound: Int
    let queryUsed: String
    let processingTime: Double
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case totalFound = "total_found"
        case queryUsed = "query_used"
        case processingTime = "processing_time"
    }
}

// MARK: - Restaurant Service
class RestaurantService: ObservableObject {
    static let shared = RestaurantService()
    
    // Railway production backend URL
    private let baseURL = "https://dbbackend-production-2721.up.railway.app"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if the backend is healthy and accessible
    func checkHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(.failure(RestaurantError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200
                DispatchQueue.main.async {
                    completion(.success(isHealthy))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(RestaurantError.serverError("Invalid response")))
                }
            }
        }.resume()
    }
    
    /// Get AI-powered restaurant recommendations
    func getRestaurantRecommendations(
        dateType: DateType,
        mealTimes: Set<MealTime>,
        priceRange: PriceRange?,
        cuisines: Set<Cuisine>,
        date: Date,
        location: String,
        coordinate: CLLocationCoordinate2D?,
        completion: @escaping (Result<[RestaurantRecommendation], Error>) -> Void
    ) {
        // Get user profile data for personalization
        let userProfile = UserProfileService.shared.userProfile
        
        let request = RestaurantRequest(
            dateType: mapDateTypeToString(dateType),
            mealTimes: mealTimes.map { mapMealTimeToString($0) },
            priceRange: priceRange.map { mapPriceRangeToString($0) } ?? "not_sure",
            cuisines: cuisines.map { mapCuisineToString($0) },
            date: formatDateForBackend(date),
            location: location,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            userId: userProfile?.userId,
            userAgeRange: userProfile?.ageRange,
            userRelationshipStatus: userProfile?.relationshipStatus,
            userHobbies: userProfile?.hobbies,
            userBudget: userProfile?.budget,
            userCuisines: userProfile?.cuisines,
            userTransportation: userProfile?.transportation,
            userFavoriteCuisines: userProfile?.favoriteCuisines,
            userPreferredPriceRange: userProfile?.preferredPriceRange
        )
        
        makeRequest(endpoint: "/recommendations", request: request, completion: completion)
    }
    
    // MARK: - Private Methods
    private func makeRequest(
        endpoint: String,
        request: RestaurantRequest,
        completion: @escaping (Result<[RestaurantRecommendation], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(RestaurantError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(RestaurantError.noData))
                }
                return
            }
            
            // Check for HTTP error status
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // Try to decode error message
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    DispatchQueue.main.async {
                        completion(.failure(RestaurantError.serverError(errorResponse.detail)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(RestaurantError.serverError("Server error with status \(httpResponse.statusCode)")))
                    }
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(RestaurantResponse.self, from: data)
                // Generate image URLs for recommendations that don't have them
                let recommendationsWithImages = response.recommendations.map { recommendation in
                    var updatedRecommendation = recommendation
                    if updatedRecommendation.imageURL == nil {
                        updatedRecommendation = RestaurantRecommendation(
                            name: recommendation.name,
                            description: recommendation.description,
                            location: recommendation.location,
                            address: recommendation.address,
                            latitude: recommendation.latitude,
                            longitude: recommendation.longitude,
                            cuisineType: recommendation.cuisineType,
                            priceLevel: recommendation.priceLevel,
                            isOpen: recommendation.isOpen,
                            openHours: recommendation.openHours,
                            rating: recommendation.rating,
                            whyRecommended: recommendation.whyRecommended,
                            estimatedCost: recommendation.estimatedCost,
                            bestTime: recommendation.bestTime,
                            duration: recommendation.duration,
                            imageURL: self.generateImageURL(for: recommendation.cuisineType, name: recommendation.name),
                            websiteURL: recommendation.websiteURL,
                            menuURL: recommendation.menuURL
                        )
                    }
                    return updatedRecommendation
                }
                DispatchQueue.main.async {
                    completion(.success(recommendationsWithImages))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Mapping Functions
    private func mapDateTypeToString(_ dateType: DateType) -> String {
        switch dateType {
        case .meal: return "meal"
        case .activity: return "activity"
        }
    }
    
    private func mapMealTimeToString(_ mealTime: MealTime) -> String {
        switch mealTime {
        case .breakfast: return "breakfast"
        case .lunch: return "lunch"
        case .dinner: return "dinner"
        case .notSure: return "not_sure"
        }
    }
    
    private func mapPriceRangeToString(_ priceRange: PriceRange) -> String {
        switch priceRange {
        case .free: return "free"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .luxury: return "luxury"
        case .notSure: return "not_sure"
        }
    }
    
    private func mapCuisineToString(_ cuisine: Cuisine) -> String {
        switch cuisine {
        case .italian: return "italian"
        case .mexican: return "mexican"
        case .american: return "american"
        case .japanese: return "japanese"
        case .chinese: return "chinese"
        case .indian: return "indian"
        case .thai: return "thai"
        case .french: return "french"
        case .mediterranean: return "mediterranean"
        case .notSure: return "not_sure"
        }
    }
    
    private func mapActivityTypeToString(_ activityType: ActivityType) -> String {
        switch activityType {
        case .sports: return "sports"
        case .outdoor: return "outdoor"
        case .indoor: return "indoor"
        case .entertainment: return "entertainment"
        case .fitness: return "fitness"
        case .notSure: return "not_sure"
        }
    }
    
    private func mapActivityIntensityToString(_ intensity: ActivityIntensity) -> String {
        switch intensity {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .notSure: return "not_sure"
        }
    }
    
    private func formatDateForBackend(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func generateImageURL(for cuisineType: String, name: String) -> String {
        // Use a more relevant image service based on activity type
        let activityType = cuisineType.lowercased()
        
        // Create a consistent seed based on name and type
        let seed = "\(name)-\(cuisineType)".hash
        let seedId = abs(seed) % 1000
        
        // Use different image sources based on activity type
        switch activityType {
        case "sports", "fitness":
            return "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop&crop=center&auto=format&q=80"
        case "outdoor":
            return "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop&crop=center&auto=format&q=80"
        case "entertainment":
            return "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&h=300&fit=crop&crop=center&auto=format&q=80"
        case "indoor":
            return "https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=400&h=300&fit=crop&crop=center&auto=format&q=80"
        default:
            // For restaurants, use Lorem Picsum with consistent seed
            return "https://picsum.photos/400/300?random=\(seedId)&blur=1"
        }
    }
}

// MARK: - Error Response
struct ErrorResponse: Codable {
    let detail: String
}

// MARK: - Restaurant Errors
enum RestaurantError: Error, LocalizedError {
    case invalidURL
    case noData
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
