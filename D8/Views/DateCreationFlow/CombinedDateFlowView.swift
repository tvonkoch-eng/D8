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
                // Results - Full Screen (conditional based on date type)
                if selectedDateType == .meal {
                    RestaurantResultsView(
                        dateType: selectedDateType,
                        mealTimes: selectedMealTimes,
                        priceRange: selectedPriceRange,
                        date: selectedDate,
                        cuisines: selectedCuisines
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .zIndex(1)
                } else {
                    ActivityResultsView(
                        dateType: selectedDateType,
                        activityTypes: selectedActivityTypes,
                        activityIntensity: selectedActivityIntensity,
                        priceRange: selectedPriceRange,
                        date: selectedDate
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .zIndex(1)
                }
            } else {
                // Date Creation Flow - Half Sheet
                VStack(spacing: 0) {
                    // Content - scrollable for half-sheet
                    ScrollView {
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
                        .padding(.horizontal, 20)
                    }
                    
                    // Compact navigation buttons
                    if selectedDateType != nil {
                        HStack {
                            // Previous button (only show if not on first step)
                            if currentStep > 0 {
                                Button("PREVIOUS") {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                }
                                .font(.system(size: 16, weight: .bold))
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.seaweedGreen)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
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
        
    }
}
