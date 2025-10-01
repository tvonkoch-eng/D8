//
//  ActivitySelectionView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct ActivitySelectionView: View {
    @Binding var selectedActivityTypes: Set<ActivityType>
    @Binding var selectedActivityIntensity: ActivityIntensity?
    
    let activityTypes: [ActivityType] = [.sports, .outdoor, .indoor, .entertainment, .fitness, .notSure]
    let activityIntensities: [ActivityIntensity] = [.low, .medium, .high, .notSure]
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("What activities?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.seaweedGreenGradient)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Activity Types
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity Types")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                    ForEach(activityTypes, id: \.self) { activityType in
                        ActivityTypeOptionView(
                            activityType: activityType,
                            isSelected: selectedActivityTypes.contains(activityType)
                        ) {
                            if activityType == .notSure {
                                selectedActivityTypes = [.notSure]
                            } else {
                                selectedActivityTypes.remove(.notSure)
                                if selectedActivityTypes.contains(activityType) {
                                    selectedActivityTypes.remove(activityType)
                                } else {
                                    selectedActivityTypes.insert(activityType)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ActivityIntensitySelectionView: View {
    @Binding var selectedActivityIntensity: ActivityIntensity?
    
    let activityIntensities: [ActivityIntensity] = [.low, .medium, .high, .notSure]
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("Activity Intensity")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.seaweedGreenGradient)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Activity Intensity
            VStack(alignment: .leading, spacing: 16) {
                Text("How intense?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2), spacing: 15) {
                    ForEach(activityIntensities, id: \.self) { intensity in
                        ActivityIntensityOptionView(
                            intensity: intensity,
                            isSelected: selectedActivityIntensity == intensity
                        ) {
                            selectedActivityIntensity = intensity
                        }
                    }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ActivityTypeOptionView: View {
    let activityType: ActivityType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: activityType.icon)
                    .font(.system(size: 30))
                    .foregroundColor(.primary)
                
                Text(activityType.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(activityType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityIntensityOptionView: View {
    let intensity: ActivityIntensity
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: intensity.icon)
                    .font(.system(size: 30))
                    .foregroundColor(.primary)
                
                Text(intensity.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(intensity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
