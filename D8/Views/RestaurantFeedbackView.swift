//
//  RestaurantFeedbackView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct RestaurantFeedbackView: View {
    let restaurant: RestaurantRecommendation
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 0
    @State private var feedback: String = ""
    @State private var wasVisited: Bool = false
    @State private var selectedAspects: Set<FeedbackAspect> = []
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("How was your experience?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(restaurant.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Star rating
                    VStack(spacing: 12) {
                        Text("Rate your experience")
                            .font(.headline)
                        
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.title)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            rating = Double(star)
                                        }
                                    }
                            }
                        }
                    }
                    
                    // Visit status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Did you visit this restaurant?")
                            .font(.headline)
                        
                        Toggle("Yes, I visited this restaurant", isOn: $wasVisited)
                            .toggleStyle(SwitchToggleStyle())
                    }
                    
                    // Feedback aspects
                    if wasVisited {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What did you think about?")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(FeedbackAspect.allCases, id: \.self) { aspect in
                                    FeedbackAspectChip(
                                        aspect: aspect,
                                        isSelected: selectedAspects.contains(aspect)
                                    ) {
                                        if selectedAspects.contains(aspect) {
                                            selectedAspects.remove(aspect)
                                        } else {
                                            selectedAspects.insert(aspect)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Text feedback
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional feedback")
                            .font(.headline)
                        
                        TextField("Tell us more about your experience...", text: $feedback, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                    
                    // Submit button
                    Button(action: submitFeedback) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Feedback")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting || rating == 0)
                    .opacity(rating == 0 ? 0.6 : 1.0)
                }
                .padding()
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitFeedback() {
        guard rating > 0 else { return }
        
        isSubmitting = true
        
        let feedbackData = FeedbackData(
            userId: getCurrentUserId(),
            restaurantId: restaurant.id.uuidString,
            restaurantName: restaurant.name,
            rating: rating,
            feedback: feedback.isEmpty ? nil : feedback,
            wasVisited: wasVisited,
            visitDate: wasVisited ? Date() : nil,
            recommendationId: nil,
            timestamp: Date(),
            feedbackAspects: selectedAspects.map { $0.rawValue }
        )
        
        Task {
            do {
                try await FirebaseService.shared.submitFeedback(feedbackData)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error submitting feedback: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
        }
    }
    
    private func getCurrentUserId() -> String {
        // For now, use a placeholder. You can implement proper auth later
        return "user_\(UUID().uuidString)"
    }
}

struct FeedbackAspectChip: View {
    let aspect: FeedbackAspect
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(aspect.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}
