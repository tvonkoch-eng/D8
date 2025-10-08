//
//  PriceRangeSelectionView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct PriceRangeSelectionView: View {
    @Binding var selectedPriceRange: PriceRange?
    let dateType: DateType
    
    var priceRanges: [PriceRange] {
        if dateType == .meal {
            // For meal dates, exclude free option since restaurants have costs
            return [.low, .medium, .high, .notSure]
        } else {
            // For activity dates, include all options including free
            return [.free, .low, .medium, .high, .notSure]
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact title
            Text("What's your budget?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            // Full-width grid layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(priceRanges, id: \.self) { priceRange in
                    PriceRangeOptionView(
                        priceRange: priceRange,
                        isSelected: selectedPriceRange == priceRange
                    ) {
                        selectedPriceRange = priceRange
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

struct PriceRangeOptionView: View {
    let priceRange: PriceRange
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: priceRange.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
                
                Text(priceRange.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if priceRange.description != nil {
                    Text(priceRange.description!)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 2)
            )
            .padding(.bottom, 8) // Add padding to prevent shadow cutoff
        }
        .buttonStyle(PlainButtonStyle())
    }
}
