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
    @State private var isAnimating = false
    @State private var selectedRestaurant: ExploreIdea?
    
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
        .onChange(of: exploreService.isLoading) { isLoading in
            if isLoading {
                isAnimating = true
            } else {
                // Keep animation running for a bit longer for smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAnimating = false
                }
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
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
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
                loadExploreIdeas()
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
                loadExploreIdeas()
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
                                    .font(.caption)
                                    .foregroundColor(.seaweedGreen)
                                
                                Text("Curated for \(exploreService.locationName)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
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
                
                // Mixed ideas list - vertical scroll
                VStack(spacing: 20) {
                    ForEach(Array(exploreService.ideas.enumerated()), id: \.element.id) { index, idea in
                        NavigationLink(destination: RestaurantDetailView(restaurant: idea)) {
                            ExploreIdeaCard(idea: idea, isHorizontal: false, index: index)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    private func loadExploreIdeas() {
        // Clear any existing error state
        exploreService.errorMessage = nil
        exploreService.showLocationPermissionDenied = false
        
        exploreService.getExploreIdeas { result in
            // The service handles updating its own published properties
            // Additional handling can be added here if needed
        }
    }
}

// MARK: - Explore Idea Card
struct ExploreIdeaCard: View {
    let idea: ExploreIdea
    let isHorizontal: Bool
    let index: Int
    @State private var isPressed = false
    @State private var userLocation: CLLocation?
    @State private var distance: Double?
    
    init(idea: ExploreIdea, isHorizontal: Bool = false, index: Int = 0) {
        self.idea = idea
        self.isHorizontal = isHorizontal
        self.index = index
    }
    
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
                        if let imageURL = idea.imageURL, !imageURL.isEmpty {
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
                                        Image(systemName: idea.category == "restaurant" ? "fork.knife" : "figure.run")
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
            
            // Popularity tag (top right)
            VStack {
                HStack {
                    Spacer()
                    popularityTag
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
                
                Spacer()
            }
            
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
    
    // MARK: - Popularity Tag
    private var popularityTag: some View {
        Group {
            if index == 0 {
                // First restaurant gets "Most Popular" tag
                Text("Most Popular")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.red)
                            .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
            } else if index == 1 {
                // Second restaurant gets "Recommended" tag
                Text("Recommended")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
            }
        }
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
                if let websiteURL = idea.websiteURL, let url = URL(string: websiteURL) {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Label("Visit Website", systemImage: "safari")
                    }
                }
                
                // Menu link
                if let menuURL = idea.menuURL, let url = URL(string: menuURL) {
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
                    Text(idea.name)
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
            
            Spacer()
        }
    }
    
    // MARK: - Rating View
    private var ratingView: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Image(systemName: index < Int(idea.rating) ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            Text(String(format: "%.1f", idea.rating))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Price Level View
    private var priceLevelView: some View {
        Text(formatPriceLevel(idea.priceLevel))
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
        Text(idea.address)
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(1)
            .truncationMode(.tail)
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

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ExploreView()
}
