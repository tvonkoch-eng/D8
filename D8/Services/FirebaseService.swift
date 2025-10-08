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
    
    func deleteExploreIdeas(for location: String, date: String) async throws {
        let locationId = location.lowercased().replacingOccurrences(of: " ", with: "_")
        let docRef = db.collection("exploreIdeas")
            .document("locations")
            .collection(locationId)
            .document("dates")
            .collection(date)
            .document("ideas")
        
        try await docRef.delete()
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
    
    // MARK: - Restaurant Details Management
    
    func saveRestaurantDetails(_ details: RestaurantDetails) async throws {
        try await db.collection("restaurantDetails").document(details.restaurantId).setData(from: details)
    }
    
    func getRestaurantDetails(for restaurantId: String) async throws -> RestaurantDetails? {
        let document = try await db.collection("restaurantDetails").document(restaurantId).getDocument()
        return try document.data(as: RestaurantDetails.self)
    }
    
    func deleteRestaurantDetails(for restaurantId: String) async throws {
        try await db.collection("restaurantDetails").document(restaurantId).delete()
    }
    
    func cleanupOldRestaurantDetails() async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let query = db.collection("restaurantDetails")
            .whereField("lastUpdated", isLessThan: cutoffDate)
        
        let snapshot = try await query.getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }
    
    // MARK: - Restaurant Database Management
    
    func saveRestaurantDatabaseEntry(_ entry: RestaurantDatabaseEntry, restaurantId: String) async throws {
        let entryWithId = RestaurantDatabaseEntry(
            id: restaurantId,
            name: entry.name,
            description: entry.description,
            location: entry.location,
            address: entry.address,
            latitude: entry.latitude,
            longitude: entry.longitude,
            cuisineType: entry.cuisineType,
            priceLevel: entry.priceLevel,
            rating: entry.rating,
            whyRecommended: entry.whyRecommended,
            estimatedCost: entry.estimatedCost,
            bestTime: entry.bestTime,
            duration: entry.duration,
            isOpen: entry.isOpen,
            openHours: entry.openHours,
            imageURL: entry.imageURL,
            websiteURL: entry.websiteURL,
            menuURL: entry.menuURL,
            viewCount: entry.viewCount,
            lastViewed: entry.lastViewed,
            createdAt: entry.createdAt,
            lastUpdated: entry.lastUpdated,
            enhancedDescription: entry.enhancedDescription,
            operatingHours: entry.operatingHours,
            additionalInfo: entry.additionalInfo,
            hasEnhancedDetails: entry.hasEnhancedDetails
        )
        try await db.collection("restaurantDatabase").document(restaurantId).setData(from: entryWithId)
    }
    
    func getRestaurantDatabaseEntry(for restaurantId: String) async throws -> RestaurantDatabaseEntry? {
        let document = try await db.collection("restaurantDatabase").document(restaurantId).getDocument()
        return try document.data(as: RestaurantDatabaseEntry.self)
    }
    
    func restaurantDatabaseEntryExists(for restaurantId: String) async throws -> Bool {
        let document = try await db.collection("restaurantDatabase").document(restaurantId).getDocument()
        return document.exists
    }
    
    func getRestaurantsByLocation(location: String, limit: Int = 50) async throws -> [RestaurantDatabaseEntry] {
        let snapshot = try await db.collection("restaurantDatabase")
            .whereField("location", isEqualTo: location)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: RestaurantDatabaseEntry.self)
        }
    }
    
    func getRestaurantsByCuisine(cuisine: String, limit: Int = 50) async throws -> [RestaurantDatabaseEntry] {
        let snapshot = try await db.collection("restaurantDatabase")
            .whereField("cuisineType", isEqualTo: cuisine)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: RestaurantDatabaseEntry.self)
        }
    }
    
    func searchRestaurants(query: String, limit: Int = 20) async throws -> [RestaurantDatabaseEntry] {
        // Note: This is a simple implementation. For better search, consider using Algolia or similar
        let snapshot = try await db.collection("restaurantDatabase")
            .whereField("name", isGreaterThanOrEqualTo: query)
            .whereField("name", isLessThan: query + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: RestaurantDatabaseEntry.self)
        }
    }
    
    func getPopularRestaurantsFromDatabase(limit: Int = 20) async throws -> [RestaurantDatabaseEntry] {
        let snapshot = try await db.collection("restaurantDatabase")
            .order(by: "viewCount", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: RestaurantDatabaseEntry.self)
        }
    }
    
    func incrementRestaurantViewCount(restaurantId: String) async throws {
        let docRef = db.collection("restaurantDatabase").document(restaurantId)
        
        try await docRef.updateData([
            "viewCount": FieldValue.increment(Int64(1)),
            "lastViewed": FieldValue.serverTimestamp()
        ])
    }
    
    func updateRestaurantEnhancedDetails(
        restaurantId: String,
        enhancedDescription: String,
        operatingHours: [String],
        additionalInfo: String
    ) async throws {
        try await db.collection("restaurantDatabase").document(restaurantId).updateData([
            "enhancedDescription": enhancedDescription,
            "operatingHours": operatingHours,
            "additionalInfo": additionalInfo,
            "hasEnhancedDetails": true,
            "lastUpdated": FieldValue.serverTimestamp()
        ])
    }
    
    func getRestaurantDatabaseStats() async throws -> RestaurantDatabaseStats {
        let snapshot = try await db.collection("restaurantDatabase").getDocuments()
        let restaurants = try snapshot.documents.compactMap { document in
            try document.data(as: RestaurantDatabaseEntry.self)
        }
        
        let totalRestaurants = restaurants.count
        let restaurantsWithEnhancedDetails = restaurants.filter { $0.hasEnhancedDetails }.count
        let totalViews = restaurants.reduce(0) { $0 + $1.viewCount }
        let averageRating = restaurants.isEmpty ? 0.0 : restaurants.reduce(0.0) { $0 + $1.rating } / Double(restaurants.count)
        
        // Find most popular cuisine
        let cuisineCounts = Dictionary(grouping: restaurants, by: { $0.cuisineType })
            .mapValues { $0.count }
        let mostPopularCuisine = cuisineCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
        
        return RestaurantDatabaseStats(
            totalRestaurants: totalRestaurants,
            restaurantsWithEnhancedDetails: restaurantsWithEnhancedDetails,
            totalViews: totalViews,
            averageRating: averageRating,
            mostPopularCuisine: mostPopularCuisine,
            lastUpdated: Date()
        )
    }
    
    func cleanupOldRestaurantDatabaseEntries() async throws {
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        let query = db.collection("restaurantDatabase")
            .whereField("lastViewed", isLessThan: cutoffDate)
            .whereField("viewCount", isLessThan: 5) // Only clean up rarely viewed restaurants
        
        let snapshot = try await query.getDocuments()
        
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        print("🧹 [FirebaseService] Cleaned up \(snapshot.documents.count) old restaurant database entries")
    }
    
    // MARK: - Recommendation Storage
    
    func storeRecommendation(
        name: String,
        description: String,
        category: String,
        location: String,
        latitude: Double,
        longitude: Double,
        estimatedCost: String,
        bestTime: String,
        whyRecommended: String,
        dateType: DateType
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user to store recommendation")
            return
        }
        
        let recommendation = [
            "name": name,
            "description": description,
            "category": category,
            "location": location,
            "latitude": latitude,
            "longitude": longitude,
            "estimatedCost": estimatedCost,
            "bestTime": bestTime,
            "whyRecommended": whyRecommended,
            "dateType": dateType.displayName,
            "timestamp": Timestamp(date: Date()),
            "userId": userId
        ] as [String: Any]
        
        db.collection("recommendations").addDocument(data: recommendation) { error in
            if let error = error {
                print("Error storing recommendation: \(error)")
            } else {
                print("Successfully stored recommendation: \(name)")
            }
        }
    }
    
    func getStoredRecommendations(userId: String, dateType: DateType? = nil) async throws -> [[String: Any]] {
        var query = db.collection("recommendations").whereField("userId", isEqualTo: userId)
        
        if let dateType = dateType {
            query = query.whereField("dateType", isEqualTo: dateType.displayName)
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.map { $0.data() }
    }
}
