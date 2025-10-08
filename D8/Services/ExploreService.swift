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
    private let restaurantDatabaseService = RestaurantDatabaseService.shared
    
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
        // Check if we have cached data for today's date
        let today = formatDateForBackend(Date())
        
        // If we already have ideas loaded for today, return them immediately
        if !ideas.isEmpty && lastKnownDate == today {
            completion(.success(ideas))
            return
        }
        
        // Only set loading state if we need to fetch data
        isLoading = true
        errorMessage = nil
        showLocationPermissionDenied = false
        
        // Get current location and check Firebase cache
        locationManager.getCurrentLocation { [weak self] coordinate in
            guard let self = self else { return }
            
            // Use fallback location if coordinate is nil
            let finalCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            
            // Get location name from coordinates
            self.getLocationNameWithRetry(from: finalCoordinate, retryCount: 0) { locationName in
                // Check if location is unknown - this is an error condition
                if locationName == "Unknown Location" {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Unable to determine your location. Please check your location settings and try again."
                        completion(.failure(ExploreError.locationUnavailable))
                    }
                    return
                }
                
                // Check Firebase cache first for today's data
                Task {
                    do {
                        if let existingIdeas = try await self.firebaseService.getExploreIdeas(for: locationName, date: today) {
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.ideas = existingIdeas.ideas
                                self.locationName = locationName
                                // Cache the location and date for future use
                                self.lastKnownLocation = locationName
                                self.lastKnownDate = today
                                completion(.success(existingIdeas.ideas))
                            }
                            return
                        }
                        
                        // If no Firebase data found for today, generate new ideas
                        try await self.generateAndSaveExploreIdeas(for: locationName, date: today, coordinate: finalCoordinate) { result in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch result {
                                case .success(let newIdeas):
                                    self.ideas = newIdeas
                                    self.locationName = locationName
                                    // Cache the location and date for future use
                                    self.lastKnownLocation = locationName
                                    self.lastKnownDate = today
                                case .failure(let error):
                                    self.errorMessage = error.localizedDescription
                                }
                                completion(result)
                            }
                        }
                    } catch {
                        // If Firebase fails (e.g., offline error), generate new ideas anyway
                        try await self.generateAndSaveExploreIdeas(for: locationName, date: today, coordinate: finalCoordinate) { result in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                switch result {
                                case .success(let newIdeas):
                                    self.ideas = newIdeas
                                    self.locationName = locationName
                                    // Cache the location and date for future use
                                    self.lastKnownLocation = locationName
                                    self.lastKnownDate = today
                                case .failure(let error):
                                    self.errorMessage = error.localizedDescription
                                }
                                completion(result)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func refreshExploreIdeas(completion: @escaping (Result<[ExploreIdea], Error>) -> Void) {
        let today = formatDateForBackend(Date())
        
        // Only clear cache if we're refreshing for a new day
        if lastKnownDate != today {
            // Clear existing data for new day
            ideas = []
            locationName = "Loading location..."
            errorMessage = nil
            showLocationPermissionDenied = false
        }
        
        // Force fresh data by skipping Firebase cache
        startParallelLocationAndFirebaseCheck(completion: completion)
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
    
    func clearFirebaseCache(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // Clear Firebase cache for current location and date
                if let location = lastKnownLocation, let date = lastKnownDate {
                    try await firebaseService.deleteExploreIdeas(for: location, date: date)
                }
                
                // Clear local cache
                clearCache()
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func shouldRefreshForNewDay() -> Bool {
        let today = formatDateForBackend(Date())
        return lastKnownDate != today
    }
    
    func hasCachedDataForToday() -> Bool {
        let today = formatDateForBackend(Date())
        return !ideas.isEmpty && lastKnownDate == today
    }
    
    func getCachedLocationAndDate() -> (location: String?, date: String?) {
        return (lastKnownLocation, lastKnownDate)
    }
    
    // MARK: - Debug Methods
    
    func testImageService() async {
        print("🧪 [ExploreService] Testing ImageService...")
        await imageService.testGooglePlacesAPI()
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
                // Check if location is unknown - this is an error condition
                if locationName == "Unknown Location" {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Unable to determine your location. Please check your location settings and try again."
                        completion(.failure(ExploreError.locationUnavailable))
                    }
                    return
                }
                
                let finalLocationName = locationName
                
                let today = self.formatDateForBackend(Date())
                
                // Always generate fresh ideas (skip Firebase cache for refresh)
                Task {
                    do {
                        // Generate new ideas using real restaurant data
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
                                case .failure(let error):
                                    self.errorMessage = error.localizedDescription
                                }
                                completion(result)
                            }
                        }
                    } catch {
                        // If Firebase fails (e.g., offline error), generate new ideas anyway
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
                                case .failure(let error):
                                    self.errorMessage = error.localizedDescription
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
                // Check if location is unknown - this is an error condition
                if locationName == "Unknown Location" {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Unable to determine your location. Please check your location settings and try again."
                        completion(.failure(ExploreError.locationUnavailable))
                    }
                    return
                }
                
                let finalLocationName = locationName
                
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
                                case .failure(let error):
                                    self.errorMessage = error.localizedDescription
                                }
                                completion(result)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getLocationNameWithRetry(from coordinate: CLLocationCoordinate2D, retryCount: Int, completion: @escaping (String) -> Void) {
        getLocationName(from: coordinate) { locationName in
            if locationName == "Unknown Location" && retryCount < 2 {
                // Retry with a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.getLocationNameWithRetry(from: coordinate, retryCount: retryCount + 1, completion: completion)
                }
            } else {
                completion(locationName)
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
                // Try a different geocoding service as fallback
                self.tryAlternativeGeocoding(coordinate: coordinate, completion: completion)
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
    
    private func tryAlternativeGeocoding(coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        // Try using Apple's reverse geocoding as fallback
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Apple geocoding error: \(error)")
                completion("Unknown Location")
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion("Unknown Location")
                return
            }
            
            let city = placemark.locality ?? placemark.administrativeArea
            let state = placemark.administrativeArea
            let country = placemark.country
            
            let locationName: String
            if let city = city, let state = state {
                locationName = "\(city), \(state)"
            } else if let city = city, let country = country {
                locationName = "\(city), \(country)"
            } else if let city = city {
                locationName = city
            } else if let state = state, let country = country {
                locationName = "\(state), \(country)"
            } else {
                locationName = "Unknown Location"
            }
            
            DispatchQueue.main.async {
                completion(locationName)
            }
        }
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
            // Use RestaurantService to get real restaurant data instead of fake AI data
            backendService.getRestaurantRecommendations(
                dateType: .meal, // Use meal type to get restaurants
                mealTimes: Set([.dinner]), // Get dinner recommendations
                priceRange: .medium, // Use medium price range for variety
                cuisines: Set<Cuisine>(), // No specific cuisine filter for variety
                date: Date(), // Use current date
                location: location,
                coordinate: coordinate
            ) { result in
                switch result {
                case .success(let recommendations):
                    Task {
                        // Convert real restaurant recommendations to explore ideas
                        let exploreIdeas = await self.convertRealRestaurantsToExploreIdeas(recommendations: recommendations)
                        continuation.resume(returning: exploreIdeas)
                    }
                case .failure(let error):
                    // Check if it's a location unavailable error
                    if case ExploreError.locationUnavailable = error {
                        continuation.resume(throwing: error)
                    } else {
                        // Use fallback ideas when backend is unavailable for other reasons
                        Task {
                            let fallbackIdeas = await self.generateFallbackIdeas(for: location, userCoordinate: coordinate)
                            continuation.resume(returning: fallbackIdeas)
                        }
                    }
                }
            }
        }
    }
    
    private func makeExploreRequest(request: RestaurantRequest, completion: @escaping (Result<[RestaurantRecommendation], Error>) -> Void) {
        // Try local development server first, then fall back to production
        let localURL = "http://localhost:8000/explore"
        let productionURL = "https://dbbackend-production-2721.up.railway.app/explore"
        
        // For now, use production URL (can be configured for development)
        let backendURL = productionURL
        
        guard let url = URL(string: backendURL) else {
            completion(.failure(ExploreError.networkError))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        urlRequest.timeoutInterval = 10.0 // Reduced to 10-second timeout for faster fallback
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
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
                DispatchQueue.main.async {
                    completion(.failure(ExploreError.networkError))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(RestaurantResponse.self, from: data)
                
                // Check if backend rejected the request due to unknown location
                if response.totalFound == 0 && response.queryUsed.contains("Location unavailable") {
                    DispatchQueue.main.async {
                        completion(.failure(ExploreError.locationUnavailable))
                    }
                    return
                }
                
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
                imageURL: "",
                websiteURL: recommendation.websiteURL,
                menuURL: recommendation.menuURL
            )
            ideas.append(idea)
        }
        
        // Shuffle the ideas to mix restaurants and activities
        return ideas.shuffled()
    }
    
    private func convertRealRestaurantsToExploreIdeas(recommendations: [RestaurantRecommendation]) async -> [ExploreIdea] {
        var ideas: [ExploreIdea] = []
        
        // Save all restaurants to database first
        do {
            try await restaurantDatabaseService.saveRestaurants(recommendations)
            print("✅ [ExploreService] Saved \(recommendations.count) restaurants to database")
        } catch {
            print("❌ [ExploreService] Failed to save restaurants to database: \(error.localizedDescription)")
        }
        
        // Convert backend recommendations to explore ideas
        for recommendation in recommendations {
            print("🔄 [ExploreService] Processing recommendation: \(recommendation.name)")
            print("📸 [ExploreService] Original imageURL: \(recommendation.imageURL ?? "nil")")
            
            // Try to get Google Places image first, then fallback to existing image
            var imageURL = recommendation.imageURL ?? ""
            
            if imageURL.isEmpty {
                print("🔍 [ExploreService] No image URL, trying Google Places API...")
                // Try Google Places API for restaurant images
                if let placesImageURL = await imageService.getImageURL(for: recommendation) {
                    imageURL = placesImageURL
                    print("✅ [ExploreService] Got Google Places image: \(placesImageURL)")
                } else {
                    print("❌ [ExploreService] Failed to get Google Places image")
                }
            } else {
                print("✅ [ExploreService] Using existing image URL: \(imageURL)")
            }
            
            let idea = ExploreIdea(
                name: recommendation.name,
                description: recommendation.description,
                location: recommendation.location,
                address: recommendation.address,
                latitude: recommendation.latitude,
                longitude: recommendation.longitude,
                category: "restaurant",
                cuisineType: recommendation.cuisineType,
                activityType: nil,
                priceLevel: recommendation.priceLevel,
                rating: recommendation.rating,
                whyRecommended: recommendation.whyRecommended,
                estimatedCost: recommendation.estimatedCost,
                bestTime: recommendation.bestTime,
                duration: recommendation.duration ?? "1-2 hours",
                isOpen: recommendation.isOpen,
                openHours: recommendation.openHours,
                imageURL: imageURL,
                websiteURL: recommendation.websiteURL,
                menuURL: recommendation.menuURL
            )
            ideas.append(idea)
        }
        
        // If we don't have enough ideas, get some activity recommendations too
        if ideas.count < 6 {
            await getActivityRecommendations(location: recommendations.first?.location ?? "Current Location", coordinate: CLLocationCoordinate2D(latitude: recommendations.first?.latitude ?? 0, longitude: recommendations.first?.longitude ?? 0)) { activityIdeas in
                ideas.append(contentsOf: activityIdeas)
            }
        }
        
        return ideas.shuffled()
    }
    
    private func getActivityRecommendations(location: String, coordinate: CLLocationCoordinate2D, completion: @escaping ([ExploreIdea]) -> Void) {
        backendService.getRestaurantRecommendations(
            dateType: .activity,
            mealTimes: Set<MealTime>(),
            priceRange: .medium,
            cuisines: Set<Cuisine>(),
            date: Date(),
            location: location,
            coordinate: coordinate
        ) { result in
            switch result {
            case .success(let recommendations):
                Task {
                    var activityIdeas: [ExploreIdea] = []
                    for recommendation in recommendations {
                        print("🔄 [ExploreService] Processing activity recommendation: \(recommendation.name)")
                        print("📸 [ExploreService] Original activity imageURL: \(recommendation.imageURL ?? "nil")")
                        
                        // Try to get Google Places image first, then fallback to existing image
                        var imageURL = recommendation.imageURL ?? ""
                        
                        if imageURL.isEmpty {
                            print("🔍 [ExploreService] No activity image URL, trying Google Places API...")
                            // Try Google Places API for activity images
                            if let placesImageURL = await self.imageService.getImageURL(for: recommendation) {
                                imageURL = placesImageURL
                                print("✅ [ExploreService] Got Google Places activity image: \(placesImageURL)")
                            } else {
                                print("❌ [ExploreService] Failed to get Google Places activity image")
                            }
                        } else {
                            print("✅ [ExploreService] Using existing activity image URL: \(imageURL)")
                        }
                        
                        let idea = ExploreIdea(
                            name: recommendation.name,
                            description: recommendation.description,
                            location: recommendation.location,
                            address: recommendation.address,
                            latitude: recommendation.latitude,
                            longitude: recommendation.longitude,
                            category: "activity",
                            cuisineType: nil,
                            activityType: recommendation.cuisineType, // Use cuisineType as activity type for activities
                            priceLevel: recommendation.priceLevel,
                            rating: recommendation.rating,
                            whyRecommended: recommendation.whyRecommended,
                            estimatedCost: recommendation.estimatedCost,
                            bestTime: recommendation.bestTime,
                            duration: recommendation.duration ?? "2-3 hours",
                            isOpen: recommendation.isOpen,
                            openHours: recommendation.openHours,
                            imageURL: imageURL,
                            websiteURL: recommendation.websiteURL,
                            menuURL: recommendation.menuURL
                        )
                        activityIdeas.append(idea)
                    }
                    completion(activityIdeas)
                }
            case .failure(_):
                completion([])
            }
        }
    }

    private func convertToExploreIdeasAsync(restaurants: [RestaurantRecommendation], activities: [RestaurantRecommendation]) async -> [ExploreIdea] {
        var restaurantIdeas: [ExploreIdea] = []
        var activityIdeas: [ExploreIdea] = []
        
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
                imageURL: "",
                websiteURL: recommendation.websiteURL,
                menuURL: recommendation.menuURL
            )
            
            if isRestaurant {
                restaurantIdeas.append(idea)
            } else {
                activityIdeas.append(idea)
            }
        }
        
        // Ensure minimum of 2 restaurants and 2 activities
        var finalIdeas: [ExploreIdea] = []
        
        // Add restaurants (at least 2)
        if restaurantIdeas.count >= 2 {
            finalIdeas.append(contentsOf: restaurantIdeas.prefix(restaurantIdeas.count))
        } else {
            // If we don't have enough restaurants, add what we have and create placeholders
            finalIdeas.append(contentsOf: restaurantIdeas)
            // Add placeholder restaurants if needed
            for i in restaurantIdeas.count..<2 {
                let placeholder = await createPlaceholderRestaurant(index: i)
                finalIdeas.append(placeholder)
            }
        }
        
        // Add activities (at least 2)
        if activityIdeas.count >= 2 {
            finalIdeas.append(contentsOf: activityIdeas.prefix(activityIdeas.count))
        } else {
            // If we don't have enough activities, add what we have and create placeholders
            finalIdeas.append(contentsOf: activityIdeas)
            // Add placeholder activities if needed
            for i in activityIdeas.count..<2 {
                let placeholder = await createPlaceholderActivity(index: i)
                finalIdeas.append(placeholder)
            }
        }
        
        // Shuffle the ideas to mix restaurants and activities
        return finalIdeas.shuffled()
    }
    
    private func createPlaceholderRestaurant(index: Int) async -> ExploreIdea {
        let placeholders = [
            ("Local Bistro", "A cozy neighborhood restaurant with fresh, locally-sourced ingredients and a warm atmosphere perfect for intimate conversations."),
            ("Garden Cafe", "An elegant dining spot featuring seasonal menu items and a beautiful outdoor seating area ideal for romantic dinners."),
            ("Artisan Kitchen", "A modern restaurant showcasing creative cuisine with an open kitchen concept and contemporary ambiance."),
            ("Heritage Diner", "A classic American diner serving comfort food favorites in a nostalgic setting with friendly service.")
        ]
        
        let placeholder = placeholders[index % placeholders.count]
        
        let tempRecommendation = RestaurantRecommendation(
            name: placeholder.0,
            description: placeholder.1,
            location: "Local Area",
            address: "Downtown Area",
            latitude: 0.0,
            longitude: 0.0,
            cuisineType: "American",
            priceLevel: "Moderate",
            isOpen: true,
            openHours: "5:00 PM - 10:00 PM",
            rating: 4.2,
            whyRecommended: "Great atmosphere for dates",
            estimatedCost: "$25-40",
            bestTime: "Evening",
            duration: "1-2 hours",
            imageURL: nil,
            websiteURL: nil,
            menuURL: nil
        )
        
        // Try to get image for placeholder restaurant
        var imageURL = ""
        if let placesImageURL = await imageService.getImageURL(for: tempRecommendation) {
            imageURL = placesImageURL
            print("✅ [ExploreService] Got placeholder restaurant image: \(placesImageURL)")
        } else {
            print("❌ [ExploreService] No placeholder restaurant image available")
        }
        
        return ExploreIdea(
            name: placeholder.0,
            description: placeholder.1,
            location: "Local Area",
            address: "Downtown Area",
            latitude: 0.0,
            longitude: 0.0,
            category: "restaurant",
            cuisineType: "American",
            activityType: nil,
            priceLevel: "Moderate",
            rating: 4.2,
            whyRecommended: "Great atmosphere for dates",
            estimatedCost: "$25-40",
            bestTime: "Evening",
            duration: "1-2 hours",
            isOpen: true,
            openHours: "5:00 PM - 10:00 PM",
            imageURL: imageURL,
            websiteURL: nil,
            menuURL: nil
        )
    }
    
    private func createPlaceholderActivity(index: Int) async -> ExploreIdea {
        let placeholders = [
            ("Art Gallery Walk", "Explore local art galleries and cultural spaces, perfect for discovering new artists and having meaningful conversations about creativity and expression."),
            ("Scenic Hiking Trail", "A beautiful nature trail with stunning views, ideal for outdoor enthusiasts who enjoy peaceful walks and connecting with nature."),
            ("Cooking Class", "Learn to prepare a new cuisine together in a hands-on cooking experience that's both fun and educational."),
            ("Live Music Venue", "Enjoy an intimate live music performance in a cozy venue, perfect for music lovers seeking a memorable evening together.")
        ]
        
        let placeholder = placeholders[index % placeholders.count]
        
        let tempRecommendation = RestaurantRecommendation(
            name: placeholder.0,
            description: placeholder.1,
            location: "Local Area",
            address: "Entertainment District",
            latitude: 0.0,
            longitude: 0.0,
            cuisineType: "entertainment",
            priceLevel: "Moderate",
            isOpen: true,
            openHours: "10:00 AM - 8:00 PM",
            rating: 4.0,
            whyRecommended: "Great for bonding and conversation",
            estimatedCost: "$15-30",
            bestTime: "Afternoon/Evening",
            duration: "2-3 hours",
            imageURL: nil,
            websiteURL: nil,
            menuURL: nil
        )
        
        // Try to get image for placeholder activity
        var imageURL = ""
        if let placesImageURL = await imageService.getImageURL(for: tempRecommendation) {
            imageURL = placesImageURL
            print("✅ [ExploreService] Got placeholder activity image: \(placesImageURL)")
        } else {
            print("❌ [ExploreService] No placeholder activity image available")
        }
        
        return ExploreIdea(
            name: placeholder.0,
            description: placeholder.1,
            location: "Local Area",
            address: "Entertainment District",
            latitude: 0.0,
            longitude: 0.0,
            category: "activity",
            cuisineType: nil,
            activityType: "entertainment",
            priceLevel: "Moderate",
            rating: 4.0,
            whyRecommended: "Great for bonding and conversation",
            estimatedCost: "$15-30",
            bestTime: "Afternoon/Evening",
            duration: "2-3 hours",
            isOpen: true,
            openHours: "10:00 AM - 8:00 PM",
            imageURL: imageURL,
            websiteURL: nil,
            menuURL: nil
        )
    }
    
    private func generateFallbackIdeas(for location: String, userCoordinate: CLLocationCoordinate2D) async -> [ExploreIdea] {
        var ideas: [ExploreIdea] = []
        
        // Use the user's actual location coordinates for fallback
        let baseLatitude = userCoordinate.latitude
        let baseLongitude = userCoordinate.longitude
        
        // Generate restaurant ideas
        let restaurantIdeas = [
            ("Local Bistro", "A cozy neighborhood restaurant with fresh, locally-sourced ingredients and a warm atmosphere perfect for intimate conversations.", "American", "Moderate"),
            ("Garden Cafe", "An elegant dining spot featuring seasonal menu items and a beautiful outdoor seating area ideal for romantic dinners.", "Contemporary", "Moderate"),
            ("Artisan Kitchen", "A modern restaurant showcasing creative cuisine with an open kitchen concept and contemporary ambiance.", "Fusion", "Upscale"),
            ("Heritage Diner", "A classic American diner serving comfort food favorites in a nostalgic setting with friendly service.", "American", "Budget")
        ]
        
        for (index, restaurant) in restaurantIdeas.enumerated() {
            let tempRecommendation = RestaurantRecommendation(
                name: restaurant.0,
                description: restaurant.1,
                location: location,
                address: "Downtown \(location)",
                latitude: baseLatitude + Double.random(in: -0.01...0.01),
                longitude: baseLongitude + Double.random(in: -0.01...0.01),
                cuisineType: restaurant.2,
                priceLevel: restaurant.3,
                isOpen: true,
                openHours: "5:00 PM - 10:00 PM",
                rating: Double.random(in: 3.8...4.8),
                whyRecommended: "Great atmosphere for dates",
                estimatedCost: restaurant.3 == "Budget" ? "$15-25" : restaurant.3 == "Moderate" ? "$25-40" : "$40-60",
                bestTime: "Evening",
                duration: "1-2 hours",
                imageURL: nil,
                websiteURL: nil,
                menuURL: nil
            )
            
            // Try to get image for fallback restaurant
            var imageURL = ""
            if let placesImageURL = await imageService.getImageURL(for: tempRecommendation) {
                imageURL = placesImageURL
                print("✅ [ExploreService] Got fallback restaurant image: \(placesImageURL)")
            } else {
                print("❌ [ExploreService] No fallback restaurant image available")
            }
            
            let idea = ExploreIdea(
                name: restaurant.0,
                description: restaurant.1,
                location: location,
                address: "Downtown \(location)",
                latitude: baseLatitude + Double.random(in: -0.01...0.01),
                longitude: baseLongitude + Double.random(in: -0.01...0.01),
                category: "restaurant",
                cuisineType: restaurant.2,
                activityType: nil,
                priceLevel: restaurant.3,
                rating: Double.random(in: 3.8...4.8),
                whyRecommended: "Great atmosphere for dates",
                estimatedCost: restaurant.3 == "Budget" ? "$15-25" : restaurant.3 == "Moderate" ? "$25-40" : "$40-60",
                bestTime: "Evening",
                duration: "1-2 hours",
                isOpen: true,
                openHours: "5:00 PM - 10:00 PM",
                imageURL: imageURL,
                websiteURL: nil,
                menuURL: nil
            )
            ideas.append(idea)
        }
        
        // Generate activity ideas
        let activityIdeas = [
            ("Art Gallery Walk", "Explore local art galleries and cultural spaces, perfect for discovering new artists and having meaningful conversations about creativity and expression.", "entertainment", "Moderate"),
            ("Scenic Hiking Trail", "A beautiful nature trail with stunning views, ideal for outdoor enthusiasts who enjoy peaceful walks and connecting with nature.", "outdoor", "Budget"),
            ("Cooking Class", "Learn to prepare a new cuisine together in a hands-on cooking experience that's both fun and educational.", "entertainment", "Moderate"),
            ("Live Music Venue", "Enjoy an intimate live music performance in a cozy venue, perfect for music lovers seeking a memorable evening together.", "entertainment", "Moderate")
        ]
        
        for (index, activity) in activityIdeas.enumerated() {
            let tempRecommendation = RestaurantRecommendation(
                name: activity.0,
                description: activity.1,
                location: location,
                address: "Entertainment District, \(location)",
                latitude: baseLatitude + Double.random(in: -0.01...0.01),
                longitude: baseLongitude + Double.random(in: -0.01...0.01),
                cuisineType: activity.2,
                priceLevel: activity.3,
                isOpen: true,
                openHours: "10:00 AM - 8:00 PM",
                rating: Double.random(in: 3.5...4.5),
                whyRecommended: "Great for bonding and conversation",
                estimatedCost: activity.3 == "Budget" ? "$10-20" : "$20-35",
                bestTime: "Afternoon/Evening",
                duration: "2-3 hours",
                imageURL: nil,
                websiteURL: nil,
                menuURL: nil
            )
            
            // Try to get image for fallback activity
            var imageURL = ""
            if let placesImageURL = await imageService.getImageURL(for: tempRecommendation) {
                imageURL = placesImageURL
                print("✅ [ExploreService] Got fallback activity image: \(placesImageURL)")
            } else {
                print("❌ [ExploreService] No fallback activity image available")
            }
            
            let idea = ExploreIdea(
                name: activity.0,
                description: activity.1,
                location: location,
                address: "Entertainment District, \(location)",
                latitude: baseLatitude + Double.random(in: -0.01...0.01),
                longitude: baseLongitude + Double.random(in: -0.01...0.01),
                category: "activity",
                cuisineType: nil,
                activityType: activity.2,
                priceLevel: activity.3,
                rating: Double.random(in: 3.5...4.5),
                whyRecommended: "Great for bonding and conversation",
                estimatedCost: activity.3 == "Budget" ? "$10-20" : "$20-35",
                bestTime: "Afternoon/Evening",
                duration: "2-3 hours",
                isOpen: true,
                openHours: "10:00 AM - 8:00 PM",
                imageURL: imageURL,
                websiteURL: nil,
                menuURL: nil
            )
            ideas.append(idea)
        }
        
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
