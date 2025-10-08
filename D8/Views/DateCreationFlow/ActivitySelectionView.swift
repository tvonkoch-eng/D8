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
        VStack(spacing: 0) {
            // Compact title
            Text("What activities?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            // Activity Types - full-width grid
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity Types")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
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
            .padding(.horizontal, 0)
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ActivityIntensitySelectionView: View {
    @Binding var selectedActivityIntensity: ActivityIntensity?
    
    let activityIntensities: [ActivityIntensity] = [.low, .medium, .high, .notSure]
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact title
            Text("Activity Intensity")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            // Activity Intensity - full-width grid
            VStack(alignment: .leading, spacing: 16) {
                Text("How intense?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
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
            .padding(.horizontal, 0)
            
            Spacer(minLength: 20)
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
            VStack(spacing: 8) {
                Image(systemName: activityType.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
                
                Text(activityType.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 2)
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
            VStack(spacing: 8) {
                Image(systemName: intensity.icon)
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
                
                Text(intensity.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
