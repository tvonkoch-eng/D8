//
//  ExploreService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

class ExploreService: ObservableObject {
    static let shared = ExploreService()
    
    private let backendService = RestaurantService.shared
    private let firebaseService = FirebaseService.shared
    private let locationManager = LocationManager()
    private let imageService = ImageService.shared
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var ideas: [ExploreIdea] = []
    @Published var locationName = "Loading location..."
    @Published var showLocationPermissionDenied = false
    
    // Cache the last known location to avoid repeated GPS calls
    private var lastKnownLocation: String?
    private var lastKnownDate: String?
    
    // Add location name cache to avoid repeated geocoding
    private var locationNameCache: [String: String] = [:]
    private let locationCacheKey = "location_name_cache"
    
    private init() {}
    
    // MARK: - Public Methods
    
    func getExploreIdeas(completion: @escaping (Result<[ExploreIdea], Error>) -> Void) {
        // If we already have ideas loaded, return them immediately
        if !ideas.isEmpty {
            completion(.success(ideas))
            return
        }
        
        // Only set loading state if we need to fetch data
        isLoading = true
        errorMessage = nil
        showLocationPermissionDenied = false
        
        // First, try to get ideas from Firebase using last known location
        if let lastLocation = lastKnownLocation, let lastDate = lastKnownDate {
            checkFirebaseForIdeas(location: lastLocation, date: lastDate, completion: completion)
            return
        }
        
        // If no cached location, start both location fetch and Firebase check in parallel
        startParallelLocationAndFirebaseCheck(completion: completion)
    }
    
    func refreshExploreIdeas(completion: @escaping (Result<[ExploreIdea], Error>) -> Void) {
        // Clear existing data and reload
        ideas = []
        locationName = "Loading location..."
        errorMessage = nil
        showLocationPermissionDenied = false
        
        getExploreIdeas(completion: completion)
    }
    
    func clearCache() {
        ideas = []
        locationName = "Loading location..."
        errorMessage = nil
        showLocationPermissionDenied = false
        isLoading = false
        lastKnownLocation = nil
        lastKnownDate = nil
    }
    
    func shouldRefreshForNewDay() -> Bool {
        // For now, always return false to avoid unnecessary refreshes
        // In the future, this could check if the cached data is from a different day
        return false
    }
    
    // MARK: - Private Methods
    
