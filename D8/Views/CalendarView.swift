//
//  CalendarView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct CalendarView: View {
    @StateObject private var eventService = EventSchedulingService.shared
    @State private var currentDate = Date()
    @State private var selectedDate = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init() {
        dateFormatter.dateFormat = "MMMM yyyy"
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Calendar grid with contained background
                        VStack(spacing: 0) {
                            // Month navigation inside the green background
                            monthNavigationView
                            
                            // Calendar grid
                            calendarGridView
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color("Seaweed").opacity(0.9),
                                            Color("Seaweed").opacity(0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Upcoming events section
                        upcomingEventsView
                        
                        // Add bottom padding to account for tab bar overlap
                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.top, 50)
                }
                .ignoresSafeArea(.container, edges: .top)
                
                // Bottom area that will be covered by tab bar
                Color.clear
                    .frame(height: 100)
            }
        }
    }
    
    private var monthNavigationView: some View {
        HStack {
            // Previous month button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Month and year
            Text(dateFormatter.string(from: currentDate))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // Next month button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 30) // Reduced padding to move arrows closer together
        .padding(.vertical, 15)
    }
    
    private var calendarGridView: some View {
        VStack(spacing: 0) {
            // Days of week header
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Calendar dates - showing 6 weeks for complete month view
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDates, id: \.self) { date in
                    calendarDateView(for: date)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func calendarDateView(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
        let eventsForDate = eventService.getEventsForDate(date)
        let hasEvents = !eventsForDate.isEmpty
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = date
            }
        }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color("Seaweed") : (isCurrentMonth ? .white : .white.opacity(0.4)))
                
                // Event dots
                if hasEvents {
                    HStack(spacing: 2) {
                        ForEach(Array(eventsForDate.prefix(3).enumerated()), id: \.offset) { index, event in
                            Circle()
                                .fill(event.category == "restaurant" ? Color.blue : Color.purple)
                                .frame(width: 4, height: 4)
                        }
                        if eventsForDate.count > 3 {
                            Circle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : (isToday ? Color.white.opacity(0.3) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday && !isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var calendarDates: [Date] {
        // Get the first day of the current month being displayed
        let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        // Get the last day of the current month being displayed
        let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: endOfMonth)?.end ?? endOfMonth
        
        // Generate all dates in the range (6 weeks to ensure we have complete rows)
        var dates: [Date] = []
        var currentDate = startOfWeek
        
        while currentDate < endOfWeek {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    private var upcomingEventsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                let selectedDateEvents = eventService.getEventsForDate(selectedDate)
                Text(selectedDateEvents.isEmpty ? "Upcoming Events" : "Events on \(dateFormatter.string(from: selectedDate))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            let selectedDateEvents = eventService.getEventsForDate(selectedDate)
            let upcomingEvents = eventService.getUpcomingEvents(limit: 5)
            
            // Show events for selected date if any, otherwise show upcoming events
            let eventsToShow = selectedDateEvents.isEmpty ? upcomingEvents : selectedDateEvents
            
            if eventsToShow.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No upcoming events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Schedule events from the Explore tab to see them here")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(eventsToShow) { event in
                        UpcomingEventCard(event: event)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Upcoming Event Card
struct UpcomingEventCard: View {
    let event: ScheduledEvent
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(event.category == "restaurant" ? Color.blue : Color.purple)
                    .frame(width: 40, height: 40)
                
                Image(systemName: event.categoryIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(event.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(event.displayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(event.displayTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

#Preview {
    CalendarView()
}
