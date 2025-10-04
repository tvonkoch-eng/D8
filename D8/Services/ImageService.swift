//
//  ImageService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import UIKit

class ImageService: ObservableObject {
    static let shared = ImageService()
    
    // API Keys - Add these to your environment or config
    private let unsplashAccessKey = "YOUR_UNSPLASH_ACCESS_KEY" // Get from https://unsplash.com/developers
    private let pexelsAPIKey = "YOUR_PEXELS_API_KEY" // Get from https://www.pexels.com/api/
    private let foursquareAPIKey = "YOUR_FOURSQUARE_API_KEY" // Get from https://developer.foursquare.com/
    private let googlePlacesAPIKey = "AIzaSyCz7OlK0dpbMuX1FLQXpUjKUMJQf0XzTkY" // Google Places API key
    
    // Cache for images to avoid repeated API calls
    private var imageCache: [String: UIImage] = [:]
    private var urlCache: [String: String] = [:]
    
    // Rate limiting
    private var lastUnsplashCall = Date.distantPast
    private var lastPexelsCall = Date.distantPast
    private var unsplashCallCount = 0
    private var pexelsCallCount = 0
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Test Google Places API integration
    func testGooglePlacesAPI() async {
        let testRestaurant = RestaurantRecommendation(
            name: "The French Laundry",
            description: "A world-renowned restaurant",
            location: "Yountville, CA",
            address: "6640 Washington St, Yountville, CA 94599",
            latitude: 38.4035,
            longitude: -122.3621,
            cuisineType: "french",
            priceLevel: "luxury",
            isOpen: true,
            openHours: "5:00 PM - 9:00 PM",
            rating: 4.8,
            whyRecommended: "Exceptional fine dining experience",
            estimatedCost: "$300+ per person",
            bestTime: "7:00 PM",
            duration: "3-4 hours",
            imageURL: nil,
            websiteURL: nil,
            menuURL: nil
        )
        
        if let imageURL = await fetchGooglePlacesImage(for: testRestaurant) {
            print("✅ Google Places API test successful!")
            print("Image URL: \(imageURL)")
        } else {
            print("❌ Google Places API test failed")
        }
    }
    
    /// Get image URL for a restaurant/activity based on cuisine type or activity type
    func getImageURL(for recommendation: RestaurantRecommendation) async -> String? {
        let cacheKey = "\(recommendation.name)_\(recommendation.cuisineType)"
        
        // Check cache first
        if let cachedURL = urlCache[cacheKey] {
            return cachedURL
        }
        
        // Try Google Places API first (most relevant for restaurants)
        if let imageURL = await fetchGooglePlacesImage(for: recommendation) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        // Determine search query based on cuisine type
        let searchQuery = getSearchQuery(for: recommendation)
        
        // Try multiple APIs in order of preference
        if let imageURL = await fetchPexelsImage(query: searchQuery) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        if let imageURL = await fetchUnsplashImage(query: searchQuery) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        // Fallback to location-based search
        if let imageURL = await fetchLocationBasedImage(for: recommendation) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        return nil
    }
    
    /// Get image URL for an explore idea
    func getImageURL(for idea: ExploreIdea) async -> String? {
        let cacheKey = "\(idea.name)_\(idea.cuisineType ?? idea.activityType ?? "")"
        
        // Check cache first
        if let cachedURL = urlCache[cacheKey] {
            return cachedURL
        }
        
        // Determine search query
        let searchQuery = getSearchQuery(for: idea)
        
        // Try multiple APIs in order of preference
        if let imageURL = await fetchPexelsImage(query: searchQuery) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        if let imageURL = await fetchUnsplashImage(query: searchQuery) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        // Fallback to location-based search
        if let imageURL = await fetchLocationBasedImage(for: idea) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        return nil
    }
    
