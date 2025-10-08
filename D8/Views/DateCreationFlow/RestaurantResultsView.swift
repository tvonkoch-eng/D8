//
//  RestaurantResultsView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI
import CoreLocation

struct RestaurantResultsView: View {
    let dateType: DateType?
    let mealTimes: Set<MealTime>
    let priceRange: PriceRange?
    let date: Date
    let cuisines: Set<Cuisine>
    
    @StateObject private var backendService = BackendService.shared
    @State private var recommendations: [RestaurantRecommendation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var locationManager = LocationManager()
    @State private var progressText = "Initializing search..."
    @State private var progressValue: Double = 0.0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 30) {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Progress bar
                        VStack(spacing: 12) {
                            ProgressView(value: progressValue, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(width: 200)
                                .animation(.easeInOut(duration: 0.3), value: progressValue)
                            
                            Text(progressText)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .animation(.easeInOut(duration: 0.2), value: progressText)
                        }
                        
                        // Loading animation
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(progressValue > Double(index) * 0.3 ? 1.2 : 0.8)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: progressValue)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                        .foregroundColor(.orange)
                        
                        Text("Oops!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    }
                    
                    Button("Try Again") {
                        loadRecommendations()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Spacer()
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    // Compact header
                    HStack {
                        Text("2 Perfect Matches")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color(.systemGray5))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    // Two results side by side
                    if recommendations.count >= 2 {
                        TabView {
                            ForEach(Array(recommendations.prefix(2).enumerated()), id: \.element.id) { index, recommendation in
                                CompactRestaurantCardView(
                                    recommendation: recommendation, 
                                    dateType: dateType,
                                    matchNumber: index + 1
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 300)
                    } else if recommendations.count == 1 {
                        CompactRestaurantCardView(
                            recommendation: recommendations[0], 
                            dateType: dateType,
                            matchNumber: 1
                        )
                        .padding(.horizontal, 20)
                        .frame(height: 300)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No matches found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button("Try Different Preferences") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(height: 300)
                    }
                    
                    // Get more options button
                    if recommendations.count >= 2 {
                        Button("Get 2 More Options") {
                            // Refresh with different criteria
                            loadRecommendations()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.seaweedGreen)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .stroke(Color.seaweedGreen, lineWidth: 2)
                        )
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadRecommendations()
        }
    }
    
    private func loadRecommendations() {
        isLoading = true
        errorMessage = nil
        progressValue = 0.0
        progressText = "Initializing search..."
        
        // Start smooth 15-second progress animation
        startProgressAnimation()
        
        // Get current location
        locationManager.getCurrentLocation { coordinate in
            guard let coordinate = coordinate else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Unable to get your location. Please check location permissions."
                }
                return
            }
            
            let locationString = "Current Location"
            
            backendService.getDateRecommendations(
                location: locationString,
                dateType: self.dateType ?? .meal,
                mealTimes: self.mealTimes,
                priceRange: self.priceRange,
                cuisines: self.cuisines,
                activityTypes: nil,
                activityIntensity: nil,
                date: self.date,
                coordinate: coordinate
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let backendRecommendations):
                        // Convert BackendPlaceRecommendation to RestaurantRecommendation
                        let recommendations = backendRecommendations.compactMap { backendRec in
                            self.convertBackendToRestaurantRecommendation(backendRec)
                        }
                        // Limit to 2 perfect matches
                        self.recommendations = Array(recommendations.prefix(2))
                        self.progressText = "Found \(recommendations.count) restaurants!"
                        self.progressValue = 1.0
                        
                        // Store recommendations in Firebase
                        self.storeRestaurantRecommendationsInFirebase(recommendations)
                        
                        // Hide progress after a moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.progressText = ""
                        }
                        
                    case .failure(let error):
                        print("Backend Error: \(error)")
                        if let decodingError = error as? DecodingError {
                            print("Decoding Error Details: \(decodingError)")
                        }
                        
                        // Use fallback mock data for testing
                        print("Using fallback mock data...")
                        let mockRecommendations = self.generateMockRestaurantRecommendations()
                        // Limit to 2 perfect matches
                        self.recommendations = Array(mockRecommendations.prefix(2))
                        self.progressText = "Found \(mockRecommendations.count) restaurants!"
                        self.progressValue = 1.0
                        
                        // Hide progress after a moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.progressText = ""
                        }
                    }
                }
            }
        }
    }
    
    private func startProgressAnimation() {
        // Smooth progress animation over 15 seconds
        let totalDuration: TimeInterval = 15.0
        let steps = 30
        let stepDuration = totalDuration / Double(steps)
        
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                let progress = Double(i) / Double(steps)
                self.progressValue = progress
                
                // Update progress text
                if progress < 0.3 {
                    self.progressText = "Searching restaurants..."
                } else if progress < 0.6 {
                    self.progressText = "Filtering by preferences..."
                } else if progress < 0.9 {
                    self.progressText = "Ranking results..."
                } else {
                    self.progressText = "Finalizing recommendations..."
                }
            }
        }
    }
    
    // MARK: - Conversion Helper
    private func convertBackendToRestaurantRecommendation(_ backendRec: BackendPlaceRecommendation) -> RestaurantRecommendation? {
        // Only convert restaurant-type recommendations for meal dates
        guard dateType == .meal else {
            return nil // Don't convert activities to restaurants
        }
        
        // Only convert restaurant-type recommendations
        guard backendRec.category.lowercased().contains("restaurant") || 
              backendRec.category.lowercased().contains("food") ||
              backendRec.category.lowercased().contains("dining") else {
            return nil
        }
        
        return RestaurantRecommendation(
            name: backendRec.name,
            description: backendRec.description,
            location: backendRec.location,
            address: backendRec.address,
            latitude: backendRec.latitude,
            longitude: backendRec.longitude,
            cuisineType: backendRec.cuisine,
            priceLevel: mapEstimatedCostToPriceLevel(backendRec.estimatedCost),
            isOpen: true,
            openHours: "11:00 AM - 10:00 PM", // Default hours since not provided by backend
            rating: 4.0, // Default rating since not provided by backend
            whyRecommended: backendRec.whyRecommended,
            estimatedCost: backendRec.estimatedCost,
            bestTime: backendRec.bestTime,
            duration: "2-3 hours", // Default duration
            imageURL: nil, // Not provided by backend
            websiteURL: nil, // Not provided by backend
            menuURL: nil // Not provided by backend
        )
    }
    
    private func mapEstimatedCostToPriceLevel(_ estimatedCost: String) -> String {
        let cost = estimatedCost.lowercased()
        
        if cost.contains("$") {
            // Extract dollar signs from cost string
            let dollarCount = cost.filter { $0 == "$" }.count
            return String(repeating: "$", count: min(dollarCount, 4))
        } else if cost.contains("low") || cost.contains("budget") || cost.contains("cheap") {
            return "$"
        } else if cost.contains("medium") || cost.contains("moderate") || cost.contains("mid") {
            return "$$"
        } else if cost.contains("high") || cost.contains("expensive") || cost.contains("upscale") {
            return "$$$"
        } else if cost.contains("very high") || cost.contains("luxury") || cost.contains("fine dining") {
            return "$$$$"
        } else {
            return "$$" // Default fallback
        }
    }
    
    // MARK: - Mock Data Generator
    private func generateMockRestaurantRecommendations() -> [RestaurantRecommendation] {
        let mockRestaurants = [
            RestaurantRecommendation(
                name: "Loquita",
                description: "Loquita offers a vibrant and lively atmosphere with a modern Spanish twist, creating a romantic and energetic dining experience.",
                location: "Santa Barbara, CA",
                address: "202 State St, Santa Barbara, CA 93101",
                latitude: 34.4208,
                longitude: -119.6982,
                cuisineType: "Spanish",
                priceLevel: "$$",
                isOpen: true,
                openHours: "11:00 AM - 10:00 PM",
                rating: 4.5,
                whyRecommended: "Perfect for a romantic Spanish tapas experience",
                estimatedCost: "$25-45",
                bestTime: "Evening",
                duration: "2-3 hours",
                imageURL: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800",
                websiteURL: "https://loquitasb.com",
                menuURL: nil
            ),
            RestaurantRecommendation(
                name: "The French Laundry",
                description: "An elegant fine dining experience featuring contemporary French cuisine in a beautiful Napa Valley setting.",
                location: "Yountville, CA",
                address: "6640 Washington St, Yountville, CA 94599",
                latitude: 38.4016,
                longitude: -122.3608,
                cuisineType: "French",
                priceLevel: "$$$$",
                isOpen: true,
                openHours: "5:30 PM - 9:00 PM",
                rating: 4.8,
                whyRecommended: "World-renowned fine dining experience",
                estimatedCost: "$300-400",
                bestTime: "Evening",
                duration: "3-4 hours",
                imageURL: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800",
                websiteURL: "https://thomaskeller.com/tfl",
                menuURL: nil
            ),
            RestaurantRecommendation(
                name: "Sushi Nakazawa",
                description: "An intimate omakase experience featuring the finest sushi and sashimi prepared by master chefs.",
                location: "New York, NY",
                address: "23 Commerce St, New York, NY 10014",
                latitude: 40.7328,
                longitude: -74.0071,
                cuisineType: "Japanese",
                priceLevel: "$$$",
                isOpen: true,
                openHours: "5:00 PM - 10:30 PM",
                rating: 4.7,
                whyRecommended: "Exceptional omakase experience",
                estimatedCost: "$150-200",
                bestTime: "Evening",
                duration: "2-3 hours",
                imageURL: "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800",
                websiteURL: "https://sushinakazawa.com",
                menuURL: nil
            )
        ]
        
        return mockRestaurants
    }
    
    // MARK: - Firebase Storage
    private func storeRestaurantRecommendationsInFirebase(_ recommendations: [RestaurantRecommendation]) {
        // Store each restaurant recommendation in Firebase for later retrieval
        for recommendation in recommendations {
            FirebaseService.shared.storeRecommendation(
                name: recommendation.name,
                description: recommendation.description,
                category: "restaurant",
                location: recommendation.location,
                latitude: recommendation.latitude,
                longitude: recommendation.longitude,
                estimatedCost: recommendation.estimatedCost,
                bestTime: recommendation.bestTime,
                whyRecommended: recommendation.whyRecommended,
                dateType: dateType ?? .meal
            )
        }
    }
}

