//
//  BackendService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

// MARK: - Backend Data Models
struct BackendDateRequest: Codable {
    let query: String
    let location: String
    let dateType: String
    let mealTimes: [String]?
    let priceRange: String?
    let cuisines: [String]?
    let activityTypes: [String]?
    let activityIntensity: String?
    let date: String
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
        case query
        case location
        case dateType = "date_type"
        case mealTimes = "meal_times"
        case priceRange = "price_range"
        case cuisines
        case activityTypes = "activity_types"
        case activityIntensity = "activity_intensity"
        case date
        case latitude
        case longitude
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

struct BackendPlaceRecommendation: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let location: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: String
    let estimatedCost: String
    let bestTime: String
    let whyRecommended: String
    let aiConfidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, description, location, address, latitude, longitude, category
        case estimatedCost = "estimated_cost"
        case bestTime = "best_time"
        case whyRecommended = "why_recommended"
        case aiConfidence = "ai_confidence"
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var cuisine: String {
        category
    }
    
    var priceLevel: String {
        estimatedCost
    }
    
    var matchScore: Double {
        aiConfidence ?? 0.0
    }
}

struct BackendLocation: Codable {
    let name: String
    let displayName: String
    let lat: Double
    let lon: Double
    let placeId: Int
    let type: String
    let importance: Double
    
    enum CodingKeys: String, CodingKey {
        case name, lat, lon, type, importance
        case displayName = "display_name"
        case placeId = "place_id"
    }
}

struct BackendDateResponse: Codable {
    let recommendations: [BackendPlaceRecommendation]
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

// MARK: - Backend Service
class BackendService: ObservableObject {
    static let shared = BackendService()
    
    // Railway production backend URL
    private let baseURL = "https://dbbackend-production-2721.up.railway.app"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if the backend is healthy and accessible
    func checkHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(.failure(BackendError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("D8-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
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
                    completion(.failure(BackendError.serverError("Invalid response")))
                }
            }
        }.resume()
    }
    
