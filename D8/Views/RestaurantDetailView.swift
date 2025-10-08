//
//  RestaurantDetailView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI
import CoreLocation

struct RestaurantDetailView: View {
    let restaurant: ExploreIdea
    @StateObject private var restaurantService = RestaurantDetailService.shared
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if let details = restaurantService.restaurantDetails {
                contentView(details: details)
            } else {
                errorView("Failed to load restaurant details")
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadRestaurantDetails()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading restaurant details...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
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
            
            Button("Try Again") {
                loadRestaurantDetails()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Content View
    private func contentView(details: RestaurantDetails) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Image Section - Limited Height
                heroImageView
                
                // Content Section
                contentSection(details: details)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .overlay(alignment: .top) {
            // Navigation Overlay
            navigationOverlay
        }
    }
    
    // MARK: - Hero Image View
    private var heroImageView: some View {
        ZStack {
            // Background image container with fixed dimensions
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 300)
                .overlay(
                    Group {
                        if let imageURL = restaurant.imageURL, !imageURL.isEmpty {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: .infinity, height: 300)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 300)
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
                                .frame(height: 300)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text("No Image Available")
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
            
            // Restaurant Info Overlay
            VStack {
                Spacer()
                HStack {
                    restaurantInfoOverlay
                    Spacer()
                }
            }
        }
        .frame(height: 300)
        .clipped()
    }
    
    // MARK: - Restaurant Info Overlay
    private var restaurantInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Restaurant Name
            Text(restaurant.name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Rating and Info Row
            HStack(spacing: 16) {
                // Rating with improved styling
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(restaurant.rating) ? "star.fill" : "star")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(String(format: "%.1f", restaurant.rating))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Price Level with improved styling
                Text(formatPriceLevel(restaurant.priceLevel))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                
                // Cuisine Type with improved styling
                if let cuisineType = restaurant.cuisineType, !cuisineType.isEmpty {
                    Text(cuisineType)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    
    // MARK: - Navigation Overlay
    private var navigationOverlay: some View {
        VStack {
            HStack {
                // Back Button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                Spacer()
                
                // Done Button
                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // MARK: - Content Section
    private func contentSection(details: RestaurantDetails) -> some View {
        VStack(spacing: 0) {
            // Quick Actions Row
            quickActionsRow(details: details)
                .padding(.horizontal, 16)
                .padding(.top, 20)
            
            // Information Cards
            VStack(spacing: 16) {
                // About Section
                if !details.description.isEmpty {
                    modernAboutSection(details: details)
                }
                
                // Hours Section
                if !details.hours.isEmpty {
                    modernHoursSection(details: details)
                }
                
                // Additional Info Section
                if !details.additionalInfo.isEmpty {
                    modernAdditionalInfoSection(details: details)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    
    // MARK: - Quick Actions Row
    private func quickActionsRow(details: RestaurantDetails) -> some View {
        HStack(spacing: 12) {
            // Directions Action
            Button(action: {
                openInAppleMaps()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Directions")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.primary.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Website Action
            if let websiteURL = restaurant.websiteURL, !websiteURL.isEmpty {
                Button(action: {
                    if let url = URL(string: websiteURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Website")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Menu Action
            if let menuURL = restaurant.menuURL, !menuURL.isEmpty {
                Button(action: {
                    if let url = URL(string: menuURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Menu")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Modern About Section
    private func modernAboutSection(details: RestaurantDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.seaweedGreen)
                
                Text("About")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(details.description)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Modern Hours Section
    private func modernHoursSection(details: RestaurantDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("Hours")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(details.hours, id: \.self) { hour in
                    HStack {
                        Text(hour)
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Add a subtle indicator for current day
                        if hour.contains("Monday") {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Modern Additional Info Section
    private func modernAdditionalInfoSection(details: RestaurantDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Additional Info")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(details.additionalInfo)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Methods
    private func loadRestaurantDetails() {
        isLoading = true
        errorMessage = nil
        
        restaurantService.getRestaurantDetails(for: restaurant) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    // Details loaded successfully
                    break
                case .failure(let error):
                    print("RestaurantDetailView: Error loading details - \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func openInAppleMaps() {
        let searchQuery = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mapsURL = "http://maps.apple.com/?q=\(searchQuery)"
        
        if let url = URL(string: mapsURL) {
            UIApplication.shared.open(url)
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
    RestaurantDetailView(restaurant: ExploreIdea(
        name: "The Lark",
        description: "Modern American cuisine",
        location: "Santa Barbara, CA",
        address: "131 Anacapa St, Santa Barbara, CA",
        latitude: 34.4208,
        longitude: -119.6982,
        category: "restaurant",
        cuisineType: "American",
        activityType: nil,
        priceLevel: "$$",
        rating: 4.7,
        whyRecommended: "Great atmosphere and food",
        estimatedCost: "$50-80",
        bestTime: "Dinner",
        duration: nil,
        isOpen: true,
        openHours: "11:00 AM - 10:00 PM",
        imageURL: nil,
        websiteURL: "https://thelarksb.com",
        menuURL: nil
    ))
}
