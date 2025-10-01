//
//  EventSchedulingService.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import Foundation
import CoreLocation

class EventSchedulingService: ObservableObject {
    static let shared = EventSchedulingService()
    
    @Published var scheduledEvents: [ScheduledEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firebaseService = FirebaseService.shared
    private let userProfileService = UserProfileService.shared
    private let userDefaults = UserDefaults.standard
    private let eventsKey = "scheduled_events"
    
    private init() {
        loadEventsFromStorage()
        loadEventsFromFirebase()
    }
    
    // MARK: - Public Methods
    
    func scheduleEvent(from idea: ExploreIdea, scheduledDate: Date, scheduledTime: Date, notes: String? = nil) {
        // Get current user ID from UserProfileService
        let userId = userProfileService.deviceId
        
        let event = ScheduledEvent(
            userId: userId,
            name: idea.name,
            description: idea.description,
            location: idea.location,
            address: idea.address,
            latitude: idea.latitude,
            longitude: idea.longitude,
            category: idea.category,
            cuisineType: idea.cuisineType,
            activityType: idea.activityType,
            priceLevel: idea.priceLevel,
            rating: idea.rating,
            estimatedCost: idea.estimatedCost,
            duration: idea.duration,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            notes: notes
        )
        
        scheduledEvents.append(event)
        saveEventsToStorage()
        saveEventToFirebase(event)
    }
    
    func updateEvent(_ event: ScheduledEvent) {
        if let index = scheduledEvents.firstIndex(where: { $0.id == event.id }) {
            scheduledEvents[index] = event
            saveEventsToStorage()
            updateEventInFirebase(event)
        }
    }
    
    func deleteEvent(_ event: ScheduledEvent) {
        scheduledEvents.removeAll { $0.id == event.id }
        saveEventsToStorage()
        deleteEventFromFirebase(event)
    }
    
    func getEventsForDate(_ date: Date) -> [ScheduledEvent] {
        let calendar = Calendar.current
        let currentUserId = userProfileService.deviceId
        return scheduledEvents.filter { 
            $0.userId == currentUserId && calendar.isDate($0.scheduledDate, inSameDayAs: date) 
        }
    }
    
    func getUpcomingEvents(limit: Int = 10) -> [ScheduledEvent] {
        let now = Date()
        let currentUserId = userProfileService.deviceId
        return scheduledEvents
            .filter { $0.userId == currentUserId && $0.scheduledDate >= now }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .prefix(limit)
            .map { $0 }
    }
    
    func getEventsWithDots() -> [Date: Int] {
        let calendar = Calendar.current
        let currentUserId = userProfileService.deviceId
        var eventCounts: [Date: Int] = [:]
        
        for event in scheduledEvents.filter({ $0.userId == currentUserId }) {
            let date = calendar.startOfDay(for: event.scheduledDate)
            eventCounts[date, default: 0] += 1
        }
        
        return eventCounts
    }
    
    // MARK: - Private Methods
    
    private func loadEventsFromStorage() {
        if let data = userDefaults.data(forKey: eventsKey),
           let events = try? JSONDecoder().decode([ScheduledEvent].self, from: data) {
            scheduledEvents = events
        }
    }
    
    private func loadEventsFromFirebase() {
        Task {
            do {
                let userId = userProfileService.deviceId
                let firebaseEvents = try await firebaseService.getScheduledEvents(for: userId)
                
                await MainActor.run {
                    // Merge Firebase events with local events, prioritizing Firebase
                    let localEventIds = Set(scheduledEvents.map { $0.id })
                    let newFirebaseEvents = firebaseEvents.filter { !localEventIds.contains($0.id) }
                    scheduledEvents.append(contentsOf: newFirebaseEvents)
                    saveEventsToStorage()
                }
            } catch {
                print("Failed to load events from Firebase: \(error)")
            }
        }
    }
    
    private func saveEventsToStorage() {
        if let data = try? JSONEncoder().encode(scheduledEvents) {
            userDefaults.set(data, forKey: eventsKey)
        }
    }
    
    private func saveEventToFirebase(_ event: ScheduledEvent) {
        Task {
            do {
                try await firebaseService.saveScheduledEvent(event)
            } catch {
                print("Failed to save event to Firebase: \(error)")
            }
        }
    }
    
    private func updateEventInFirebase(_ event: ScheduledEvent) {
        Task {
            do {
                try await firebaseService.updateScheduledEvent(event)
            } catch {
                print("Failed to update event in Firebase: \(error)")
            }
        }
    }
    
    private func deleteEventFromFirebase(_ event: ScheduledEvent) {
        Task {
            do {
                try await firebaseService.deleteScheduledEvent(event.id, userId: event.userId)
            } catch {
                print("Failed to delete event from Firebase: \(error)")
            }
        }
    }
}
