//
//  UserProfileService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/28/25.
//

import Foundation
import FirebaseFirestore
import UIKit

class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    private let db = Firestore.firestore()
    let deviceId: String
    
    @Published var hasCompletedOnboarding = false
    @Published var userProfile: UserProfile?
    
    private init() {
        // Use device identifier as temporary user ID
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Check if user has completed onboarding
        checkOnboardingStatus()
    }
    
    // MARK: - Public Methods
    
    func saveOnboardingData(_ onboardingData: OnboardingData) {
        print("🔄 Starting to save onboarding data...")
        print("📱 Device ID: \(deviceId)")
        print("📊 Onboarding data: \(onboardingData)")
        
        let userProfile = onboardingData.toUserProfile(userId: deviceId)
        print("👤 Created user profile: \(userProfile)")
        
        // Save to Firebase
        Task {
            do {
                // Create a simplified data structure for Firebase
                let data: [String: Any] = [
                    "userId": userProfile.userId,
                    "favoriteCuisines": userProfile.favoriteCuisines,
                    "preferredPriceRange": userProfile.preferredPriceRange,
                    "lastUpdated": Timestamp(date: userProfile.lastUpdated),
                    "totalRecommendations": userProfile.totalRecommendations,
                    "totalFeedback": userProfile.totalFeedback,
                    "ageRange": userProfile.ageRange ?? "",
                    "relationshipStatus": userProfile.relationshipStatus ?? "",
                    "hobbies": userProfile.hobbies,
                    "budget": userProfile.budget ?? "",
                    "cuisines": userProfile.cuisines,
                    "transportation": userProfile.transportation,
                    "hasCompletedOnboarding": userProfile.hasCompletedOnboarding,
                    "createdAt": Timestamp(date: Date())
                ]
                
                print("💾 Saving to Firebase with data: \(data)")
                
                try await db.collection("user_profiles").document(deviceId).setData(data)
                
                // Update local state
                await MainActor.run {
                    self.userProfile = userProfile
                    self.hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
                
                print("✅ User profile saved successfully to Firebase!")
            } catch {
                print("❌ Error saving user profile: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
    }
    
    func loadUserProfile() {
        Task {
            do {
                let document = try await db.collection("user_profiles").document(deviceId).getDocument()
                
                if document.exists {
                    let data = document.data() ?? [:]
                    
                    // Create a basic UserProfile and update with onboarding data
                    var userProfile = UserProfile(userId: deviceId)
                    
                    // Update with existing data
                    userProfile.preferences = (try? Firestore.Decoder().decode(UserPreferences.self, from: data["preferences"])) ?? UserPreferences()
                    userProfile.diningHistory = (try? Firestore.Decoder().decode([DiningExperience].self, from: data["diningHistory"])) ?? []
                    userProfile.favoriteCuisines = data["favoriteCuisines"] as? [String] ?? []
                    userProfile.preferredPriceRange = data["preferredPriceRange"] as? String ?? "not_sure"
                    userProfile.lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
                    userProfile.totalRecommendations = data["totalRecommendations"] as? Int ?? 0
                    userProfile.totalFeedback = data["totalFeedback"] as? Int ?? 0
                    
                    // Update onboarding data
                    userProfile.ageRange = data["ageRange"] as? String
                    userProfile.relationshipStatus = data["relationshipStatus"] as? String
                    userProfile.hobbies = data["hobbies"] as? [String] ?? []
                    userProfile.budget = data["budget"] as? String
                    userProfile.cuisines = data["cuisines"] as? [String] ?? []
                    userProfile.transportation = data["transportation"] as? [String] ?? []
                    userProfile.hasCompletedOnboarding = data["hasCompletedOnboarding"] as? Bool ?? false
                    
                    await MainActor.run {
                        self.userProfile = userProfile
                        self.hasCompletedOnboarding = userProfile.hasCompletedOnboarding
                    }
                }
            } catch {
                print("❌ Error loading user profile: \(error)")
            }
        }
    }
    
    func clearUserData() {
        Task {
            do {
                try await db.collection("user_profiles").document(deviceId).delete()
                
                await MainActor.run {
                    self.userProfile = nil
                    self.hasCompletedOnboarding = false
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
                
                print("✅ User profile cleared successfully")
            } catch {
                print("❌ Error clearing user profile: \(error)")
            }
        }
    }
    
    // Method to reset onboarding for testing
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = false
        userProfile = nil
        print("🔄 Onboarding reset - user will see onboarding again")
    }
    
    // MARK: - Private Methods
    
    private func checkOnboardingStatus() {
        // Check UserDefaults first for quick access
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Also load from Firebase to get the latest data
        if hasCompletedOnboarding {
            loadUserProfile()
        }
    }
}