    /// Load and cache an image from URL
    func loadImage(from urlString: String) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache[urlString] {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                imageCache[urlString] = image
                return image
            }
        } catch {
            print("Error loading image from \(urlString): \(error)")
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func fetchGooglePlacesImage(for recommendation: RestaurantRecommendation) async -> String? {
        print("🔍 [Google Places] Starting image fetch for: \(recommendation.name)")
        
        // Step 1: Search for the place to get place_id
        guard let placeId = await searchGooglePlaceId(for: recommendation) else {
            print("❌ [Google Places] Failed to get place_id for: \(recommendation.name)")
            return nil
        }
        
        print("✅ [Google Places] Got place_id: \(placeId)")
        
        // Step 2: Get place details with photo references
        guard let photoReference = await getGooglePlacePhotoReference(for: placeId) else {
            print("❌ [Google Places] Failed to get photo reference for place_id: \(placeId)")
            return nil
        }
        
        print("✅ [Google Places] Got photo reference: \(photoReference)")
        
        // Step 3: Construct the photo URL
        let photoURL = constructGooglePhotoURL(photoReference: photoReference)
        print("✅ [Google Places] Generated photo URL: \(photoURL)")
        
        return photoURL
    }
    
    private func searchGooglePlaceId(for recommendation: RestaurantRecommendation) async -> String? {
        let query = "\(recommendation.name) \(recommendation.address)"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(encodedQuery)&key=\(googlePlacesAPIKey)"
        
        print("🔍 [Google Places] Search URL: \(urlString)")
        
        guard let url = URL(string: urlString) else { 
            print("❌ [Google Places] Invalid URL")
            return nil 
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [Google Places] HTTP Status: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "No data"
            print("📄 [Google Places] Response: \(responseString.prefix(200))...")
            
            let googleResponse = try JSONDecoder().decode(GooglePlacesSearchResponse.self, from: data)
            
            if let result = googleResponse.results.first {
                print("✅ [Google Places] Found place: \(result.name)")
                return result.place_id
            } else {
                print("❌ [Google Places] No results found")
            }
        } catch {
            print("❌ [Google Places] Search error: \(error)")
        }
        
        return nil
    }
    
    private func getGooglePlacePhotoReference(for placeId: String) async -> String? {
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(placeId)&fields=photos&key=\(googlePlacesAPIKey)"
        
        print("🔍 [Google Places] Details URL: \(urlString)")
        
        guard let url = URL(string: urlString) else { 
            print("❌ [Google Places] Invalid details URL")
            return nil 
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [Google Places] Details HTTP Status: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "No data"
            print("📄 [Google Places] Details Response: \(responseString.prefix(200))...")
            
            let googleResponse = try JSONDecoder().decode(GooglePlacesDetailsResponse.self, from: data)
            
            if let photo = googleResponse.result.photos.first {
                print("✅ [Google Places] Found photo reference: \(photo.photo_reference)")
                return photo.photo_reference
            } else {
                print("❌ [Google Places] No photos found for place_id: \(placeId)")
            }
        } catch {
            print("❌ [Google Places] Details error: \(error)")
        }
        
        return nil
    }
    
    private func constructGooglePhotoURL(photoReference: String) -> String {
        return "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=\(photoReference)&key=\(googlePlacesAPIKey)"
    }
    
    private func getSearchQuery(for recommendation: RestaurantRecommendation) -> String {
        let cuisineType = recommendation.cuisineType.lowercased()
        let name = recommendation.name.lowercased()
        
        // Extract meaningful words from the activity name
        let separators = CharacterSet.whitespaces.union(CharacterSet.punctuationCharacters)
        let nameWords = name.components(separatedBy: separators)
            .filter { !$0.isEmpty && $0.count > 2 }
            .prefix(2) // Take first 2 meaningful words
        
        // Map cuisine types to better search terms with activity-specific keywords
        switch cuisineType {
        case "italian":
            return "italian restaurant pasta food dining \(nameWords.joined(separator: " "))"
        case "mexican":
            return "mexican restaurant tacos food dining \(nameWords.joined(separator: " "))"
        case "american":
            return "american restaurant burger food dining \(nameWords.joined(separator: " "))"
        case "japanese":
            return "japanese restaurant sushi food dining \(nameWords.joined(separator: " "))"
        case "chinese":
            return "chinese restaurant food dining \(nameWords.joined(separator: " "))"
        case "indian":
            return "indian restaurant curry food dining \(nameWords.joined(separator: " "))"
        case "thai":
            return "thai restaurant food dining \(nameWords.joined(separator: " "))"
        case "french":
            return "french restaurant food dining \(nameWords.joined(separator: " "))"
        case "mediterranean":
            return "mediterranean restaurant food dining \(nameWords.joined(separator: " "))"
        case "seafood":
            return "seafood restaurant fish food dining \(nameWords.joined(separator: " "))"
        case "steakhouse":
            return "steakhouse restaurant steak food dining \(nameWords.joined(separator: " "))"
        case "contemporary":
            return "modern restaurant fine dining food \(nameWords.joined(separator: " "))"
        case "sports":
            if name.contains("gym") || name.contains("fitness") {
                return "gym workout fitness equipment \(nameWords.joined(separator: " "))"
            } else if name.contains("yoga") {
                return "yoga class meditation wellness \(nameWords.joined(separator: " "))"
            } else if name.contains("tennis") {
                return "tennis court racket sport \(nameWords.joined(separator: " "))"
            } else if name.contains("basketball") {
                return "basketball court sport game \(nameWords.joined(separator: " "))"
            } else if name.contains("swimming") {
                return "swimming pool water sport \(nameWords.joined(separator: " "))"
            } else {
                return "sports fitness activity \(nameWords.joined(separator: " "))"
            }
        case "outdoor":
            if name.contains("hiking") || name.contains("trail") {
                return "hiking trail mountain nature \(nameWords.joined(separator: " "))"
            } else if name.contains("park") {
                return "park outdoor nature green \(nameWords.joined(separator: " "))"
            } else if name.contains("beach") {
                return "beach ocean water sand \(nameWords.joined(separator: " "))"
            } else if name.contains("garden") {
                return "garden flowers plants nature \(nameWords.joined(separator: " "))"
            } else if name.contains("zoo") {
                return "zoo animals wildlife nature \(nameWords.joined(separator: " "))"
            } else {
                return "outdoor nature activity \(nameWords.joined(separator: " "))"
            }
        case "indoor":
            if name.contains("museum") {
                return "museum indoor culture art \(nameWords.joined(separator: " "))"
            } else if name.contains("library") {
                return "library books reading study \(nameWords.joined(separator: " "))"
            } else if name.contains("gallery") {
                return "art gallery exhibition culture \(nameWords.joined(separator: " "))"
            } else if name.contains("spa") {
                return "spa relaxation wellness massage \(nameWords.joined(separator: " "))"
            } else if name.contains("escape") {
                return "escape room puzzle game \(nameWords.joined(separator: " "))"
            } else {
                return "indoor activity \(nameWords.joined(separator: " "))"
            }
        case "entertainment":
            if name.contains("movie") || name.contains("cinema") {
                return "movie theater cinema entertainment \(nameWords.joined(separator: " "))"
            } else if name.contains("bowling") {
                return "bowling alley game entertainment \(nameWords.joined(separator: " "))"
            } else if name.contains("arcade") {
                return "arcade games entertainment fun \(nameWords.joined(separator: " "))"
            } else if name.contains("karaoke") {
                return "karaoke singing entertainment music \(nameWords.joined(separator: " "))"
            } else if name.contains("comedy") {
                return "comedy show entertainment stage \(nameWords.joined(separator: " "))"
            } else if name.contains("theater") {
                return "theater stage performance entertainment \(nameWords.joined(separator: " "))"
            } else {
                return "entertainment fun activity \(nameWords.joined(separator: " "))"
            }
        case "fitness":
            return "fitness activity workout gym \(nameWords.joined(separator: " "))"
        default:
            // For unknown types, try to use the activity name
            if !nameWords.isEmpty {
                return "\(cuisineType) \(nameWords.joined(separator: " "))"
            } else {
                return "restaurant food dining"
            }
        }
    }
    
    private func getSearchQuery(for idea: ExploreIdea) -> String {
        if let cuisineType = idea.cuisineType {
            return getSearchQuery(for: RestaurantRecommendation(
                name: idea.name,
                description: idea.description,
                location: idea.location,
                address: idea.address,
                latitude: idea.latitude,
                longitude: idea.longitude,
                cuisineType: cuisineType,
                priceLevel: idea.priceLevel,
                isOpen: idea.isOpen,
                openHours: idea.openHours,
                rating: idea.rating,
                whyRecommended: idea.whyRecommended,
                estimatedCost: idea.estimatedCost,
                bestTime: idea.bestTime,
                duration: idea.duration,
                imageURL: idea.imageURL,
                websiteURL: idea.websiteURL,
                menuURL: idea.menuURL
            ))
        } else if let activityType = idea.activityType {
            return getSearchQuery(for: RestaurantRecommendation(
                name: idea.name,
                description: idea.description,
                location: idea.location,
                address: idea.address,
                latitude: idea.latitude,
                longitude: idea.longitude,
                cuisineType: activityType,
                priceLevel: idea.priceLevel,
                isOpen: idea.isOpen,
                openHours: idea.openHours,
                rating: idea.rating,
                whyRecommended: idea.whyRecommended,
                estimatedCost: idea.estimatedCost,
                bestTime: idea.bestTime,
                duration: idea.duration,
                imageURL: idea.imageURL,
                websiteURL: idea.websiteURL,
                menuURL: idea.menuURL
            ))
        } else {
            return "restaurant food dining"
        }
    }
    
    private func fetchPexelsImage(query: String) async -> String? {
        guard !pexelsAPIKey.isEmpty && pexelsAPIKey != "YOUR_PEXELS_API_KEY" else {
            print("Pexels API key not configured")
            return nil
        }
        
        // Rate limiting: 200 requests per hour
        let now = Date()
        if now.timeIntervalSince(lastPexelsCall) < 3600 { // 1 hour
            if pexelsCallCount >= 200 {
                print("Pexels rate limit reached")
                return nil
            }
        } else {
            pexelsCallCount = 0
            lastPexelsCall = now
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.pexels.com/v1/search?query=\(encodedQuery)&per_page=1&orientation=landscape"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(pexelsAPIKey, forHTTPHeaderField: "Authorization")
        request.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(PexelsResponse.self, from: data)
            
            if let photo = response.photos.first {
                pexelsCallCount += 1
                return photo.src.medium
            }
        } catch {
            print("Pexels API error: \(error)")
        }
        
        return nil
    }
    
    private func fetchUnsplashImage(query: String) async -> String? {
        guard !unsplashAccessKey.isEmpty && unsplashAccessKey != "YOUR_UNSPLASH_ACCESS_KEY" else {
            print("Unsplash API key not configured")
            return nil
        }
        
        // Rate limiting: 50 requests per hour
        let now = Date()
        if now.timeIntervalSince(lastUnsplashCall) < 3600 { // 1 hour
            if unsplashCallCount >= 50 {
                print("Unsplash rate limit reached")
                return nil
            }
        } else {
            unsplashCallCount = 0
            lastUnsplashCall = now
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.unsplash.com/search/photos?query=\(encodedQuery)&per_page=1&orientation=landscape"
        
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(unsplashAccessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("D8-iOS/2.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(UnsplashResponse.self, from: data)
            
            if let photo = response.results.first {
                unsplashCallCount += 1
                return photo.urls.regular
            }
        } catch {
            print("Unsplash API error: \(error)")
        }
        
        return nil
    }
    
    private func fetchLocationBasedImage(for recommendation: RestaurantRecommendation) async -> String? {
        // Use location + activity type for more relevant images
        let location = recommendation.location.components(separatedBy: ",").first ?? ""
        let activityType = recommendation.cuisineType.lowercased()
        
        let locationQuery = "\(location) \(activityType)"
        
        // Try Pexels first for location-based search
        if let imageURL = await fetchPexelsImage(query: locationQuery) {
            return imageURL
        }
        
        // Try Unsplash for location-based search
        if let imageURL = await fetchUnsplashImage(query: locationQuery) {
            return imageURL
        }
        
        return nil
    }
    
    private func fetchLocationBasedImage(for idea: ExploreIdea) async -> String? {
        // Use location + activity type for more relevant images
        let location = idea.location.components(separatedBy: ",").first ?? ""
        let activityType = idea.activityType ?? idea.cuisineType ?? ""
        
        let locationQuery = "\(location) \(activityType)"
        
        // Try Pexels first for location-based search
        if let imageURL = await fetchPexelsImage(query: locationQuery) {
            return imageURL
        }
        
        // Try Unsplash for location-based search
        if let imageURL = await fetchUnsplashImage(query: locationQuery) {
            return imageURL
        }
        
        return nil
    }
}

// MARK: - API Response Models

struct UnsplashResponse: Codable {
    let results: [UnsplashPhoto]
}

struct UnsplashPhoto: Codable {
    let urls: UnsplashUrls
    let user: UnsplashUser
}

struct UnsplashUrls: Codable {
    let regular: String
    let small: String
    let thumb: String
}

struct UnsplashUser: Codable {
    let name: String
    let username: String
}

struct PexelsResponse: Codable {
    let photos: [PexelsPhoto]
}

struct PexelsPhoto: Codable {
    let src: PexelsSrc
    let photographer: String
}

struct PexelsSrc: Codable {
    let medium: String
    let small: String
    let tiny: String
}

// MARK: - Google Places API Response Models

struct GooglePlacesSearchResponse: Codable {
    let results: [GooglePlacesSearchResult]
}

struct GooglePlacesSearchResult: Codable {
    let place_id: String
    let name: String
}

struct GooglePlacesDetailsResponse: Codable {
    let result: GooglePlacesDetailsResult
}

struct GooglePlacesDetailsResult: Codable {
    let photos: [GooglePlacesPhoto]
}

struct GooglePlacesPhoto: Codable {
    let photo_reference: String
    let html_attributions: [String]
}