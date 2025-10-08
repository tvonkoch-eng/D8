//
//  RestaurantDetailService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation

class RestaurantDetailService: ObservableObject {
    static let shared = RestaurantDetailService()
    
    private let firebaseService = FirebaseService.shared
    private let openAIService = OpenAIService.shared
    private let restaurantDatabaseService = RestaurantDatabaseService.shared
    
    @Published var restaurantDetails: RestaurantDetails?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func getRestaurantDetails(for restaurant: ExploreIdea, completion: @escaping (Result<RestaurantDetails, Error>) -> Void) {
        // Convert ExploreIdea to RestaurantRecommendation for database lookup
        let restaurantRecommendation = RestaurantRecommendation(
            name: restaurant.name,
            description: restaurant.description,
            location: restaurant.location,
            address: restaurant.address,
            latitude: restaurant.latitude,
            longitude: restaurant.longitude,
            cuisineType: restaurant.cuisineType ?? "Unknown",
            priceLevel: restaurant.priceLevel,
            isOpen: restaurant.isOpen,
            openHours: restaurant.openHours,
            rating: restaurant.rating,
            whyRecommended: restaurant.whyRecommended,
            estimatedCost: restaurant.estimatedCost,
            bestTime: restaurant.bestTime,
            duration: restaurant.duration,
            imageURL: restaurant.imageURL,
            websiteURL: restaurant.websiteURL,
            menuURL: restaurant.menuURL
        )
        
        Task {
            do {
                // First, update view count
                try await restaurantDatabaseService.updateRestaurantViewCount(restaurantRecommendation)
                
                // Get restaurant details from database
                if let databaseEntry = try await restaurantDatabaseService.getRestaurantDetails(for: restaurantRecommendation) {
                    
                    // If we have enhanced details, use them
                    if databaseEntry.hasEnhancedDetails {
                        let details = RestaurantDetails(
                            restaurantId: databaseEntry.id,
                            name: databaseEntry.name,
                            description: databaseEntry.enhancedDescription ?? databaseEntry.description,
                            hours: databaseEntry.operatingHours ?? generateDefaultHours(),
                            additionalInfo: databaseEntry.additionalInfo ?? "Please call ahead for reservations and current information."
                        )
                        
                        DispatchQueue.main.async {
                            self.restaurantDetails = details
                            completion(.success(details))
                        }
                        return
                    }
                    
                    // If no enhanced details, create basic details and fetch enhanced ones in background
                    let basicDetails = RestaurantDetails(
                        restaurantId: databaseEntry.id,
                        name: databaseEntry.name,
                        description: databaseEntry.description,
                        hours: generateDefaultHours(),
                        additionalInfo: "Please call ahead for reservations and current information."
                    )
                    
                    DispatchQueue.main.async {
                        self.restaurantDetails = basicDetails
                        completion(.success(basicDetails))
                    }
                    
                    // Fetch enhanced details in background
                    Task {
                        do {
                            try await self.fetchAndSaveEnhancedDetails(for: restaurantRecommendation, databaseEntry: databaseEntry)
                        } catch {
                            print("❌ [RestaurantDetailService] Failed to fetch enhanced details: \(error.localizedDescription)")
                        }
                    }
                    
                } else {
                    // Restaurant not in database, create fallback details
                    print("⚠️ [RestaurantDetailService] Restaurant not found in database: \(restaurant.name)")
                    let fallbackDetails = createFallbackDetails(for: restaurant, restaurantId: generateRestaurantId(from: restaurant))
                    
                    DispatchQueue.main.async {
                        self.restaurantDetails = fallbackDetails
                        completion(.success(fallbackDetails))
                    }
                }
                
            } catch {
                print("❌ [RestaurantDetailService] Database error: \(error.localizedDescription)")
                // Create fallback details if database fails
                let fallbackDetails = createFallbackDetails(for: restaurant, restaurantId: generateRestaurantId(from: restaurant))
                
                DispatchQueue.main.async {
                    self.restaurantDetails = fallbackDetails
                    completion(.success(fallbackDetails))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateRestaurantId(from restaurant: ExploreIdea) -> String {
        // Use address as unique identifier since restaurant names can be duplicated
        let address = restaurant.address.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        // Also include coordinates for extra uniqueness
        let coordinates = "\(restaurant.latitude),\(restaurant.longitude)"
        
        return "\(address)_\(coordinates)".hashValue.description
    }
    
    private func fetchRestaurantDetailsFromOpenAI(for restaurant: ExploreIdea, restaurantId: String, completion: @escaping (Result<RestaurantDetails, Error>) -> Void) async throws {
        let prompt = createOpenAIPrompt(for: restaurant)
        
        do {
            let response = try await openAIService.generateRestaurantDetails(prompt: prompt)
            let details = parseOpenAIResponse(response, restaurantId: restaurantId, restaurantName: restaurant.name)
            completion(.success(details))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func fetchAndSaveEnhancedDetails(for restaurant: RestaurantRecommendation, databaseEntry: RestaurantDatabaseEntry) async throws {
        let prompt = createOpenAIPrompt(for: restaurant)
        
        do {
            let response = try await openAIService.generateRestaurantDetails(prompt: prompt)
            let (enhancedDescription, operatingHours, additionalInfo) = parseOpenAIResponse(response)
            
            // Update the database entry with enhanced details
            try await firebaseService.updateRestaurantEnhancedDetails(
                restaurantId: databaseEntry.id,
                enhancedDescription: enhancedDescription,
                operatingHours: operatingHours,
                additionalInfo: additionalInfo
            )
            
            print("✅ [RestaurantDetailService] Enhanced details saved for: \(restaurant.name)")
            
        } catch {
            print("❌ [RestaurantDetailService] Failed to fetch enhanced details: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func createOpenAIPrompt(for restaurant: RestaurantRecommendation) -> String {
        return """
        Please provide detailed information about the restaurant "\(restaurant.name)" located at "\(restaurant.address)".
        
        Please provide the following information in JSON format:
        {
            "description": "A detailed description of the restaurant, its atmosphere, cuisine style, and what makes it special",
            "hours": ["Monday: 11:00 AM - 10:00 PM", "Tuesday: 11:00 AM - 10:00 PM", ...],
            "additionalInfo": "Any additional relevant information like parking, dress code, reservations, special features, etc."
        }
        
        Please make the description engaging and informative, focusing on what makes this restaurant unique. For hours, provide realistic operating hours for each day of the week. For additional info, include practical details that would be helpful for diners.
        
        If you don't have specific information about this restaurant, please provide general information that would be typical for a restaurant of this type and location, but clearly indicate that this is general information.
        """
    }
    
    private func createOpenAIPrompt(for restaurant: ExploreIdea) -> String {
        return """
        Please provide detailed information about the restaurant "\(restaurant.name)" located at "\(restaurant.address)".
        
        Please provide the following information in JSON format:
        {
            "description": "A detailed description of the restaurant, its atmosphere, cuisine style, and what makes it special",
            "hours": ["Monday: 11:00 AM - 10:00 PM", "Tuesday: 11:00 AM - 10:00 PM", ...],
            "additionalInfo": "Any additional relevant information like parking, dress code, reservations, special features, etc."
        }
        
        Please make the description engaging and informative, focusing on what makes this restaurant unique. For hours, provide realistic operating hours for each day of the week. For additional info, include practical details that would be helpful for diners.
        
        If you don't have specific information about this restaurant, please provide general information that would be typical for a restaurant of this type and location, but clearly indicate that this is general information.
        """
    }
    
    private func parseOpenAIResponse(_ response: String) -> (String, [String], String) {
        // Try to parse JSON response
        if let data = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            let description = json["description"] as? String ?? "A wonderful dining experience awaits you."
            let hoursArray = json["hours"] as? [String] ?? generateDefaultHours()
            let additionalInfo = json["additionalInfo"] as? String ?? "Please call ahead for reservations and current information."
            
            return (description, hoursArray, additionalInfo)
        }
        
        // Fallback if JSON parsing fails
        return (
            "A wonderful dining experience awaits you.",
            generateDefaultHours(),
            "Please call ahead for reservations and current information."
        )
    }
    
    private func parseOpenAIResponse(_ response: String, restaurantId: String, restaurantName: String) -> RestaurantDetails {
        let (description, hoursArray, additionalInfo) = parseOpenAIResponse(response)
        
        return RestaurantDetails(
            restaurantId: restaurantId,
            name: restaurantName,
            description: description,
            hours: hoursArray,
            additionalInfo: additionalInfo
        )
    }
    
    private func createFallbackDetails(for restaurant: ExploreIdea, restaurantId: String) -> RestaurantDetails {
        let description = restaurant.description.isEmpty ? 
            "A wonderful dining experience awaits you at \(restaurant.name). Located at \(restaurant.address), this restaurant offers a unique culinary experience." :
            restaurant.description
        
        let additionalInfo = """
        Located at \(restaurant.address), \(restaurant.name) offers a great dining experience. 
        Please call ahead for reservations and current information about hours and availability.
        """
        
        return RestaurantDetails(
            restaurantId: restaurantId,
            name: restaurant.name,
            description: description,
            hours: generateDefaultHours(),
            additionalInfo: additionalInfo
        )
    }
    
    private func generateDefaultHours() -> [String] {
        return [
            "Monday: 11:00 AM - 10:00 PM",
            "Tuesday: 11:00 AM - 10:00 PM",
            "Wednesday: 11:00 AM - 10:00 PM",
            "Thursday: 11:00 AM - 10:00 PM",
            "Friday: 11:00 AM - 11:00 PM",
            "Saturday: 10:00 AM - 11:00 PM",
            "Sunday: 10:00 AM - 9:00 PM"
        ]
    }
}
