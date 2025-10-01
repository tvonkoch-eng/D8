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
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("What cuisines?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.seaweedGreenGradient)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
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
            .padding(.horizontal, 30)
            
            Spacer()
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
            VStack(spacing: 8) {
                Text(cuisine.emoji)
                    .font(.system(size: 30))
                
                Text(cuisine.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.seaweedGreen : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
