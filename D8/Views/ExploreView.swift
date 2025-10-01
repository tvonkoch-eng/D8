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
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.seaweedGreen.opacity(0.3),
                                    Color.seaweedGreen.opacity(0.1),
                                    Color.clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
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
                
                // Refresh button
                Button("Refresh Ideas") {
                    exploreService.refreshExploreIdeas { result in
                        // Service handles updating its own properties
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
    
    init(idea: ExploreIdea, isHorizontal: Bool = false) {
        self.idea = idea
        self.isHorizontal = isHorizontal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isHorizontal ? 16 : 16) {
            
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
            
            // Location
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.caption)
                    .foregroundColor(.red)
                Text(idea.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Tags
            HStack(spacing: 8) {
                if let cuisineType = idea.cuisineType {
                    TagView(text: cuisineType, color: .blue)
                }
                
                if let activityType = idea.activityType {
                    TagView(text: activityType, color: .purple)
                }
                
                TagView(text: idea.priceLevel.capitalized, color: .green)
                
                if let duration = idea.duration {
                    TagView(text: duration, color: .orange)
                }
                
                Spacer()
            }
            
            // Rating
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

#Preview {
    ExploreView()
}
