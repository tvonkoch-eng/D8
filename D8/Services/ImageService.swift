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
    
    // API Keys - Only Google Places API for restaurant images
    private let googlePlacesAPIKey = "AIzaSyCz7OlK0dpbMuX1FLQXpUjKUMJQf0XzTkY" // Google Places API key
    
    // Cache for images to avoid repeated API calls
    private var imageCache: [String: UIImage] = [:]
    private var urlCache: [String: String] = [:]
    
    // Rate limiting
    private var lastGooglePlacesCall = Date.distantPast
    private var googlePlacesCallCount = 0
    
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
    
    /// Get image URL for a restaurant/activity using Google Places API only
    func getImageURL(for recommendation: RestaurantRecommendation) async -> String? {
        let cacheKey = "\(recommendation.name)_\(recommendation.cuisineType)"
        
        // Check cache first
        if let cachedURL = urlCache[cacheKey] {
            return cachedURL
        }
        
        // Try Google Places API (only source for restaurant images)
        if let imageURL = await fetchGooglePlacesImage(for: recommendation) {
            urlCache[cacheKey] = imageURL
            return imageURL
        }
        
        // Return nil if no image found (no placeholder images)
        return nil
    }
    
    /// Get image URL for an explore idea using Google Places API only
    func getImageURL(for idea: ExploreIdea) async -> String? {
        let cacheKey = "\(idea.name)_\(idea.cuisineType ?? idea.activityType ?? "")"
        
        // Check cache first
        if let cachedURL = urlCache[cacheKey] {
            return cachedURL
        }
        
        // Try Google Places API (only source for restaurant images)
        if let cuisineType = idea.cuisineType {
            let tempRecommendation = RestaurantRecommendation(
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
            )
            
            if let imageURL = await fetchGooglePlacesImage(for: tempRecommendation) {
                urlCache[cacheKey] = imageURL
                return imageURL
            }
        }
        
        // Return nil if no image found (no placeholder images)
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