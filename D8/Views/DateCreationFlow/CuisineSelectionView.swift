//
//  CuisineSelectionView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct CuisineSelectionView: View {
    @Binding var selectedCuisines: Set<Cuisine>
    
    let cuisines: [Cuisine] = [.italian, .mexican, .american, .japanese, .chinese, .indian, .thai, .french, .mediterranean, .notSure]
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact title
            Text("What cuisines?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            // Full-width grid layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(cuisines, id: \.self) { cuisine in
                    CuisineOptionView(
                        cuisine: cuisine,
                        isSelected: selectedCuisines.contains(cuisine)
                    ) {
                        if cuisine == .notSure {
                            selectedCuisines = [.notSure]
                        } else {
                            selectedCuisines.remove(.notSure)
                            if selectedCuisines.contains(cuisine) {
                                selectedCuisines.remove(cuisine)
                            } else {
                                selectedCuisines.insert(cuisine)
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

struct CuisineOptionView: View {
    let cuisine: Cuisine
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(cuisine.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
