//
//  MealTimeSelectionView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct MealTimeSelectionView: View {
    @Binding var selectedMealTimes: Set<MealTime>
    
    let mealTimes: [MealTime] = [.breakfast, .lunch, .dinner, .notSure]
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact title
            Text("What meal?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.seaweedGreenGradient)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            // Full-width grid layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(mealTimes, id: \.self) { mealTime in
                    MealTimeOptionView(
                        mealTime: mealTime,
                        isSelected: selectedMealTimes.contains(mealTime)
                    ) {
                        if mealTime == .notSure {
                            selectedMealTimes = [.notSure]
                        } else {
                            selectedMealTimes.remove(.notSure)
                            if selectedMealTimes.contains(mealTime) {
                                selectedMealTimes.remove(mealTime)
                            } else {
                                selectedMealTimes.insert(mealTime)
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

struct MealTimeOptionView: View {
    let mealTime: MealTime
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: mealTime.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
                
                Text(mealTime.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}
