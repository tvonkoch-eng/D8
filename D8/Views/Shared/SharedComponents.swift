//
//  SharedComponents.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

// MARK: - Color Extensions
extension Color {
    static let seaweedGreen = Color(red: 0.208, green: 0.290, blue: 0.129) // #354A21
    static let seaweedGreenGradient = LinearGradient(
        colors: [Color.seaweedGreen, Color.seaweedGreen.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Preference Capsule Component
struct PreferenceCapsule: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            // Icon
            if icon.count == 1 && icon.unicodeScalars.first?.properties.isEmoji == true {
                // Emoji icon
                Text(icon)
                    .font(.caption)
            } else {
                // SF Symbol icon
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Title and Value
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - Custom Tab Bar Components

// Custom shape for tab bar with curved indentation
struct CurvedTabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let cornerRadius: CGFloat = 25
        let indentWidth: CGFloat = 90
        let indentDepth: CGFloat = 40
        
        // Calculate key points for smoother curves
        let centerX = width / 2
        let indentStartX = centerX - indentWidth / 2
        let indentEndX = centerX + indentWidth / 2
        let transitionWidth: CGFloat = 25 // Wider transition for smoother curves
        
        // Start from top left corner
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top edge leading to indentation
        path.addLine(to: CGPoint(x: indentStartX - transitionWidth, y: 0))
        
        // Smooth transition into the indent - first curve
        path.addCurve(
            to: CGPoint(x: indentStartX, y: indentDepth * 0.3),
            control1: CGPoint(x: indentStartX - transitionWidth * 0.5, y: 0),
            control2: CGPoint(x: indentStartX - transitionWidth * 0.2, y: indentDepth * 0.15)
        )
        
        // Middle curve of indentation - deepest part
        path.addCurve(
            to: CGPoint(x: indentEndX, y: indentDepth * 0.3),
            control1: CGPoint(x: centerX - indentWidth * 0.15, y: indentDepth * 1.2),
            control2: CGPoint(x: centerX + indentWidth * 0.15, y: indentDepth * 1.2)
        )
        
        // Smooth transition out of the indent - final curve
        path.addCurve(
            to: CGPoint(x: indentEndX + transitionWidth, y: 0),
            control1: CGPoint(x: indentEndX + transitionWidth * 0.2, y: indentDepth * 0.15),
            control2: CGPoint(x: indentEndX + transitionWidth * 0.5, y: 0)
        )
        
        // Continue to top right
        path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
        
        // Top right corner
        path.addQuadCurve(
            to: CGPoint(x: width, y: cornerRadius),
            control: CGPoint(x: width, y: 0)
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
        
        // Bottom right corner
        path.addQuadCurve(
            to: CGPoint(x: width - cornerRadius, y: height),
            control: CGPoint(x: width, y: height)
        )
        
        // Bottom edge - extend all the way to bottom
        path.addLine(to: CGPoint(x: 0, y: height))
        
        // Left edge - go straight up from bottom
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        // Top left corner
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        
        return path
    }
}

// Custom Tab Bar View
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onPlusTapped: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            // Single centered tab - Explore (Safari icon)
            Button(action: {
                selectedTab = 0
            }) {
                VStack(spacing: 1) {
                    Image(systemName: "safari")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("Seaweed"))
                    
                    Text("Explore")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color("Seaweed"))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, -35)
        .padding(.vertical, 1)
        .padding(.top, 2)
        .background(
            CurvedTabBarShape()
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(.all, edges: .bottom)
        )
    }
}

// MARK: - Async Image Component
struct AsyncImageView: View {
    let urlString: String?
    let placeholder: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(urlString: String?, placeholder: String = "🍽️", width: CGFloat = 80, height: CGFloat = 80, cornerRadius: CGFloat = 8) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .overlay(
                            Text(placeholder)
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        Text(placeholder)
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

