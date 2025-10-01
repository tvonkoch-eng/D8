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
            return [.low, .medium, .high, .luxury, .notSure]
        } else {
            // For activity dates, include all options including free
            return [.free, .low, .medium, .high, .luxury, .notSure]
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("What's your budget?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.seaweedGreenGradient)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 2), spacing: 20) {
                ForEach(priceRanges, id: \.self) { priceRange in
                    PriceRangeOptionView(
                        priceRange: priceRange,
                        isSelected: selectedPriceRange == priceRange
                    ) {
                        selectedPriceRange = priceRange
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

struct PriceRangeOptionView: View {
    let priceRange: PriceRange
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: priceRange.icon)
                    .font(.system(size: 30))
                    .foregroundColor(.primary)
                
                Text(priceRange.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if priceRange.description != nil {
                    Text(priceRange.description!)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
