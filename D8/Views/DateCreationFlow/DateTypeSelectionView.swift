//
//  DateTypeSelectionView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct DateTypeSelectionView: View {
    @Binding var selectedDateType: DateType?
    
    let dateTypes: [DateType] = [.meal, .activity]
    
    var body: some View {
        VStack(spacing: 0) {
            // Title with gradient - positioned higher
            Text("What type of date?")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity) // Ensure title takes full width
            
            // Two cards vertically stacked
            VStack(spacing: 20) {
                ForEach(dateTypes, id: \.self) { dateType in
                    DateTypeOptionView(
                        dateType: dateType,
                        isSelected: selectedDateType == dateType
                    ) {
                        selectedDateType = dateType
                    }
                }
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity) // Ensure consistent width
            
            Spacer(minLength: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .clipped() // Prevent content from overflowing
    }
}

struct DateTypeOptionView: View {
    let dateType: DateType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                // Icon based on date type
                if dateType == .meal {
                    Text("")
                        .font(.system(size: 40))
                } else {
                    Image(systemName: dateType.icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.seaweedGreen)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    // Display name
                    Text(dateType.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Description
                    Text(dateType.description)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: isSelected ? 3 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isSelected ? 0.95 : 1.0) // Subtle visual feedback without size change
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
