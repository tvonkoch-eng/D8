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
    let activityTypes: Set<ActivityType>?
    let activityIntensity: ActivityIntensity?
    
    @StateObject private var restaurantService = RestaurantService.shared
    @State private var recommendations: [RestaurantRecommendation] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var locationManager = LocationManager()
    @State private var progressText = "Initializing search..."
    @State private var progressValue: Double = 0.0
    @State private var currentPage = 1
    @State private var hasMoreResults = true
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
                        
                        // Loading spinner
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                    
                    Spacer()
                }
                .padding()
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Oops! Something went wrong")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        loadRecommendations()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if recommendations.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No \(dateType == .activity ? "activities" : "restaurants") found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("We couldn't find any \(dateType == .activity ? "activities" : "restaurants") matching your criteria. Try adjusting your preferences or location.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        loadRecommendations()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    // Header with exit button
                    HStack {
                        Text("\(recommendations.count) \(dateType == .activity ? "activities" : "restaurants") found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
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
                    .padding(.vertical, 16)
                    
                    // Results list
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(recommendations) { recommendation in
                                    RestaurantCardView(recommendation: recommendation, dateType: dateType)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        
                        // Load More button - outside ScrollView so it's always visible
                        if hasMoreResults && !isLoadingMore {
                            Button(action: {
                                loadMoreRecommendations()
                            }) {
                                HStack {
                                    Text("Load More")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        } else if isLoadingMore {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more restaurants...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
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
        currentPage = 1
        hasMoreResults = true
        progressValue = 0.0
        progressText = "Initializing search..."
        
        // Start smooth 15-second progress animation
        startProgressAnimation()
        
        // Get current location
        locationManager.getCurrentLocation { coordinate in
            let locationString = "Current Location"
            
            restaurantService.getRestaurantRecommendations(
                dateType: self.dateType ?? .meal,
                mealTimes: self.dateType == .meal ? self.mealTimes : nil,
                priceRange: self.priceRange,
                cuisines: self.dateType == .meal ? self.cuisines : nil,
                activityTypes: self.dateType == .activity ? self.activityTypes : nil,
                activityIntensity: self.dateType == .activity ? self.activityIntensity : nil,
                date: self.date,
                location: locationString,
                coordinate: coordinate
            ) { result in
                // Complete the progress when API call finishes
                DispatchQueue.main.async {
                    switch result {
                    case .success(let recs):
                        self.updateProgress(text: "Complete!", value: 1.0)
                        self.recommendations = recs
                        // Set hasMoreResults based on whether we got a full page of results
                        self.hasMoreResults = recs.count >= 10
                        print("✅ Loaded \(recs.count) recommendations, hasMoreResults: \(self.hasMoreResults)")
                        print("✅ Load more button should be visible: \(self.hasMoreResults && !self.isLoadingMore)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            self.isLoading = false
                        }
                    case .failure(let error):
                        // Provide more specific error messages
                        if let urlError = error as? URLError {
                            switch urlError.code {
                            case .notConnectedToInternet, .networkConnectionLost:
                                self.errorMessage = "No internet connection. Please check your network and try again."
                            case .timedOut:
                                self.errorMessage = "Request timed out. Please try again."
                            case .cannotConnectToHost, .cannotFindHost:
                                self.errorMessage = "Cannot connect to server. Please try again later."
                            default:
                                self.errorMessage = "Network error: \(error.localizedDescription)"
                            }
                        } else {
                            self.errorMessage = error.localizedDescription
                        }
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func startProgressAnimation() {
        // 15-second smooth progress animation
        let totalDuration: TimeInterval = 15.0
        let steps = [
            (text: "Getting your location...", value: 0.1, delay: 0.5),
            (text: dateType == .activity ? "Searching for activities..." : "Searching for restaurants...", value: 0.25, delay: 2.0),
            (text: "Analyzing preferences...", value: 0.4, delay: 3.5),
            (text: "Finding perfect matches...", value: 0.55, delay: 5.0),
            (text: "Checking availability...", value: 0.7, delay: 6.5),
            (text: dateType == .activity ? "Processing activity recommendations..." : "Processing results...", value: 0.8, delay: 8.0),
            (text: "Optimizing suggestions...", value: 0.9, delay: 10.0),
            (text: dateType == .activity ? "Finalizing activity suggestions..." : "Finalizing recommendations...", value: 0.95, delay: 12.0)
        ]
        
        // Set up step-based progress updates
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                if self.isLoading { // Only update if still loading
                    self.updateProgress(text: step.text, value: step.value)
                }
            }
        }
        
        // Smooth continuous progress that only increases
        let animationSteps = 100
        let stepDuration = totalDuration / Double(animationSteps)
        
        for i in 1...animationSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                if self.isLoading {
                    let newProgress = Double(i) / Double(animationSteps) * 0.95 // Cap at 95% until API completes
                    // Only update if the new progress is greater than current progress
                    if newProgress > self.progressValue {
                        self.progressValue = newProgress
                    }
                }
            }
        }
    }
    
    private func loadMoreRecommendations() {
        guard !isLoadingMore && hasMoreResults else { 
            print("❌ Load more blocked - isLoadingMore: \(isLoadingMore), hasMoreResults: \(hasMoreResults)")
            return 
        }
        
        print("🔄 Loading more recommendations, page: \(currentPage + 1)")
        isLoadingMore = true
        currentPage += 1
        
        // Get current location
        locationManager.getCurrentLocation { coordinate in
            let locationString = "Current Location"
            
            restaurantService.getRestaurantRecommendations(
                dateType: dateType ?? .meal,
                mealTimes: dateType == .meal ? mealTimes : nil,
                priceRange: priceRange,
                cuisines: dateType == .meal ? cuisines : nil,
                activityTypes: dateType == .activity ? activityTypes : nil,
                activityIntensity: dateType == .activity ? activityIntensity : nil,
                date: date,
                location: locationString,
                coordinate: coordinate,
                page: currentPage
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let newRecs):
                        recommendations.append(contentsOf: newRecs)
                        hasMoreResults = newRecs.count >= 10
                        print("Loaded \(newRecs.count) more recommendations, total: \(recommendations.count), hasMoreResults: \(hasMoreResults)")
                        isLoadingMore = false
                    case .failure(let error):
                        print("Error loading more: \(error)")
                        // Don't show error for load more, just stop trying
                        hasMoreResults = false
                        isLoadingMore = false
                    }
                }
            }
        }
    }
    
    private func updateProgress(text: String, value: Double) {
        DispatchQueue.main.async {
            progressText = text
            // Only update progress if the new value is greater than current value
            if value > progressValue {
                progressValue = value
            }
        }
    }
}

struct RestaurantCardView: View {
    let recommendation: RestaurantRecommendation
    let dateType: DateType?
    @State private var userLocation: CLLocation?
    @State private var distance: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and location
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(recommendation.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Location with map pin (clickable)
                Button(action: {
                    openInAppleMaps()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Text(recommendation.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Description
            Text(recommendation.description)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            // Activity attributes (pills)
            HStack(spacing: 8) {
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text(activityDuration)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
                
                // Intensity
                HStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text(activityIntensity)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                )
                
                // Vibe
                HStack(spacing: 4) {
                    Text(activityVibeIcon)
                        .font(.system(size: 12))
                    Text(activityVibe)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.1))
                )
                
                Spacer()
            }
            
            // Rating and Price on same line
            HStack {
                // Rating display
                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(recommendation.rating) ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text("\(String(format: "%.1f", recommendation.rating)) (\(Int.random(in: 100...5000)))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Price display
                Text(simplifiedPrice)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.seaweedGreenGradient)
                    )
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Feedback buttons
                HStack(spacing: 8) {
                    Button(action: {
                        // Handle thumbs down
                        print("Thumbs down: \(recommendation.name)")
                    }) {
                        Image(systemName: "hand.thumbsdown")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    
                    Button(action: {
                        // Handle thumbs up
                        print("Thumbs up: \(recommendation.name)")
                    }) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                            )
                    }
                }
                
                Spacer()
                
                // Select button
                Button(action: {
                    // Handle selection
                    print("Selected: \(recommendation.name)")
                }) {
                    Text("Select")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.seaweedGreenGradient)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.seaweedGreen.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            calculateDistance()
        }
    }
    
    // MARK: - Location Methods
    private func calculateDistance() {
        guard let userLocation = userLocation else {
            // Get user location if not available
            LocationManager().getCurrentLocation { coordinate in
                guard let coordinate = coordinate else {
                    print("Failed to get user location")
                    return
                }
                self.userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                self.calculateDistance()
            }
            return
        }
        
        let restaurantLocation = CLLocation(
            latitude: recommendation.latitude,
            longitude: recommendation.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: restaurantLocation)
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert meters to miles
        self.distance = distanceInMiles
    }
    
    private func openInAppleMaps() {
        let encodedAddress = recommendation.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mapsURL = "https://maps.apple.com/?q=\(encodedAddress)"
        
        if let url = URL(string: mapsURL) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Computed Properties
    private var simplifiedPrice: String {
        let cost = recommendation.estimatedCost.lowercased()
        
        // Check if it's free
        if cost.contains("free") {
            return "Free"
        }
        
        // Extract price range and calculate average
        if let range = extractPriceRange(from: cost) {
            let average = (range.min + range.max) / 2
            let rounded = Int(ceil(average / 5.0) * 5.0) // Round up to nearest $5
            return "$\(rounded)"
        }
        
        // Fallback to original if we can't parse
        return recommendation.estimatedCost
    }
    
    private func extractPriceRange(from cost: String) -> (min: Double, max: Double)? {
        // Look for patterns like "$9.95 - $29.95" or "$15-$25"
        let pattern = #"\$?(\d+(?:\.\d+)?)\s*-\s*\$?(\d+(?:\.\d+)?)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: cost.utf16.count)
            if let match = regex.firstMatch(in: cost, options: [], range: range) {
                if let minRange = Range(match.range(at: 1), in: cost),
                   let maxRange = Range(match.range(at: 2), in: cost),
                   let min = Double(String(cost[minRange])),
                   let max = Double(String(cost[maxRange])) {
                    return (min: min, max: max)
                }
            }
        }
        
        // Look for single price like "$15" or "15"
        let singlePattern = #"\$?(\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: singlePattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: cost.utf16.count)
            if let match = regex.firstMatch(in: cost, options: [], range: range) {
                if let priceRange = Range(match.range(at: 1), in: cost),
                   let price = Double(String(cost[priceRange])) {
                    return (min: price, max: price)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Activity-specific computed properties
    private var activityDuration: String {
        // Extract duration from description or estimate based on activity type
        let name = recommendation.name.lowercased()
        if name.contains("hiking") || name.contains("walk") {
            return "2-3 hours"
        } else if name.contains("biking") || name.contains("bike") {
            return "1-2 hours"
        } else if name.contains("garden") || name.contains("museum") {
            return "1-2 hours"
        } else if name.contains("picnic") {
            return "2-4 hours"
        } else if name.contains("zoo") || name.contains("aquarium") {
            return "1-3 hours"
        } else {
            return "1-3 hours"
        }
    }
    
    private var activityIntensity: String {
        // Extract intensity from description or estimate based on activity type
        let name = recommendation.name.lowercased()
        let description = recommendation.description.lowercased()
        
        if name.contains("hiking") || description.contains("strenuous") || description.contains("challenging") {
            return "High"
        } else if name.contains("biking") || name.contains("fitness") || description.contains("moderate") {
            return "Medium"
        } else if name.contains("garden") || name.contains("picnic") || name.contains("stroll") || name.contains("zoo") {
            return "Low"
        } else {
            return "Medium"
        }
    }
    
    private var activityVibe: String {
        // Determine the vibe/atmosphere of the activity
        let name = recommendation.name.lowercased()
        let description = recommendation.description.lowercased()
        
        if name.contains("picnic") || name.contains("garden") || description.contains("romantic") || description.contains("intimate") {
            return "Romantic"
        } else if name.contains("hiking") || name.contains("biking") || description.contains("adventure") || description.contains("outdoor") {
            return "Adventure"
        } else if name.contains("museum") || description.contains("cultural") || description.contains("educational") {
            return "Cultural"
        } else if name.contains("zoo") || name.contains("aquarium") || description.contains("fun") || description.contains("playful") || description.contains("games") {
            return "Fun"
        } else {
            return "Casual"
        }
    }
    
    private var activityVibeIcon: String {
        switch activityVibe {
        case "Romantic": return "💕"
        case "Adventure": return "🏔️"
        case "Cultural": return "🎨"
        case "Fun": return "🎭"
        default: return "😊"
        }
    }
}