    private func startParallelLocationAndFirebaseCheck(completion: @escaping (Result<[ExploreIdea], Error>) -> Void) {
        // Check location permission first
        guard locationManager.checkCurrentPermissionStatus() else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.showLocationPermissionDenied = true
                completion(.failure(ExploreError.locationPermissionDenied))
            }
            return
        }
        
        // Start location fetch with fallback
        locationManager.getCurrentLocation { [weak self] coordinate in
            guard let self = self else { return }
            
            // If location fails, use a default location for testing
            let finalCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            
            // Get location name from coordinates
            self.getLocationName(from: finalCoordinate) { locationName in
                // Use fallback location name if needed
                let finalLocationName = locationName == "Unknown Location" ? "San Francisco, CA" : locationName
                
                let today = self.formatDateForBackend(Date())
                
                // Check if ideas already exist for today
                Task {
                    do {
                        if let existingIdeas = try await self.firebaseService.getExploreIdeas(for: locationName, date: today) {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.ideas = existingIdeas.ideas
                                self.locationName = locationName
                                // Cache the location for future use
                                self.lastKnownLocation = locationName
                                self.lastKnownDate = today
                                completion(.success(existingIdeas.ideas))
                            }
                            return
                        }
                        
                        // Generate new ideas
                        try await self.generateAndSaveExploreIdeas(for: locationName, date: today, coordinate: finalCoordinate) { result in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch result {
                                case .success(let newIdeas):
                                    self.ideas = newIdeas
                                    self.locationName = locationName
                                    // Cache the location for future use
                                    self.lastKnownLocation = locationName
                                    self.lastKnownDate = today
                                case .failure:
                                    break
                                }
                                completion(result)
                            }
                        }
                    } catch {
                        // If Firebase fails (e.g., offline error), generate new ideas anyway
                        print("Firebase error, generating new ideas: \(error.localizedDescription)")
                        try await self.generateAndSaveExploreIdeas(for: locationName, date: today, coordinate: finalCoordinate) { result in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch result {
                                case .success(let newIdeas):
                                    self.ideas = newIdeas
                                    self.locationName = locationName
                                    // Cache the location for future use
                                    self.lastKnownLocation = locationName
                                    self.lastKnownDate = today
                                case .failure:
                                    break
                                }
                                completion(result)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func checkFirebaseForIdeas(location: String, date: String, completion: @escaping (Result<[ExploreIdea], Error>) -> Void) {
        Task {
            do {
                if let existingIdeas = try await self.firebaseService.getExploreIdeas(for: location, date: date) {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.ideas = existingIdeas.ideas
                        self.locationName = location
                        completion(.success(existingIdeas.ideas))
                    }
                    return
                }
                
                // If no Firebase data found, fall back to GPS location
                self.fallbackToGPSLocation(completion: completion)
            } catch {
                // If Firebase fails (e.g., offline error), fall back to generating new ideas
                print("Firebase error, falling back to backend generation: \(error.localizedDescription)")
                self.fallbackToGPSLocation(completion: completion)
            }
        }
    }
    
    private func fallbackToGPSLocation(completion: @escaping (Result<[ExploreIdea], Error>) -> Void) {
        // Check location permission first
        guard locationManager.checkCurrentPermissionStatus() else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.showLocationPermissionDenied = true
                completion(.failure(ExploreError.locationPermissionDenied))
            }
            return
        }
        
        // Get current location first
        locationManager.getCurrentLocation { [weak self] coordinate in
            guard let self = self else { return }
            
            // Use fallback location if coordinate is nil
            let finalCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            
            // Get location name from coordinates
            self.getLocationName(from: finalCoordinate) { locationName in
                // Use fallback location name if needed
                let finalLocationName = locationName == "Unknown Location" ? "San Francisco, CA" : locationName
                
                let today = self.formatDateForBackend(Date())
                
                // Check if ideas already exist for today
                Task {
                    do {
                        if let existingIdeas = try await self.firebaseService.getExploreIdeas(for: finalLocationName, date: today) {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.ideas = existingIdeas.ideas
                                self.locationName = finalLocationName
                                // Cache the location for future use
                                self.lastKnownLocation = finalLocationName
                                self.lastKnownDate = today
                                completion(.success(existingIdeas.ideas))
                            }
                            return
                        }
                        
                        // Generate new ideas
                        try await self.generateAndSaveExploreIdeas(for: finalLocationName, date: today, coordinate: finalCoordinate) { result in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch result {
                                case .success(let newIdeas):
                                    self.ideas = newIdeas
                                    self.locationName = locationName
                                    // Cache the location for future use
                                    self.lastKnownLocation = locationName
                                    self.lastKnownDate = today
                                case .failure:
                                    break
                                }
                                completion(result)
                            }
                        }
                    } catch {
                        // If Firebase fails (e.g., offline error), generate new ideas anyway
                        print("Firebase error in fallback, generating new ideas: \(error.localizedDescription)")
                        try await self.generateAndSaveExploreIdeas(for: finalLocationName, date: today, coordinate: finalCoordinate) { result in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch result {
                                case .success(let newIdeas):
                                    self.ideas = newIdeas
                                    self.locationName = locationName
                                    // Cache the location for future use
                                    self.lastKnownLocation = locationName
                                    self.lastKnownDate = today
                                case .failure:
                                    break
                                }
                                completion(result)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getLocationName(from coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        // Check cache first to avoid repeated geocoding
        let coordinateKey = "\(coordinate.latitude),\(coordinate.longitude)"
        if let cachedLocation = locationNameCache[coordinateKey] {
            print("Using cached location name: \(cachedLocation)")
            completion(cachedLocation)
            return
        }
        
        // Use lower zoom level for faster response (city-level instead of street-level)
        let url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&zoom=10&addressdetails=1"
        
        guard let requestURL = URL(string: url) else {
            completion("Unknown Location")
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5.0 // Add 5-second timeout
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Geocoding error: \(error)")
                completion("Unknown Location")
                return
            }
            
            guard let data = data else {
                completion("Unknown Location")
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion("Unknown Location")
                return
            }
            
            guard let address = json["address"] as? [String: Any] else {
                completion("Unknown Location")
                return
            }
            
            // Extract city and state
            let city = address["city"] as? String ?? 
                     address["town"] as? String ?? 
                     address["village"] as? String ?? 
                     address["hamlet"] as? String
            let state = address["state"] as? String
            let county = address["county"] as? String
            let country = address["country"] as? String
            
            let locationName: String
            if let city = city, let state = state {
                locationName = "\(city), \(state)"
            } else if let city = city, let country = country {
                locationName = "\(city), \(country)"
            } else if let city = city {
                locationName = city
            } else if let county = county, let state = state {
                // Use county if no city is available
                locationName = "\(county), \(state)"
            } else if let county = county, let country = country {
                locationName = "\(county), \(country)"
            } else if let county = county {
                locationName = county
            } else if let state = state, let country = country {
                locationName = "\(state), \(country)"
            } else {
                locationName = "Unknown Location"
            }
            
            DispatchQueue.main.async {
                // Cache the location name for future use
                self.locationNameCache[coordinateKey] = locationName
                completion(locationName)
            }
        }.resume()
    }
    
    private func generateAndSaveExploreIdeas(for location: String, date: String, coordinate: CLLocationCoordinate2D, completion: @escaping (Result<[ExploreIdea], Error>) -> Void) async throws {
        // Clean up expired ideas first
        try await firebaseService.cleanupExpiredIdeas()
        
        // Generate ideas using the existing backend
        let ideas = try await generateIdeasFromBackend(location: location, date: date, coordinate: coordinate)
        
        // Save to Firebase
        let exploreIdeas = ExploreIdeas(location: location, date: date, ideas: ideas)
        try await firebaseService.saveExploreIdeas(exploreIdeas)
        
        completion(.success(ideas))
    }
    
    private func generateIdeasFromBackend(location: String, date: String, coordinate: CLLocationCoordinate2D) async throws -> [ExploreIdea] {
        return try await withCheckedThrowingContinuation { continuation in
            // Get user profile data for personalization
            let userProfile = UserProfileService.shared.userProfile
            
            // Use the new explore endpoint
            let request = RestaurantRequest(
                dateType: "explore", // Special type for explore
                mealTimes: [],
                priceRange: "not_sure",
                cuisines: [],
                activityTypes: [],
                activityIntensity: nil,
                date: date,
                location: location,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                page: 1,
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
            
            makeExploreRequest(request: request) { result in
                switch result {
                case .success(let recommendations):
                    Task {
                        let exploreIdeas = await self.convertToExploreIdeasAsync(restaurants: recommendations, activities: [])
                        continuation.resume(returning: exploreIdeas)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func makeExploreRequest(request: RestaurantRequest, completion: @escaping (Result<[RestaurantRecommendation], Error>) -> Void) {
        // Use Railway production backend
        guard let url = URL(string: "https://dbbackend-production-2721.up.railway.app/explore") else {
            completion(.failure(ExploreError.networkError))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        urlRequest.timeoutInterval = 15.0 // Add 15-second timeout for backend API
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Backend API error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(ExploreError.networkError))
                }
                return
            }
            
            // Check for HTTP error status
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Backend API HTTP error: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(ExploreError.networkError))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(RestaurantResponse.self, from: data)
                print("Backend API success: \(response.recommendations.count) recommendations")
                DispatchQueue.main.async {
                    completion(.success(response.recommendations))
                }
            } catch {
                print("Backend API decode error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    private func convertToExploreIdeas(restaurants: [RestaurantRecommendation], activities: [RestaurantRecommendation]) -> [ExploreIdea] {
        var ideas: [ExploreIdea] = []
        
        // Convert all recommendations (now mixed from explore endpoint)
        for recommendation in restaurants {
            // Determine if it's a restaurant or activity based on cuisine_type
            let isRestaurant = recommendation.cuisineType.lowercased() != "activity" && 
                              recommendation.cuisineType.lowercased() != "sports" &&
                              recommendation.cuisineType.lowercased() != "outdoor" &&
                              recommendation.cuisineType.lowercased() != "indoor" &&
                              recommendation.cuisineType.lowercased() != "entertainment" &&
                              recommendation.cuisineType.lowercased() != "fitness"
            
            // No image handling - removed for simplicity
            
            let idea = ExploreIdea(
                name: recommendation.name,
                description: recommendation.description,
                location: recommendation.location,
                address: recommendation.address,
                latitude: recommendation.latitude,
                longitude: recommendation.longitude,
                category: isRestaurant ? "restaurant" : "activity",
                cuisineType: isRestaurant ? recommendation.cuisineType : nil,
                activityType: isRestaurant ? nil : recommendation.cuisineType,
                priceLevel: recommendation.priceLevel,
                rating: recommendation.rating,
                whyRecommended: recommendation.whyRecommended,
                estimatedCost: recommendation.estimatedCost,
                bestTime: recommendation.bestTime,
                duration: recommendation.duration,
                isOpen: recommendation.isOpen,
                openHours: recommendation.openHours,
                imageURL: ""
            )
            ideas.append(idea)
        }
        
        // Shuffle the ideas to mix restaurants and activities
        return ideas.shuffled()
    }
    
    private func convertToExploreIdeasAsync(restaurants: [RestaurantRecommendation], activities: [RestaurantRecommendation]) async -> [ExploreIdea] {
        var ideas: [ExploreIdea] = []
        
        // Convert all recommendations (now mixed from explore endpoint)
        for recommendation in restaurants {
            // Determine if it's a restaurant or activity based on cuisine_type
            let isRestaurant = recommendation.cuisineType.lowercased() != "activity" && 
                              recommendation.cuisineType.lowercased() != "sports" &&
                              recommendation.cuisineType.lowercased() != "outdoor" &&
                              recommendation.cuisineType.lowercased() != "indoor" &&
                              recommendation.cuisineType.lowercased() != "entertainment" &&
                              recommendation.cuisineType.lowercased() != "fitness"
            
            // No image handling - removed for simplicity
            
            let idea = ExploreIdea(
                name: recommendation.name,
                description: recommendation.description,
                location: recommendation.location,
                address: recommendation.address,
                latitude: recommendation.latitude,
                longitude: recommendation.longitude,
                category: isRestaurant ? "restaurant" : "activity",
                cuisineType: isRestaurant ? recommendation.cuisineType : nil,
                activityType: isRestaurant ? nil : recommendation.cuisineType,
                priceLevel: recommendation.priceLevel,
                rating: recommendation.rating,
                whyRecommended: recommendation.whyRecommended,
                estimatedCost: recommendation.estimatedCost,
                bestTime: recommendation.bestTime,
                duration: recommendation.duration,
                isOpen: recommendation.isOpen,
                openHours: recommendation.openHours,
                imageURL: ""
            )
            ideas.append(idea)
        }
        
        // Shuffle the ideas to mix restaurants and activities
        return ideas.shuffled()
    }
    
    
    
    
    
    private func formatDateForBackend(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Explore Errors
enum ExploreError: Error, LocalizedError {
    case locationUnavailable
    case locationPermissionDenied
    case noIdeasGenerated
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Unable to determine your location. Please check your location settings and try again."
        case .locationPermissionDenied:
            return "Location permission is required to get personalized recommendations. Please enable location access in Settings."
        case .noIdeasGenerated:
            return "Unable to generate ideas for your location. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        }
    }
}
