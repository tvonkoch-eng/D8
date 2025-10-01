//
//  CombinedDateFlowView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct CombinedDateFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userProfileService = UserProfileService.shared
    @State private var currentStep = 0
    @State private var maxStepReached = 0 // Track the furthest step reached
    @State private var selectedDateType: DateType? = nil
    @State private var selectedMealTimes: Set<MealTime> = []
    @State private var selectedPriceRange: PriceRange? = nil
    @State private var selectedDate = Date()
    @State private var selectedCuisines: Set<Cuisine> = []
    @State private var selectedActivityTypes: Set<ActivityType> = []
    @State private var selectedActivityIntensity: ActivityIntensity? = nil
    @State private var showResults = false
    @State private var resultsKey = UUID() // Force refresh of results when preferences change
    
    private var steps: [String] {
        guard let dateType = selectedDateType else { return [] }
        switch dateType {
        case .meal:
            return ["Type", "Meal", "Price", "Date", "Cuisines"]
        case .activity:
            return ["Type", "Activity", "Intensity", "Price", "Date"]
        }
    }
    
    var body: some View {
        ZStack {
            if showResults {
                // Restaurant Results - Full Screen
                RestaurantResultsView(
                    dateType: selectedDateType,
                    mealTimes: selectedMealTimes,
                    priceRange: selectedPriceRange,
                    date: selectedDate,
                    cuisines: selectedCuisines,
                    activityTypes: selectedActivityTypes,
                    activityIntensity: selectedActivityIntensity
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
                .zIndex(1)
            } else {
                // Date Creation Flow - Full Screen
                VStack(spacing: 0) {
                    // Header with X button and progress indicator
                    VStack(spacing: 16) {
                        // Top row with X button - fixed position
                        HStack {
                            Spacer()
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding(.trailing, 40)
                        }
                        .padding(.top, 10)
                        .frame(height: 30) // Fixed height for X button row
                        
                        // Progress indicator - always present but with opacity control
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ForEach(0..<5, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(index <= maxStepReached && selectedDateType != nil ? Color.seaweedGreen : Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 4)
                                        .animation(.easeInOut(duration: 0.3), value: maxStepReached)
                                }
                            }
                            .frame(maxWidth: 400) // Fixed maximum width
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .frame(height: 20) // Fixed height to prevent layout shifts
                        .opacity(selectedDateType != nil ? 1.0 : 0.0) // Show/hide with opacity
                        .animation(.easeInOut(duration: 0.3), value: selectedDateType != nil)
                    }
                    
                    // Content - fixed width container
                    VStack {
                        if selectedDateType == nil {
                            // Show date type selection first
                            DateTypeSelectionView(selectedDateType: $selectedDateType)
                                .onChange(of: selectedDateType) { newValue in
                                    if newValue != nil {
                                        maxStepReached = max(maxStepReached, currentStep)
                                    }
                                }
                        } else {
                            // Show flow based on selected date type
                            switch currentStep {
                            case 0:
                                DateTypeSelectionView(selectedDateType: $selectedDateType)
                            case 1:
                                if selectedDateType == .meal {
                                    MealTimeSelectionView(selectedMealTimes: $selectedMealTimes)
                                } else {
                                    ActivitySelectionView(
                                        selectedActivityTypes: $selectedActivityTypes,
                                        selectedActivityIntensity: $selectedActivityIntensity
                                    )
                                }
                            case 2:
                                if selectedDateType == .meal {
                                    PriceRangeSelectionView(selectedPriceRange: $selectedPriceRange, dateType: selectedDateType!)
                                } else {
                                    ActivityIntensitySelectionView(selectedActivityIntensity: $selectedActivityIntensity)
                                }
                            case 3:
                                if selectedDateType == .meal {
                                    DateSelectionView(selectedDate: $selectedDate)
                                } else {
                                    PriceRangeSelectionView(selectedPriceRange: $selectedPriceRange, dateType: selectedDateType!)
                                }
                            case 4:
                                if selectedDateType == .meal {
                                    CuisineSelectionView(selectedCuisines: $selectedCuisines)
                                } else {
                                    DateSelectionView(selectedDate: $selectedDate)
                                }
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped() // Prevent content from overflowing
                    
                    // Navigation buttons (only show if date type is selected)
                    if selectedDateType != nil {
                        HStack {
                            // Previous button (only show if not on first step)
                            if currentStep > 0 {
                                Button("PREVIOUS") {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.seaweedGreen)
                            }
                            
                            Spacer()
                            
                            Button("NEXT") {
                                if currentStep < steps.count - 1 {
                                    withAnimation {
                                        currentStep += 1
                                        maxStepReached = max(maxStepReached, currentStep)
                                    }
                                } else {
                                    // Show results with animation
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        showResults = true
                                    }
                                }
                            }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.seaweedGreen)
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 50)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
                .zIndex(0)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            prePopulateUserPreferences()
        }
    }
    
    private func prePopulateUserPreferences() {
        guard let userProfile = userProfileService.userProfile else { return }
        
        // Pre-populate cuisines based on user preferences
        if !userProfile.cuisines.isEmpty {
            let userCuisines = userProfile.cuisines.compactMap { cuisineString in
                Cuisine.allCases.first { $0.displayName.lowercased() == cuisineString.uppercased() }
            }
            selectedCuisines = Set(userCuisines)
        }
        
        // Pre-populate price range based on user budget
        if let budget = userProfile.budget {
            selectedPriceRange = PriceRange.allCases.first { priceRange in
                switch (budget, priceRange) {
                case ("low", .low), ("medium", .medium), ("high", .high), ("luxury", .luxury):
                    return true
                default:
                    return false
                }
            }
        }
        
        // Pre-populate activity types based on user hobbies
        if !userProfile.hobbies.isEmpty {
            let hobbyToActivityMap: [String: ActivityType] = [
                "sports": .sports,
                "fitness": .fitness,
                "outdoor": .outdoor,
                "entertainment": .entertainment,
                "arts": .entertainment,
                "music": .entertainment,
                "dancing": .entertainment,
                "gaming": .indoor,
                "reading": .indoor,
                "cooking": .indoor
            ]
            
            let userActivityTypes = userProfile.hobbies.compactMap { hobby in
                hobbyToActivityMap[hobby.lowercased()]
            }
            selectedActivityTypes = Set(userActivityTypes)
        }
    }
}
