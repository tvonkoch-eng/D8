//
//  EventSchedulingView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct EventSchedulingView: View {
    let idea: ExploreIdea
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eventService = EventSchedulingService.shared
    
    @State private var selectedDate = Date()
    @State private var selectedHour = 7 // Default to 7 (will be 7 PM)
    @State private var selectedPeriod = "PM" // AM or PM
    @State private var isScheduling = false
    @State private var showSuccessAlert = false
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(idea: ExploreIdea) {
        self.idea = idea
        dateFormatter.dateStyle = .medium
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with idea info
                    ideaHeaderView
                    
                    // Date selection
                    dateSelectionView
                    
                    // Time selection
                    timeSelectionView
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Schedule Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") {
                        scheduleEvent()
                    }
                    .disabled(isScheduling)
                }
            }
        }
        .alert("Event Scheduled!", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your \(idea.name) event has been scheduled for \(dateFormatter.string(from: selectedDate)) at \(formatTimeForDisplay()).")
        }
    }
    
    private var ideaHeaderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                CategoryBadge(category: idea.category)
                Spacer()
                if idea.isOpen {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Open")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(idea.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(idea.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.caption)
                    .foregroundColor(.red)
                Text(idea.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Tags
            HStack(spacing: 8) {
                if let cuisineType = idea.cuisineType {
                    TagView(text: cuisineType, color: .blue)
                }
                
                if let activityType = idea.activityType {
                    TagView(text: activityType, color: .purple)
                }
                
                TagView(text: idea.priceLevel.capitalized, color: .green)
                
                if let duration = idea.duration {
                    TagView(text: duration, color: .orange)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var dateSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Date")
                .font(.headline)
                .foregroundColor(.primary)
            
            DatePicker(
                "Event Date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .accentColor(.seaweedGreen)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var timeSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Time")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                // Hour picker (1-12)
                VStack {
                    Text("Hour")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Hour", selection: $selectedHour) {
                        ForEach(1...12, id: \.self) { hour in
                            Text("\(hour)")
                                .tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                .frame(maxWidth: .infinity)
                
                // AM/PM picker
                VStack {
                    Text("Period")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Period", selection: $selectedPeriod) {
                        Text("AM").tag("AM")
                        Text("PM").tag("PM")
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func convertTo24Hour(hour: Int, period: String) -> Int {
        if period == "AM" {
            return hour == 12 ? 0 : hour
        } else { // PM
            return hour == 12 ? 12 : hour + 12
        }
    }
    
    private func formatTimeForDisplay() -> String {
        return "\(selectedHour):00 \(selectedPeriod)"
    }
    
    private func scheduleEvent() {
        isScheduling = true
        
        // Combine date and time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = convertTo24Hour(hour: selectedHour, period: selectedPeriod)
        combinedComponents.minute = 0
        
        guard let scheduledDateTime = calendar.date(from: combinedComponents) else {
            isScheduling = false
            return
        }
        
        eventService.scheduleEvent(
            from: idea,
            scheduledDate: selectedDate,
            scheduledTime: scheduledDateTime,
            notes: nil
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isScheduling = false
            showSuccessAlert = true
        }
    }
}
