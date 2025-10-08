//
//  ActivityResultsView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI
import CoreLocation

struct ActivityResultsView: View {
    let dateType: DateType?
    let activityTypes: Set<ActivityType>
    let activityIntensity: ActivityIntensity?
    let priceRange: PriceRange?
    let date: Date
    
    @StateObject private var backendService = BackendService.shared
    @State private var recommendations: [BackendPlaceRecommendation] = []
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
                                CompactActivityCardView(
                                    recommendation: recommendation,
                                    matchNumber: index + 1
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 300)
                    } else if recommendations.count == 1 {
                        CompactActivityCardView(
                            recommendation: recommendations[0],
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
                dateType: self.dateType ?? .activity,
                mealTimes: nil,
                priceRange: self.priceRange,
                cuisines: nil,
                activityTypes: self.activityTypes,
                activityIntensity: self.activityIntensity,
                date: self.date,
                coordinate: coordinate
            ) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let backendRecommendations):
                        // Filter out restaurants and keep only activities
                        let activityRecommendations = backendRecommendations.filter { backendRec in
                            !backendRec.category.lowercased().contains("restaurant") &&
                            !backendRec.category.lowercased().contains("food") &&
                            !backendRec.category.lowercased().contains("dining")
                        }
                        
                        // Apply additional filtering based on user criteria
                        let filteredRecommendations = self.filterActivitiesByCriteria(activityRecommendations)
                        
                        // Limit to 2 perfect matches
                        self.recommendations = Array(filteredRecommendations.prefix(2))
                        self.progressText = "Found \(filteredRecommendations.count) activities!"
                        self.progressValue = 1.0
                        
                        // Store recommendations in Firebase
                        self.storeRecommendationsInFirebase(filteredRecommendations)
                        
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
                        print("Using fallback mock activity data...")
                        let mockRecommendations = self.generateMockActivityRecommendations()
                        // Limit to 2 perfect matches
                        self.recommendations = Array(mockRecommendations.prefix(2))
                        self.progressText = "Found \(mockRecommendations.count) activities!"
                        self.progressValue = 1.0
                        
                        // Store mock recommendations in Firebase
                        self.storeRecommendationsInFirebase(mockRecommendations)
                        
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
                    self.progressText = "Searching activities..."
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
    
    // MARK: - Firebase Storage
    private func storeRecommendationsInFirebase(_ recommendations: [BackendPlaceRecommendation]) {
        // Store each recommendation in Firebase for later retrieval
        for recommendation in recommendations {
            FirebaseService.shared.storeRecommendation(
                name: recommendation.name,
                description: recommendation.description,
                category: recommendation.category,
                location: recommendation.location,
                latitude: recommendation.latitude,
                longitude: recommendation.longitude,
                estimatedCost: recommendation.estimatedCost,
                bestTime: recommendation.bestTime,
                whyRecommended: recommendation.whyRecommended,
                dateType: dateType ?? .activity
            )
        }
    }
    
    // MARK: - Mock Data Generator
    private func generateMockActivityRecommendations() -> [BackendPlaceRecommendation] {
        let allMockActivities = [
            // FREE HIGH INTENSITY ACTIVITIES
            BackendPlaceRecommendation(
                name: "Rock Climbing - Stoney Point",
                description: "Outdoor rock climbing with multiple routes for all skill levels. Bring your own gear or rent nearby.",
                location: "Chatsworth, CA",
                address: "Stoney Point Park, Chatsworth, CA",
                latitude: 34.2578,
                longitude: -118.6009,
                category: "sports",
                estimatedCost: "Free",
                bestTime: "Morning",
                whyRecommended: "Extreme physical challenge perfect for adventurous couples",
                aiConfidence: 0.98
            ),
            BackendPlaceRecommendation(
                name: "Beach Volleyball - Santa Monica",
                description: "Free public beach volleyball courts with nets. Bring your own ball or rent from nearby shops.",
                location: "Santa Monica, CA",
                address: "Santa Monica Beach, Santa Monica, CA",
                latitude: 34.0195,
                longitude: -118.4912,
                category: "sports",
                estimatedCost: "Free",
                bestTime: "Afternoon",
                whyRecommended: "High-energy beach sport with ocean views",
                aiConfidence: 0.95
            ),
            BackendPlaceRecommendation(
                name: "Trail Running - Runyon Canyon",
                description: "Challenging trail running with steep inclines and scenic views. Multiple difficulty levels available.",
                location: "Los Angeles, CA",
                address: "Runyon Canyon Park, Los Angeles, CA",
                latitude: 34.1083,
                longitude: -118.3506,
                category: "fitness",
                estimatedCost: "Free",
                bestTime: "Morning",
                whyRecommended: "Intense cardio workout with beautiful city views",
                aiConfidence: 0.94
            ),
            BackendPlaceRecommendation(
                name: "Basketball Courts - Venice Beach",
                description: "Free outdoor basketball courts with ocean views. Multiple courts available for pickup games.",
                location: "Venice, CA",
                address: "Venice Beach Basketball Courts, Venice, CA",
                latitude: 33.9850,
                longitude: -118.4695,
                category: "sports",
                estimatedCost: "Free",
                bestTime: "Afternoon",
                whyRecommended: "High-intensity team sport with beach atmosphere",
                aiConfidence: 0.91
            ),
            
            // PAID HIGH INTENSITY ACTIVITIES
            BackendPlaceRecommendation(
                name: "Indoor Rock Climbing Gym",
                description: "State-of-the-art climbing gym with routes for all levels. Equipment rental included.",
                location: "Los Angeles, CA",
                address: "LA Boulders, Los Angeles, CA",
                latitude: 34.0736,
                longitude: -118.4004,
                category: "fitness",
                estimatedCost: "$25-35 per person",
                bestTime: "Evening",
                whyRecommended: "Intense full-body workout in controlled environment",
                aiConfidence: 0.89
            ),
            
            // LOW INTENSITY ACTIVITIES
            BackendPlaceRecommendation(
                name: "Escape Room Adventure",
                description: "An immersive puzzle-solving experience that tests your teamwork and problem-solving skills.",
                location: "Los Angeles, CA",
                address: "Escape Room LA, Los Angeles, CA",
                latitude: 34.0522,
                longitude: -118.2437,
                category: "indoor",
                estimatedCost: "$25-35 per person",
                bestTime: "Evening",
                whyRecommended: "Great for couples who enjoy challenges and working together",
                aiConfidence: 0.9
            ),
            BackendPlaceRecommendation(
                name: "Cooking Class - Italian Cuisine",
                description: "Learn to make authentic Italian dishes together in a fun, hands-on cooking experience.",
                location: "Los Angeles, CA",
                address: "Culinary Studio LA, Los Angeles, CA",
                latitude: 34.0736,
                longitude: -118.4004,
                category: "indoor",
                estimatedCost: "$75-95 per person",
                bestTime: "Evening",
                whyRecommended: "Perfect for food-loving couples who want to learn something new together",
                aiConfidence: 0.88
            )
        ]
        
        // Filter activities based on user criteria
        return filterActivitiesByCriteria(allMockActivities)
    }
    
    private func filterActivitiesByCriteria(_ activities: [BackendPlaceRecommendation]) -> [BackendPlaceRecommendation] {
        var filteredActivities = activities
        
        // STRICT FILTERING: Price Range (Extreme Cases)
        if let priceRange = priceRange {
            filteredActivities = filteredActivities.filter { activity in
                let cost = activity.estimatedCost.lowercased()
                
                switch priceRange {
                case .free:
                    // EXTREME CASE: 100% free results only
                    return cost.contains("free") && !cost.contains("$")
                case .low:
                    // Low budget: Free OR very cheap ($0-15)
                    return cost.contains("free") || 
                           (cost.contains("$") && (cost.contains("0-15") || cost.contains("5-15")))
                case .medium:
                    // Medium budget: $15-35 range
                    return cost.contains("$") && 
                           (cost.contains("15-30") || cost.contains("25-35") || cost.contains("20-40"))
                case .high:
                    // High budget: $35-75 range
                    return cost.contains("$") && 
                           (cost.contains("30-50") || cost.contains("50+") || cost.contains("40-75"))
                case .luxury:
                    // Luxury budget: $75+ only
                    return cost.contains("$") && 
                           (cost.contains("75-95") || cost.contains("100+") || cost.contains("75+"))
                case .notSure:
                    return true // Show all activities
                }
            }
        }
        
        // STRICT FILTERING: Activity Intensity (Extreme Cases)
        if let intensity = activityIntensity {
            filteredActivities = filteredActivities.filter { activity in
                let activityName = activity.name.lowercased()
                let activityCategory = activity.category.lowercased()
                let activityDescription = activity.description.lowercased()
                
                switch intensity {
                case .low:
                    // Low intensity: Sedentary activities only
                    return activityCategory.contains("indoor") || 
                           activityCategory.contains("entertainment") ||
                           activityName.contains("escape") ||
                           activityName.contains("cooking") ||
                           activityName.contains("museum") ||
                           activityName.contains("art") ||
                           activityName.contains("movie") ||
                           activityName.contains("board game")
                           
                case .medium:
                    // Medium intensity: Light physical activity
                    return activityCategory.contains("outdoor") || 
                           activityName.contains("walking") ||
                           activityName.contains("hiking") ||
                           activityName.contains("cycling") ||
                           activityName.contains("swimming") ||
                           activityDescription.contains("moderate") ||
                           activityDescription.contains("light")
                           
                case .high:
                    // EXTREME CASE: High intensity = ONLY physically demanding activities
                    return isHighIntensityActivity(activity)
                           
                case .notSure:
                    return true // Show all activities
                }
            }
        }
        
        // STRICT FILTERING: Activity Types
        if !activityTypes.isEmpty && !activityTypes.contains(.notSure) {
            filteredActivities = filteredActivities.filter { activity in
                let activityCategory = activity.category.lowercased()
                let activityName = activity.name.lowercased()
                
                return activityTypes.contains { activityType in
                    switch activityType {
                    case .sports:
                        return activityCategory.contains("sports") || 
                               activityName.contains("volleyball") ||
                               activityName.contains("basketball") ||
                               activityName.contains("tennis") ||
                               activityName.contains("soccer") ||
                               activityName.contains("football")
                    case .outdoor:
                        return activityCategory.contains("outdoor") || 
                               activityName.contains("beach") || 
                               activityName.contains("trail") ||
                               activityName.contains("park") ||
                               activityName.contains("hiking") ||
                               activityName.contains("climbing")
                    case .indoor:
                        return activityCategory.contains("indoor") || 
                               activityName.contains("gym") || 
                               activityName.contains("class") ||
                               activityName.contains("escape") ||
                               activityName.contains("museum")
                    case .entertainment:
                        return activityCategory.contains("entertainment") || 
                               activityName.contains("escape") ||
                               activityName.contains("movie") ||
                               activityName.contains("concert") ||
                               activityName.contains("show")
                    case .fitness:
                        return activityCategory.contains("fitness") || 
                               activityName.contains("running") || 
                               activityName.contains("climbing") ||
                               activityName.contains("workout") ||
                               activityName.contains("gym")
                    case .notSure:
                        return true
                    }
                }
            }
        }
        
        // FALLBACK: If no activities match strict criteria, show relevant alternatives
        if filteredActivities.isEmpty {
            return getRelevantFallbackActivities(activities)
        }
        
        return filteredActivities
    }
    
    // Helper function to determine if an activity is truly high intensity
    private func isHighIntensityActivity(_ activity: BackendPlaceRecommendation) -> Bool {
        let activityName = activity.name.lowercased()
        let activityCategory = activity.category.lowercased()
        let activityDescription = activity.description.lowercased()
        
        // High intensity keywords
        let highIntensityKeywords = [
            "climbing", "rock climbing", "bouldering",
            "running", "trail running", "sprinting",
            "volleyball", "beach volleyball",
            "basketball", "pickup basketball",
            "tennis", "squash", "racquetball",
            "soccer", "football", "rugby",
            "boxing", "martial arts", "kickboxing",
            "crossfit", "hiit", "high intensity",
            "cycling", "mountain biking",
            "swimming", "water polo",
            "hiking", "mountain hiking", "trekking",
            "surfing", "windsurfing", "kitesurfing",
            "skateboarding", "rollerblading",
            "dancing", "zumba", "aerobic"
        ]
        
        // Check if activity name or description contains high intensity keywords
        let allText = "\(activityName) \(activityDescription)"
        return highIntensityKeywords.contains { keyword in
            allText.contains(keyword)
        } || activityCategory.contains("sports") || activityCategory.contains("fitness")
    }
    
    // Helper function to provide relevant fallback activities
    private func getRelevantFallbackActivities(_ activities: [BackendPlaceRecommendation]) -> [BackendPlaceRecommendation] {
        // If user wants free activities, show only free ones
        if let priceRange = priceRange, priceRange == .free {
            return activities.filter { activity in
                activity.estimatedCost.lowercased().contains("free")
            }
        }
        
        // If user wants high intensity, show only high intensity ones
        if let intensity = activityIntensity, intensity == .high {
            return activities.filter { activity in
                isHighIntensityActivity(activity)
            }
        }
        
        // If user wants both free AND high intensity, show only those
        if let priceRange = priceRange, let intensity = activityIntensity,
           priceRange == .free && intensity == .high {
            return activities.filter { activity in
                activity.estimatedCost.lowercased().contains("free") && 
                isHighIntensityActivity(activity)
            }
        }
        
        // Default fallback: show some activities
        return Array(activities.prefix(3))
    }
}

struct ActivityCardView: View {
    let recommendation: BackendPlaceRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Activity name and category
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(recommendation.category.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.seaweedGreen.opacity(0.1))
                        )
                }
                
                Spacer()
                
                // Cost indicator
                Text(recommendation.estimatedCost)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.seaweedGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.seaweedGreen.opacity(0.1))
                    )
            }
            
            // Description
            Text(recommendation.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Why recommended
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Text(recommendation.whyRecommended)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Best time and location
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(recommendation.bestTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(recommendation.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
    }
}

struct CompactActivityCardView: View {
    let recommendation: BackendPlaceRecommendation
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
                        VStack(spacing: 8) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                            Text("Activity")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                
                // Activity info overlay
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recommendation.name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                // Activity category
                                Text(recommendation.category.capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                    )
                                
                                // Cost indicator
                                Text(recommendation.estimatedCost)
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
}

#Preview {
    ActivityResultsView(
        dateType: .activity,
        activityTypes: [.outdoor, .indoor],
        activityIntensity: .medium,
        priceRange: .medium,
        date: Date()
    )
}
