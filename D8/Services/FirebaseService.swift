//
//  FirebaseService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - User Profile Management
    
    func createUserProfile(userId: String) async throws {
        let userProfile = UserProfile(userId: userId)
        try await db.collection("userProfiles").document(userId).setData(from: userProfile)
    }
    
    func getUserProfile(userId: String) async throws -> UserProfile? {
        let document = try await db.collection("userProfiles").document(userId).getDocument()
        return try document.data(as: UserProfile.self)
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        try await db.collection("userProfiles").document(profile.userId).setData(from: profile)
    }
    
    // MARK: - Feedback Management
    
    func submitFeedback(_ feedback: FeedbackData) async throws {
        try await db.collection("feedback").document(feedback.id.uuidString).setData(from: feedback)
        
        // Update user profile with feedback
        if var profile = try await getUserProfile(userId: feedback.userId) {
            profile.totalFeedback += 1
            profile.lastUpdated = Date()
            
            // Update preferences based on feedback
            if feedback.wasVisited && feedback.rating > 3.0 {
                // Learn from positive feedback
                profile = updatePreferencesFromFeedback(profile, feedback)
            }
            
            try await updateUserProfile(profile)
        }
    }
    
    func getFeedbackForUser(userId: String) async throws -> [FeedbackData] {
        let snapshot = try await db.collection("feedback")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: FeedbackData.self)
        }
    }
    
    // MARK: - Recommendation Tracking
    
    func trackRecommendation(_ tracking: RecommendationTracking) async throws {
        try await db.collection("recommendations").document(tracking.id).setData(from: tracking)
    }
    
    func getRecommendationHistory(userId: String) async throws -> [RecommendationTracking] {
        let snapshot = try await db.collection("recommendations")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: RecommendationTracking.self)
        }
    }
    
    // MARK: - Analytics
    
    func getPopularRestaurants(limit: Int = 10) async throws -> [String: Int] {
        let snapshot = try await db.collection("feedback")
            .whereField("wasVisited", isEqualTo: true)
            .whereField("rating", isGreaterThan: 3.0)
            .getDocuments()
        
        var restaurantCounts: [String: Int] = [:]
        for document in snapshot.documents {
            if let data = try? document.data(as: FeedbackData.self) {
                restaurantCounts[data.restaurantId, default: 0] += 1
            }
        }
        
        let sortedItems = Array(restaurantCounts.sorted { $0.value > $1.value }.prefix(limit))
        return Dictionary(uniqueKeysWithValues: sortedItems)
    }
    
    // MARK: - Helper Methods
    
    private func updatePreferencesFromFeedback(_ profile: UserProfile, _ feedback: FeedbackData) -> UserProfile {
        var updatedProfile = profile
        
        // Add to dining history
        let experience = DiningExperience(
            restaurantId: feedback.restaurantId,
            restaurantName: feedback.restaurantName,
            date: feedback.visitDate ?? Date(),
            rating: feedback.rating,
            mealTime: "unknown", // You can extract this from context
            companions: 1, // Default, can be improved
            occasion: "unknown", // Can be extracted from context
            feedback: feedback.feedback,
            photos: nil,
            totalCost: nil,
            wasRecommended: true,
            recommendationId: feedback.recommendationId
        )
        
        updatedProfile.diningHistory.append(experience)
        
        // Update preferences based on rating
        if feedback.rating > 4.0 {
            // Positive feedback - increase weights for this type of restaurant
            // This is where you'd implement your learning algorithm
        }
        
        return updatedProfile
    }
    
    // MARK: - Explore Ideas Management
    
    func getExploreIdeas(for location: String, date: String) async throws -> ExploreIdeas? {
        let locationId = location.lowercased().replacingOccurrences(of: " ", with: "_")
        let docRef = db.collection("exploreIdeas")
            .document("locations")
            .collection(locationId)
            .document("dates")
            .collection(date)
            .document("ideas")
        
        let document = try await docRef.getDocument()
        
        guard document.exists else {
            return nil
        }
        
        let exploreIdeas = try document.data(as: ExploreIdeas.self)
        
        // Check if ideas have expired
        if exploreIdeas.expiresAt < Date() {
            // Delete expired ideas
            try await docRef.delete()
            return nil
        }
        
        return exploreIdeas
    }
    
    func saveExploreIdeas(_ exploreIdeas: ExploreIdeas) async throws {
        let locationId = exploreIdeas.location.lowercased().replacingOccurrences(of: " ", with: "_")
        let docRef = db.collection("exploreIdeas")
            .document("locations")
            .collection(locationId)
            .document("dates")
            .collection(exploreIdeas.date)
            .document("ideas")
        
        try await docRef.setData(from: exploreIdeas)
        
        // Update location metadata
        let metadataRef = db.collection("exploreIdeas")
            .document("locations")
            .collection(locationId)
            .document("metadata")
        
        try await metadataRef.setData([
            "lastUpdated": exploreIdeas.generatedAt,
            "totalIdeas": exploreIdeas.ideas.count,
            "location": exploreIdeas.location
        ], merge: true)
    }
    
    // MARK: - Cleanup Functions
    
    func cleanupExpiredIdeas() async throws {
        // Query all ideas documents across all locations
        let ideasSnapshot = try await db.collectionGroup("ideas").getDocuments()
        
        let currentDate = Date()
        var deletedCount = 0
        
        for document in ideasSnapshot.documents {
            do {
                let exploreIdeas = try document.data(as: ExploreIdeas.self)
                if exploreIdeas.expiresAt < currentDate {
                    try await document.reference.delete()
                    deletedCount += 1
                }
            } catch {
                // If we can't parse the document, delete it as it's likely corrupted
                try await document.reference.delete()
                deletedCount += 1
            }
        }
        
        print("🧹 Cleaned up \(deletedCount) expired explore ideas")
    }
    
    func getLocationDates(for location: String) async throws -> [String] {
        let locationId = location.lowercased().replacingOccurrences(of: " ", with: "_")
        
        // Query all ideas documents for this specific location
        let ideasSnapshot = try await db.collectionGroup("ideas")
            .whereField("location", isEqualTo: location)
            .getDocuments()
        
        return ideasSnapshot.documents.compactMap { document in
            try? document.data(as: ExploreIdeas.self)
        }.map { $0.date }.sorted()
    }
    
    func deleteLocationIdeas(for location: String, date: String) async throws {
        let locationId = location.lowercased().replacingOccurrences(of: " ", with: "_")
        let docRef = db.collection("exploreIdeas")
            .document("locations")
            .collection(locationId)
            .document("dates")
            .collection(date)
            .document("ideas")
        
        try await docRef.delete()
    }
    
    // MARK: - Scheduled Events Management
    
    func saveScheduledEvent(_ event: ScheduledEvent) async throws {
        try await db.collection("user_events").document(event.userId).collection("events").document(event.id.uuidString).setData(from: event)
    }
    
    func updateScheduledEvent(_ event: ScheduledEvent) async throws {
        try await db.collection("user_events").document(event.userId).collection("events").document(event.id.uuidString).setData(from: event)
    }
    
    func deleteScheduledEvent(_ eventId: UUID, userId: String) async throws {
        try await db.collection("user_events").document(userId).collection("events").document(eventId.uuidString).delete()
    }
    
    func getScheduledEvents(for userId: String) async throws -> [ScheduledEvent] {
        let snapshot = try await db.collection("user_events").document(userId).collection("events").getDocuments()
        return snapshot.documents.compactMap { document in
            try? document.data(as: ScheduledEvent.self)
        }
    }
    
    // MARK: - Test Methods
    
    func testFirebaseConnection() async throws -> String {
        let testUserId = "test_user_\(UUID().uuidString)"
        try await createUserProfile(userId: testUserId)
        
        if let profile = try await getUserProfile(userId: testUserId) {
            return "✅ Firebase working! User profile created: \(profile.userId)"
        } else {
            return "❌ Failed to retrieve user profile"
        }
    }
}
