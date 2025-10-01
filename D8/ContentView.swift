//
//  ContentView.swift
//  D8
//
//  Created by Tobias  Vonkoch  on 9/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var userProfileService = UserProfileService.shared
    @State private var showingLocationDenied = false
    @State private var hasCheckedPermissions = false
    @State private var showingOnboarding = false
    @State private var onboardingData: OnboardingData?
    
    var body: some View {
        ZStack {
            MainTabView()
                .onAppear {
                    if !hasCheckedPermissions {
                        checkLocationPermissions()
                        hasCheckedPermissions = true
                    }
                    
                    // Check if user needs to see onboarding
                    checkOnboardingStatus()
                }
                .sheet(isPresented: $showingLocationDenied) {
                    LocationPermissionDeniedView()
                }
            
            // Onboarding Overlay
            if showingOnboarding {
                OnboardingFlowView { data in
                    print("🎉 Onboarding completed! Data received: \(data)")
                    
                    // Immediately set local storage to prevent re-showing
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    
                    // Save onboarding data to Firebase
                    userProfileService.saveOnboardingData(data)
                    
                    onboardingData = data
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingOnboarding = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: userProfileService.hasCompletedOnboarding) { hasCompleted in
            showingOnboarding = !hasCompleted
        }
    }
    
    private func checkLocationPermissions() {
        // First check current status
        let currentStatus = locationManager.checkCurrentPermissionStatus()
        
        if currentStatus {
            // Permission already granted, continue
            return
        }
        
        // If permission is not determined, request it
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestLocationPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        // Permission was denied, show the denied view
                        showingLocationDenied = true
                    }
                    // If granted, the app will continue normally
                }
            }
        } else {
            // Permission was previously denied or restricted, show the denied view
            showingLocationDenied = true
        }
    }
    
    private func checkOnboardingStatus() {
        // Check local storage first for immediate response
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        showingOnboarding = !hasCompleted
        
        print("🔍 Onboarding status check: hasCompleted=\(hasCompleted), showingOnboarding=\(showingOnboarding)")
    }
}

#Preview {
    ContentView()
}