struct RestaurantCardView: View {
    let recommendation: RestaurantRecommendation
    let dateType: DateType?
    @State private var userLocation: CLLocation?
    @State private var distance: Double?
    @State private var isPressed = false
    
    var body: some View {
        imageSection
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.seaweedGreen.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 5)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onAppear {
                calculateDistance()
            }
    }
    
    // MARK: - Image Section
    private var imageSection: some View {
        ZStack {
            // Background image container with fixed dimensions
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 240)
                .padding(.horizontal, 4)
                .overlay(
                    Group {
                        if let imageURL = recommendation.imageURL, !imageURL.isEmpty {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: .infinity, height: 240)
                                    .clipped()
                            } placeholder: {
                                // Loading placeholder
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 240)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            Text("Loading...")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    )
                            }
                        } else {
                            // No image placeholder
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 240)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                        Text("No Image")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                                )
                        }
                    }
                )
            
            // Gradient overlay
            gradientOverlay
            
            // Content overlay (bottom)
            VStack {
                Spacer()
                HStack {
                    contentOverlay
                    Spacer()
                }
            }
        }
        .frame(height: 240)
        .cornerRadius(16)
    }
    
    // MARK: - Gradient Overlay
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.black.opacity(0.1),
                Color.black.opacity(0.4),
                Color.black.opacity(0.8)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Content Overlay
    private var contentOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Restaurant title as dropdown menu
            Menu {
                // Website link
                if let websiteURL = recommendation.websiteURL, let url = URL(string: websiteURL) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Label("Visit Website", systemImage: "safari")
                    }
                }
                
                // Menu link
                if let menuURL = recommendation.menuURL, let url = URL(string: menuURL) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Label("View Menu", systemImage: "doc.text")
                    }
                }
                
                // Address link (opens in Maps)
                Button(action: {
                    openInAppleMaps()
                }) {
                    Label("Get Directions", systemImage: "location")
                }
            } label: {
                HStack {
                    Text(recommendation.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                }
            }
            
            // Key information over the image
            keyInfoRow
            
            // Address
            addressText
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    
    // MARK: - Key Info Row
    private var keyInfoRow: some View {
        HStack(spacing: 12) {
            // Rating
            ratingView
            
            // Price level
            priceLevelView
            
            // Cuisine type
            if !recommendation.cuisineType.isEmpty {
                cuisineTypeView
            }
            
            Spacer()
        }
    }
    
    // MARK: - Rating View
    private var ratingView: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(recommendation.rating) ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            Text(String(format: "%.1f", recommendation.rating))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Price Level View
    private var priceLevelView: some View {
        Text(formatPriceLevel(recommendation.priceLevel))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
    }
    
    // MARK: - Cuisine Type View
    private var cuisineTypeView: some View {
        Text(formatCuisineType(recommendation.cuisineType))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
    }
    
    // MARK: - Address Text
    private var addressText: some View {
        Text(recommendation.address)
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(1)
            .truncationMode(.tail)
    }
    
    private func openInAppleMaps() {
        // Use restaurant name for searching instead of exact address
        let searchQuery = recommendation.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mapsURL = "http://maps.apple.com/?q=\(searchQuery)"
        
        if let url = URL(string: mapsURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func calculateDistance() {
        guard let currentLocation = LocationManager.shared.currentLocation else {
            // Get user location if not available
            LocationManager.shared.getCurrentLocation { coordinate in
                guard let coordinate = coordinate else {
                    print("Failed to get user location")
                    return
                }
                self.userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                self.calculateDistance()
            }
            return
        }
        
        let userLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let restaurantLocation = CLLocation(
            latitude: recommendation.latitude,
            longitude: recommendation.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: restaurantLocation)
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert meters to miles
        self.distance = distanceInMiles
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1.0 {
            return String(format: "%.1f mi", distance)
        } else {
            return String(format: "%.0f mi", distance)
        }
    }
    
    private func formatCuisineType(_ cuisineType: String) -> String {
        // Split by common delimiters and clean up
        let cuisines = cuisineType.components(separatedBy: CharacterSet(charactersIn: ",;&|"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if cuisines.count <= 1 {
            return cuisineType
        } else {
            let additionalCount = cuisines.count - 1
            return "\(cuisines[0]) +\(additionalCount)"
        }
    }
    
    private func formatPriceLevel(_ priceLevel: String) -> String {
        let level = priceLevel.lowercased()
        
        switch level {
        case "low", "budget", "cheap":
            return "$"
        case "medium", "moderate", "mid":
            return "$$"
        case "high", "expensive", "upscale":
            return "$$$"
        case "very high", "luxury", "fine dining":
            return "$$$$"
        default:
            // Try to extract dollar signs or numbers
            if level.contains("$") {
                return level.uppercased()
            } else if let range = level.range(of: #"\d+"#, options: .regularExpression) {
                let number = String(level[range])
                if let num = Int(number) {
                    return String(repeating: "$", count: min(num, 4))
                }
            }
            return "$$" // Default fallback
        }
    }
    
    private func generateReviewCount() -> String {
        // Generate deterministic review counts based on restaurant name and rating
        let hash = recommendation.name.hashValue
        let baseCount: Int
        
        switch recommendation.rating {
        case 4.5...5.0:
            baseCount = 200 + (abs(hash) % 1800) // 200-2000
        case 4.0..<4.5:
            baseCount = 100 + (abs(hash) % 1400) // 100-1500
        case 3.5..<4.0:
            baseCount = 50 + (abs(hash) % 750) // 50-800
        case 3.0..<3.5:
            baseCount = 20 + (abs(hash) % 380) // 20-400
        default:
            baseCount = 10 + (abs(hash) % 190) // 10-200
        }
        
        // Format with K for thousands
        if baseCount >= 1000 {
            return "\(baseCount / 1000)K+"
        } else {
            return "\(baseCount)+"
        }
    }
}

struct CompactRestaurantCardView: View {
    let recommendation: RestaurantRecommendation
    let dateType: DateType?
    let matchNumber: Int
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image section
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 180)
                    .overlay(
                        Group {
                            if let imageURL = recommendation.imageURL, !imageURL.isEmpty {
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 180)
                                        .clipped()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 180)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                Text("Loading...")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                        )
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 180)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "fork.knife")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                            Text("No Image")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                        }
                    )
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.1),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Match number badge
                VStack {
                    HStack {
                        Text("Match #\(matchNumber)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.seaweedGreen)
                            )
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.leading, 12)
                    
                    Spacer()
                }
                
                // Restaurant info overlay
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recommendation.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                // Rating
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(recommendation.rating) ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                // Price level
                                Text(formatPriceLevel(recommendation.priceLevel))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                    )
                            }
                        }
                        
                        Spacer()
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            
            // Details section
            VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(recommendation.whyRecommended)
                        .font(.system(size: 12))
                        .foregroundColor(.seaweedGreen)
                        .italic()
                    
                    Spacer()
                    
                    Text(recommendation.estimatedCost)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.seaweedGreen)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.seaweedGreen.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    private func formatPriceLevel(_ priceLevel: String) -> String {
        let level = priceLevel.lowercased()
        
        switch level {
        case "low", "budget", "cheap":
            return "$"
        case "medium", "moderate", "mid":
            return "$$"
        case "high", "expensive", "upscale":
            return "$$$"
        case "very high", "luxury", "fine dining":
            return "$$$$"
        default:
            if level.contains("$") {
                return level.uppercased()
            } else if let range = level.range(of: #"\d+"#, options: .regularExpression) {
                let number = String(level[range])
                if let num = Int(number) {
                    return String(repeating: "$", count: min(num, 4))
                }
            }
            return "$$"
        }
    }
}

#Preview {
    RestaurantResultsView(
        dateType: .meal,
        mealTimes: [.dinner],
        priceRange: .medium,
        date: Date(),
        cuisines: [.italian]
    )
}