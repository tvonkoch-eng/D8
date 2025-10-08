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
            // Compact title
            Text("What type of date?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
            
            // Compact cards
            VStack(spacing: 12) {
                ForEach(dateTypes, id: \.self) { dateType in
                    DateTypeOptionView(
                        dateType: dateType,
                        isSelected: selectedDateType == dateType
                    ) {
                        selectedDateType = dateType
                    }
                }
            }
            .padding(.horizontal, 0)
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 20)
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
            HStack(spacing: 16) {
                // Compact icon
                if dateType == .meal {
                    Text("🍽️")
                        .font(.system(size: 28))
                } else {
                    Image(systemName: dateType.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.seaweedGreen)
                }
                
                // Compact text content
                VStack(alignment: .leading, spacing: 4) {
                    // Display name
                    Text(dateType.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Description
                    Text(dateType.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isSelected ? 0.95 : 1.0) // Subtle visual feedback without size change
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
