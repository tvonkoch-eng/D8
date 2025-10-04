//
//  ExploreView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI
import CoreLocation

struct ExploreView: View {
    @StateObject private var exploreService = ExploreService.shared
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if exploreService.isLoading {
                loadingView
            } else if exploreService.showLocationPermissionDenied {
                locationPermissionDeniedView
            } else if let errorMessage = exploreService.errorMessage {
                errorView(errorMessage)
            } else if exploreService.ideas.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear {
            // Only load if we don't have ideas already
            if exploreService.ideas.isEmpty {
                loadExploreIdeas()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                // Animated loading icon
                ZStack {
                    Circle()
                        .stroke(Color.seaweedGreen.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.seaweedGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(exploreService.isLoading ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: exploreService.isLoading)
                }
                
                VStack(spacing: 8) {
                    Text("Discovering your area...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(exploreService.locationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Location Permission Denied View
    private var locationPermissionDeniedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "location.slash")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Location Access Required")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("We need your location to suggest personalized date ideas in your area. Please enable location access in Settings to continue.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Try Again") {
                        exploreService.clearCache()
                        loadExploreIdeas()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "location.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Oops!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                exploreService.refreshExploreIdeas { result in
                    // Service handles updating its own properties
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No ideas found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("We couldn't find any ideas for your location. Please try again later.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Refresh") {
                exploreService.refreshExploreIdeas { result in
                    // Service handles updating its own properties
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enhanced Header Section
                VStack(spacing: 16) {
                    // Main title with decorative elements
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Explore")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.seaweedGreen)
                                
                                Text("Curated for \(exploreService.locationName)")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    
                    // Decorative line
                    Rectangle()
                        .fill(Color.seaweedGreen.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(.systemBackground).opacity(0.8))
                        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                )
                
                // Separate categories
                VStack(spacing: 32) {
                    // Restaurants Section
                    if !restaurantIdeas.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Restaurants")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(restaurantIdeas.count) places to dine")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(restaurantIdeas) { idea in
                                        ExploreIdeaCard(idea: idea, isHorizontal: true)
                                            .frame(width: 320)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .padding(.trailing, 20)
                            }
                        }
                    }
                    
                    // Activities Section
                    if !activityIdeas.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Activities")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(activityIdeas.count) things to do")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(activityIdeas) { idea in
                                        ExploreIdeaCard(idea: idea, isHorizontal: true)
                                            .frame(width: 320)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .padding(.trailing, 20)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var restaurantIdeas: [ExploreIdea] {
        exploreService.ideas.filter { $0.category == "restaurant" }
    }
    
    private var activityIdeas: [ExploreIdea] {
        exploreService.ideas.filter { $0.category == "activity" }
    }
    
    // MARK: - Methods
    private func loadExploreIdeas() {
        exploreService.getExploreIdeas { result in
            // The service now handles updating its own published properties
            // No need to manually update state here
        }
    }
}

// MARK: - Explore Idea Card
struct ExploreIdeaCard: View {
    let idea: ExploreIdea
    let isHorizontal: Bool
    @State private var isPressed = false
    @State private var showSchedulingView = false
    @State private var userLocation: CLLocation?
    @State private var distance: Double?
    
    init(idea: ExploreIdea, isHorizontal: Bool = false) {
        self.idea = idea
        self.isHorizontal = isHorizontal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isHorizontal ? 16 : 16) {
            
            // Restaurant/Activity Image
            if !idea.imageURL.isEmpty {
                AsyncImage(url: URL(string: idea.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .frame(height: isHorizontal ? 120 : 150)
                .clipped()
                .cornerRadius(12)
            } else {
                // Placeholder when no image
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: isHorizontal ? 120 : 150)
                    .cornerRadius(12)
                    .overlay(
                        VStack {
                            Image(systemName: idea.category == "restaurant" ? "fork.knife" : "figure.run")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                            Text("No Image")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: isHorizontal ? 8 : 8) {
                Text(idea.name)
                    .font(isHorizontal ? .title3 : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(isHorizontal ? 2 : 2)
                
                Text(idea.description)
                    .font(isHorizontal ? .body : .body)
                    .foregroundColor(.secondary)
                    .lineLimit(isHorizontal ? 3 : 3)
            }
            
            // Location - Full width button
            Button(action: {
                openInAppleMaps()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.address)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if let distance = distance {
                            Text(formatDistance(distance))
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    Text("open")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Tags and Links Menu
            HStack(spacing: 8) {
                if let cuisineType = idea.cuisineType {
                    TagView(text: formatCuisineType(cuisineType), color: .seaweedGreen)
                }
                
                if let activityType = idea.activityType {
                    TagView(text: activityType, color: .seaweedGreen)
                }
                
                TagView(text: formatPriceLevel(idea.priceLevel), color: .seaweedGreen)
                
                if let duration = idea.duration {
                    TagView(text: duration, color: .seaweedGreen)
                }
                
                Spacer()
                
                Spacer()
            }
            
            // Rating with review count
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(idea.rating) ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                Text(String(format: "%.1f", idea.rating))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("(\(generateReviewCount()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Handle like
                    print("Liked: \(idea.name)")
                }) {
                    Image(systemName: "heart")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.1))
                        )
                }
                
                Button(action: {
                    // Handle dislike
                    print("Disliked: \(idea.name)")
                }) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                
                Spacer()
                
                // Select button with Links overlay
                Button(action: {
                    showSchedulingView = true
                }) {
                    Text("Select")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.seaweedGreenGradient)
                        )
                }
                .overlay(
                    // Links Menu Button - Grey menucard overlay
                    Group {
                        if idea.websiteURL != nil || idea.menuURL != nil {
                            Menu {
                                if let websiteURL = idea.websiteURL, let url = URL(string: websiteURL) {
                                    Button(action: {
                                        UIApplication.shared.open(url)
                                    }) {
                                        Label("Restaurant Website", systemImage: "safari")
                                    }
                                }
                                
                                if let menuURL = idea.menuURL, let url = URL(string: menuURL) {
                                    Button(action: {
                                        UIApplication.shared.open(url)
                                    }) {
                                        Label("View Menu", systemImage: "doc.text")
                                    }
                                }
                            } label: {
                                Image(systemName: "menucard")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.black)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color.seaweedGreen.opacity(0.1))
                                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            .offset(x: -6, y: -50)// Offset to the right and up
                        }
                    },
                    alignment: .topTrailing
                )
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
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
        .sheet(isPresented: $showSchedulingView) {
            EventSchedulingView(idea: idea)
        }
        .onAppear {
            calculateDistance()
        }
    }
    
    private func openInAppleMaps() {
        // Use restaurant name for searching instead of exact address
        let searchQuery = idea.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
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
        let ideaLocation = CLLocation(
            latitude: idea.latitude,
            longitude: idea.longitude
        )
        
        let distanceInMeters = userLocation.distance(from: ideaLocation)
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
        let hash = idea.name.hashValue
        let baseCount: Int
        
        switch idea.rating {
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

// MARK: - Category Badge
struct CategoryBadge: View {
    let category: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category == "restaurant" ? "fork.knife" : "figure.run")
                .font(.caption)
            Text(category.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(category == "restaurant" ? Color.blue : Color.purple)
        )
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
    }
}

// MARK: - Helper Functions
extension ExploreIdeaCard {
    // Emoji placeholders removed for cleaner UI
}

#Preview {
    ExploreView()
}
