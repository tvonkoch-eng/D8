//
//  OnboardingFlowView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct OnboardingData {
    var ageRange: AgeRange? = nil
    var relationshipStatus: RelationshipStatus? = nil
    var hobbies: Set<HobbyInterest> = []
    var budget: BudgetRange? = nil
    var cuisines: Set<CuisinePreference> = []
    var transportation: Set<TransportationOption> = []
}

enum AgeRange: String, CaseIterable {
    case seventeenAndBelow = "17 and below"
    case eighteenToTwentyFour = "18-24"
    case twentyFiveToThirtyFour = "25-34"
    case thirtyFiveToFortyFour = "35-44"
    case fortyFiveToFiftyFour = "45-54"
    case fiftyFivePlus = "55+"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .seventeenAndBelow: return .blue
        case .eighteenToTwentyFour: return .green
        case .twentyFiveToThirtyFour: return .orange
        case .thirtyFiveToFortyFour: return .purple
        case .fortyFiveToFiftyFour: return .red
        case .fiftyFivePlus: return .pink
        }
    }
}

enum BudgetRange: String, CaseIterable {
    case budget = "Budget ($)"
    case moderate = "Moderate ($$)"
    case upscale = "Upscale ($$$)"
    case luxury = "Luxury ($$$$)"
    case notSure = "Not sure"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .budget: return .green
        case .moderate: return .blue
        case .upscale: return .orange
        case .luxury: return .purple
        case .notSure: return .gray
        }
    }
}

enum CuisinePreference: String, CaseIterable {
    case american = "American"
    case italian = "Italian"
    case asian = "Asian"
    case mexican = "Mexican"
    case mediterranean = "Mediterranean"
    case indian = "Indian"
    case french = "French"
    case japanese = "Japanese"
    case thai = "Thai"
    case chinese = "Chinese"
    case seafood = "Seafood"
    case steakhouse = "Steakhouse"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case other = "Other"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .american: return .red
        case .italian: return .green
        case .asian: return .orange
        case .mexican: return .yellow
        case .mediterranean: return .blue
        case .indian: return .purple
        case .french: return .pink
        case .japanese: return .cyan
        case .thai: return .mint
        case .chinese: return .brown
        case .seafood: return .teal
        case .steakhouse: return .gray
        case .vegetarian: return .green
        case .vegan: return .mint
        case .other: return .gray
        }
    }
}

enum TransportationOption: String, CaseIterable {
    case walking = "Walking"
    case driving = "Driving"
    case publicTransit = "Public Transit"
    case rideshare = "Rideshare"
    case cycling = "Cycling"
    case flexible = "Flexible"
    
    var displayName: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .walking: return .green
        case .driving: return .blue
        case .publicTransit: return .orange
        case .rideshare: return .purple
        case .cycling: return .mint
        case .flexible: return .gray
        }
    }
}

struct OnboardingFlowView: View {
    @State private var currentStep = -1 // Start with launch screen
    @State private var onboardingData = OnboardingData()
    @State private var isAnimating = false
    @State private var showOnboarding = false
    
    let onComplete: (OnboardingData) -> Void
    
    private let totalSteps = 6
    
    var body: some View {
        ZStack {
            // Shared Background with Moving Circles
            ZStack {
                // White background to hide explore page
                Color.white
                    .ignoresSafeArea()
                
                // Animated Background
                LinearGradient(
                    colors: [
                        Color("Seaweed"),
                        Color("Seaweed").opacity(0.8),
                        Color("Seaweed").opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .overlay(
                    // Floating circles for visual interest
                    ZStack {
                        ForEach(0..<10, id: \.self) { index in
                            FloatingCircleView(
                                index: index,
                                isAnimating: true
                            )
                        }
                    }
                )
            }
            
            if currentStep == -1 {
                // Launch Screen
                OnboardingLaunchView {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStep = 0
                        showOnboarding = true
                    }
                }
                .transition(.opacity)
            } else {
                // Onboarding Flow - Full Screen Overlay
                ZStack {
                    // Progress Bar
                    VStack {
                        Spacer()
                            .frame(height: 60)
                        
                        ProgressBarView(currentStep: currentStep, totalSteps: totalSteps)
                            .padding(.horizontal, 24)
                            .opacity(showOnboarding ? 1 : 0)
                            .offset(y: showOnboarding ? 0 : -20)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: showOnboarding)
                        
                        Spacer()
                    }
                    
                    // Content - Full Screen
                    TabView(selection: $currentStep) {
                        // Step 1: Age Range
                        AgeRangeView(
                            selectedAgeRange: $onboardingData.ageRange
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 1
                            }
                        }
                        .tag(0)
                        
                        // Step 2: Relationship Status
                        RelationshipStatusView(
                            selectedStatus: $onboardingData.relationshipStatus
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        } onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 0
                            }
                        }
                        .tag(1)
                        
                        // Step 3: Budget Range
                        BudgetRangeView(
                            selectedBudget: $onboardingData.budget
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 3
                            }
                        } onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 1
                            }
                        }
                        .tag(2)
                        
                        // Step 4: Cuisine Preference
                        CuisinePreferenceView(
                            selectedCuisines: $onboardingData.cuisines
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 4
                            }
                        } onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        }
                        .tag(3)
                        
                        // Step 5: Transportation Option
                        TransportationOptionView(
                            selectedTransportation: $onboardingData.transportation
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 5
                            }
                        } onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 3
                            }
                        }
                        .tag(4)
                        
                        // Step 6: Hobbies & Interests
                        HobbiesInterestsView(
                            selectedHobbies: $onboardingData.hobbies
                        ) {
                            // Complete onboarding
                            completeOnboarding()
                        } onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 4
                            }
                        }
                        .tag(5)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    .allowsHitTesting(true)
                    .gesture(
                        DragGesture()
                            .onChanged { _ in }
                            .onEnded { _ in }
                    )
                    
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isAnimating = true
        }
        
        // Add a small delay to show the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete(onboardingData)
        }
    }
}

struct ProgressBarView: View {
    let currentStep: Int
    let totalSteps: Int
    
    private var progress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }
    
    var body: some View {
        HStack {
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.nexa(.regular, size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Simple progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(width: 60, height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    OnboardingFlowView { onboardingData in
        print("Onboarding completed with data: \(onboardingData)")
    }
}