    /// Get AI-powered date recommendations
    func getDateRecommendations(
        location: String,
        dateType: DateType,
        mealTimes: Set<MealTime>?,
        priceRange: PriceRange?,
        cuisines: Set<Cuisine>?,
        activityTypes: Set<ActivityType>?,
        activityIntensity: ActivityIntensity?,
        date: Date,
        coordinate: CLLocationCoordinate2D?,
        completion: @escaping (Result<[BackendPlaceRecommendation], Error>) -> Void
    ) {
        // Create a query string from the preferences
        let query = createQueryString(
            location: location,
            dateType: dateType,
            mealTimes: mealTimes,
            priceRange: priceRange,
            cuisines: cuisines,
            activityTypes: activityTypes,
            activityIntensity: activityIntensity
        )
        
        // Get user profile data for personalization
        let userProfile = UserProfileService.shared.userProfile
        
        let request = BackendDateRequest(
            query: query,
            location: location,
            dateType: mapDateTypeToString(dateType),
            mealTimes: mealTimes?.map { mapMealTimeToString($0) },
            priceRange: priceRange.map { mapPriceRangeToString($0) },
            cuisines: cuisines?.map { mapCuisineToString($0) },
            activityTypes: activityTypes?.map { mapActivityTypeToString($0) },
            activityIntensity: activityIntensity.map { mapActivityIntensityToString($0) },
            date: formatDateForBackend(date),
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            // User profile data
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
    
    /// Search locations without AI (basic search)
    func searchLocations(
        query: String,
        completion: @escaping (Result<[BackendPlaceRecommendation], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/search/locations?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            completion(.failure(BackendError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("D8-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(BackendError.noData))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(BackendDateResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response.recommendations))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Search by category
    func searchByCategory(
        category: String,
        completion: @escaping (Result<[BackendPlaceRecommendation], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/search/category/\(category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")") else {
            completion(.failure(BackendError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("D8-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(BackendError.noData))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(BackendDateResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response.recommendations))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Enhance specific place recommendations
    func enhancePlace(
        placeId: String,
        completion: @escaping (Result<BackendPlaceRecommendation, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/enhance/\(placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")") else {
            completion(.failure(BackendError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("D8-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(BackendError.noData))
                }
                return
            }
            
            do {
                let recommendation = try JSONDecoder().decode(BackendPlaceRecommendation.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(recommendation))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Private Methods
    private func makeRequest(
        endpoint: String,
        request: BackendDateRequest,
        completion: @escaping (Result<[BackendPlaceRecommendation], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(BackendError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("D8-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
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
                    completion(.failure(BackendError.noData))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(BackendDateResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response.recommendations))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Mapping Functions
    private func createQueryString(
        location: String,
        dateType: DateType,
        mealTimes: Set<MealTime>?,
        priceRange: PriceRange?,
        cuisines: Set<Cuisine>?,
        activityTypes: Set<ActivityType>?,
        activityIntensity: ActivityIntensity?
    ) -> String {
        var queryParts: [String] = []
        
        // Add location
        queryParts.append(location)
        
        // Add cuisine preferences (for meal dates)
        if let cuisines = cuisines, !cuisines.isEmpty {
            let cuisineNames = cuisines.map { mapCuisineToString($0) }.joined(separator: " ")
            queryParts.append(cuisineNames)
        }
        
        // Add meal times (for meal dates)
        if let mealTimes = mealTimes, !mealTimes.isEmpty {
            let mealTimeNames = mealTimes.map { mapMealTimeToString($0) }.joined(separator: " ")
            queryParts.append(mealTimeNames)
        }
        
        // Add activity types (for activity dates)
        if let activityTypes = activityTypes, !activityTypes.isEmpty {
            let activityTypeNames = activityTypes.map { mapActivityTypeToString($0) }.joined(separator: " ")
            queryParts.append(activityTypeNames)
        }
        
        // Add activity intensity (for activity dates) - EXTREME CASES
        if let activityIntensity = activityIntensity {
            let intensityString = mapActivityIntensityToString(activityIntensity)
            queryParts.append(intensityString)
            
            // Add specific keywords for extreme cases
            if activityIntensity == .high {
                queryParts.append("high intensity physical activity sports fitness")
            } else if activityIntensity == .low {
                queryParts.append("low intensity indoor sedentary")
            }
        }
        
        // Add price range - EXTREME CASES
        if let priceRange = priceRange {
            let priceString = mapPriceRangeToString(priceRange)
            queryParts.append(priceString)
            
            // Add specific keywords for extreme cases
            if priceRange == .free {
                queryParts.append("free no cost zero cost")
            } else if priceRange == .luxury {
                queryParts.append("expensive premium luxury high-end")
            }
        }
        
        // Add date type
        queryParts.append(mapDateTypeToString(dateType))
        
        return queryParts.joined(separator: " ")
    }
    
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
}

// MARK: - Backend Errors
enum BackendError: Error, LocalizedError {
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

// MARK: - Backend to OSM Place Conversion
extension BackendPlaceRecommendation {
    func toOSMPlace() -> OSMPlace {
        return OSMPlace(
            id: Int.random(in: 1...10000), // Generate random ID since we don't have placeId anymore
            name: name,
            latitude: latitude,
            longitude: longitude,
            amenity: mapCategoryToAmenity(category),
            cuisine: cuisine,
            website: nil, // Not available in current backend response
            phone: nil, // Not available in current backend response
            address: address,
            openingHours: nil, // Not available in current backend response
            rating: nil, // Not available in current backend response
            priceLevel: mapEstimatedCostToPriceLevel(estimatedCost),
            description: description,
            capacity: nil,
            outdoorSeating: nil,
            takeaway: nil,
            delivery: nil,
            wheelchair: nil,
            smoking: nil,
            wifi: nil,
            parking: nil,
            paymentMethods: nil,
            lastUpdated: nil
        )
    }
    
    private func mapCategoryToAmenity(_ category: String) -> String {
        switch category.lowercased() {
        case "restaurant", "cafe", "bar": return "restaurant"
        case "park": return "park"
        case "museum": return "museum"
        case "theater": return "theatre"
        case "cinema": return "cinema"
        default: return "restaurant"
        }
    }
    
    private func mapEstimatedCostToPriceLevel(_ estimatedCost: String) -> String? {
        switch estimatedCost.lowercased() {
        case "free": return "0"
        case "low": return "1"
        case "medium", "moderate": return "2"
        case "high", "expensive": return "3"
        case "luxury", "very expensive": return "4"
        default: return "2" // Default to medium
        }
    }
}
