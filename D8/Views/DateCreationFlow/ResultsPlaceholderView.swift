//
//  ResultsPlaceholderView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI
import CoreLocation

struct ResultsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @StateObject private var osmService = OpenStreetMapService.shared
    @StateObject private var backendService = BackendService.shared
    
    let dateType: DateType?
    let mealTimes: Set<MealTime>
    let priceRange: PriceRange?
    let date: Date
    let cuisines: Set<Cuisine>
    let activityTypes: Set<ActivityType>?
    let activityIntensity: ActivityIntensity?
    
    @State private var recommendations: [DateRecommendation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingLocationDenied = false
    @State private var useBackend = true // Always use backend
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Date Recommendations")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // AI Badge
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("AI")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .cornerRadius(12)
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Preference Capsules
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Date Type
                    if let dateType = dateType {
                        PreferenceCapsule(
                            title: "Type",
                            value: dateType.displayName,
                            icon: dateType.icon
                        )
                    }
                    
                    // Meal Times
                    ForEach(Array(mealTimes), id: \.self) { mealTime in
                        PreferenceCapsule(
                            title: "Meal",
                            value: mealTime.displayName,
                            icon: mealTime.icon
                        )
                    }
                    
                    // Price Range
                    if let priceRange = priceRange {
                        PreferenceCapsule(
                            title: "Budget",
                            value: priceRange.displayName,
                            icon: priceRange.icon
                        )
                    }
                    
                    // Date
                    PreferenceCapsule(
                        title: "Date",
                        value: DateFormatter.shortDate.string(from: date),
                        icon: "calendar"
                    )
                    
                    // Cuisines
                    ForEach(Array(cuisines), id: \.self) { cuisine in
                        PreferenceCapsule(
                            title: "Cuisine",
                            value: cuisine.displayName,
                            icon: cuisine.emoji
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 10)
            
            // Results Content
            if isLoading {
                VStack(spacing: 20) {
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Finding perfect date spots...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Oops! Something went wrong")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 12) {
                        Button("Try Again") {
                            searchForRecommendations()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                 UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
            } else if recommendations.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No recommendations found")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Try adjusting your search radius or preferences")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
            } else {
                // Results List
                VStack(spacing: 0) {
                    // Results Header
                    HStack {
                        Text("\(recommendations.count) recommendations found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    // Recommendations List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(recommendations) { recommendation in
                                RecommendationCard(
                                    recommendation: recommendation,
                                    onTap: {
                                        // Handle recommendation tap
                                        print("Tapped: \(recommendation.title)")
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            searchForRecommendations()
        }
        // Removed onChange for useBackend since it's always true now
        .sheet(isPresented: $showingLocationDenied) {
            LocationPermissionDeniedView()
        }
    }
    
    // MARK: - Private Methods
    private func searchForRecommendations() {
        isLoading = true
        errorMessage = nil
        
        // Check if we have location permission
        if locationManager.checkCurrentPermissionStatus() {
            getLocationAndSearch()
        } else {
            // No permission, show error with instructions
            errorMessage = "Location access is required to find recommendations. Please enable location access in Settings and set it to 'While Using App'."
            isLoading = false
            showingLocationDenied = true
        }
    }
    
    private func getLocationAndSearch() {
        print("Getting current location...")
        locationManager.getCurrentLocation { coordinate in
            if let coordinate = coordinate {
                print("Location received: \(coordinate.latitude), \(coordinate.longitude)")
                // Always use backend for AI-powered recommendations
                self.searchWithBackend(near: coordinate)
            } else {
                print("Failed to get location")
                self.errorMessage = "Unable to get your current location. Please try again."
                self.isLoading = false
            }
        }
    }
    
    private func searchWithBackend(near coordinate: CLLocationCoordinate2D) {
        // Get location name for the backend
        let locationName = "Current Location" // You could reverse geocode this for a better name
        
        backendService.getDateRecommendations(
            location: locationName,
            dateType: dateType ?? .meal,
            mealTimes: dateType == .meal ? mealTimes : nil,
            priceRange: priceRange,
            cuisines: dateType == .meal ? cuisines : nil,
            activityTypes: dateType == .activity ? activityTypes : nil,
            activityIntensity: dateType == .activity ? activityIntensity : nil,
            date: date,
            coordinate: coordinate
        ) { result in
            switch result {
            case .success(let backendRecommendations):
                // Convert backend recommendations to DateRecommendation objects
                let newRecommendations = backendRecommendations.map { backendRec in
                    let osmPlace = backendRec.toOSMPlace()
                    return DateRecommendation(
                        place: osmPlace,
                        dateType: self.dateType ?? .meal,
                        mealTime: self.dateType == .meal ? self.mealTimes.first : nil,
                        priceRange: self.priceRange,
                        cuisines: self.dateType == .meal ? self.cuisines : [],
                        activityTypes: self.dateType == .activity ? self.activityTypes : nil,
                        activityIntensity: self.dateType == .activity ? self.activityIntensity : nil,
                        distance: self.calculateDistance(from: coordinate, to: osmPlace.coordinate),
                        matchScore: backendRec.matchScore
                    )
                }
                
                // Sort by match score and distance
                self.recommendations = newRecommendations.sorted { first, second in
                    if first.matchScore != second.matchScore {
                        return first.matchScore > second.matchScore
                    }
                    return (first.distance ?? Double.infinity) < (second.distance ?? Double.infinity)
                }
                
                self.isLoading = false
                
            case .failure(let error):
                print("Backend error: \(error)")
                self.errorMessage = "Unable to get AI recommendations. Please check your connection and try again."
                self.isLoading = false
            }
        }
    }
    
    private func searchRestaurants(near coordinate: CLLocationCoordinate2D) {
        // Use a 20-mile radius (32km) for better results
        let searchRadius = 32000
        
        // Get cuisine filter - use first cuisine if multiple selected, or nil if none
        let cuisineFilter = cuisines.isEmpty ? nil : cuisines.first.flatMap { osmService.mapCuisineToOSM($0) }
        
        osmService.searchRestaurants(
            near: coordinate,
            radius: searchRadius,
            cuisine: cuisineFilter
        ) { places in
            // Convert places to recommendations
            let newRecommendations = places.map { place in
                DateRecommendation(
                    place: place,
                    dateType: self.dateType ?? .meal,
                    mealTime: self.dateType == .meal ? self.mealTimes.first : nil,
                    priceRange: self.priceRange,
                    cuisines: self.dateType == .meal ? self.cuisines : [],
                    activityTypes: self.dateType == .activity ? self.activityTypes : nil,
                    activityIntensity: self.dateType == .activity ? self.activityIntensity : nil,
                    distance: self.calculateDistance(from: coordinate, to: place.coordinate),
                    matchScore: self.calculateMatchScore(for: place)
                )
            }
            
            // Sort by match score and distance, then limit to 20 results
            self.recommendations = newRecommendations.sorted { first, second in
                if first.matchScore != second.matchScore {
                    return first.matchScore > second.matchScore
                }
                return (first.distance ?? Double.infinity) < (second.distance ?? Double.infinity)
            }.prefix(20).map { $0 }
            
            self.isLoading = false
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func calculateMatchScore(for place: OSMPlace) -> Double {
        var score = 0.5 // Base score
        
        // Cuisine match - check if any selected cuisine matches
        if !cuisines.isEmpty, let placeCuisine = place.cuisine?.lowercased() {
            let hasCuisineMatch = cuisines.contains { selectedCuisine in
                guard let mappedCuisine = osmService.mapCuisineToOSM(selectedCuisine) else { return false }
                return mappedCuisine.lowercased() == placeCuisine
            }
            
            if hasCuisineMatch {
                score += 0.3
            } else {
                // Slight penalty for cuisine mismatch when cuisines are selected
                score -= 0.1
            }
        }
        
        // Price range match
        if let priceRange = priceRange,
           let osmPriceLevel = osmService.mapPriceRangeToOSM(priceRange) {
            if place.priceLevel == osmPriceLevel {
                score += 0.2
            } else {
                // Slight penalty for price mismatch
                score -= 0.05
            }
        }
        
        // Meal time match (bonus for appropriate meal times)
        if !mealTimes.isEmpty {
            let placeAmenity = place.amenity?.lowercased() ?? ""
            let hasMealTimeMatch = mealTimes.contains { mealTime in
                switch mealTime {
                case .breakfast:
                    return placeAmenity == "cafe" || placeAmenity == "restaurant"
                case .lunch:
                    return placeAmenity == "restaurant" || placeAmenity == "fast_food" || placeAmenity == "cafe"
                case .dinner:
                    return placeAmenity == "restaurant" || placeAmenity == "bar"
                case .notSure:
                    return true
                }
            }
            
            if hasMealTimeMatch {
                score += 0.1
            }
        }
        
        return max(0.0, min(score, 1.0)) // Ensure score is between 0 and 1
    }
    
}

struct RecommendationCard: View {
    let recommendation: DateRecommendation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon, name, and match score
                HStack(alignment: .top, spacing: 12) {
                    Text(recommendation.icon)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(recommendation.place.cuisineDisplayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(recommendation.matchScore * 100))% match")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                        
                        if let distance = recommendation.distance {
                            Text(formatDistance(distance))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Address and contact info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(recommendation.place.formattedAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if recommendation.place.phone != "Phone not available" {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(recommendation.place.formattedPhone)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if recommendation.place.website != "Website not available" {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("Website available")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Price, rating, and hours
                HStack(spacing: 16) {
                    // Price level
                    Text(recommendation.place.priceLevelDisplay)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    
                    // Rating
                    if let rating = recommendation.place.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Hours
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                        if let hours = recommendation.place.openingHours, !hours.isEmpty && hours != "Hours not available" {
                            Text(hours)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Hours unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Amenities
                if !recommendation.place.amenitiesList.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recommendation.place.amenitiesList, id: \.self) { amenity in
                                Text(amenity)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            return String(format: "%.1fkm away", distance / 1000)
        }
    }
}



#Preview {
    ResultsPlaceholderView(
        dateType: .meal,
        mealTimes: [.dinner],
        priceRange: .medium,
        date: Date(),
        cuisines: [.italian],
        activityTypes: nil,
        activityIntensity: nil
    )
}
