//
//  RelationshipStatusView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

enum RelationshipStatus: String, CaseIterable {
    case dating = "dating"
    case inRelationship = "in_relationship"
    case married = "married"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .dating: return "Dating"
        case .inRelationship: return "In Relationship"
        case .married: return "Married"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
    
    var icon: String {
        switch self {
        case .dating: return "heart"
        case .inRelationship: return "heart.fill"
        case .married: return "heart.fill"
        case .preferNotToSay: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .dating: return .blue
        case .inRelationship: return .pink
        case .married: return .red
        case .preferNotToSay: return .gray
        }
    }
}

struct RelationshipStatusView: View {
    @Binding var selectedStatus: RelationshipStatus?
    @State private var isAnimating = false
    @State private var showContent = false

    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ZStack {
            // Full screen overlay
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("What's your status?")
                        .font(.nexa(.bold, size: 28))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.top, 100)
                .padding(.bottom, 80)
                
                // Relationship Status Options - Simple Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(RelationshipStatus.allCases.enumerated()), id: \.element) { index, status in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedStatus = status
                            }
                        }) {
                            Text(status.displayName)
                                .font(.nexa(.regular, size: 18))
                                .foregroundColor(selectedStatus == status ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            selectedStatus == status ? 
                                            LinearGradient(
                                                colors: [Color("Seaweed"), Color("Seaweed").opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [Color.white, Color.white],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(
                                                    selectedStatus == status ? 
                                                    Color.clear :
                                                    Color.gray.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(
                                            color: selectedStatus == status ? Color("Seaweed").opacity(0.4) : Color.clear,
                                            radius: selectedStatus == status ? 6 : 0,
                                            x: 0,
                                            y: 3
                                        )
                                )
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: showContent)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                
                // Skip Button
                Button(action: onNext) {
                    Text("Skip")
                        .font(.nexa(.regular, size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .underline()
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                
                // Bottom Navigation
                HStack(spacing: 16) {
                    // Back Button
                    Button(action: onBack) {
                        Text("Back")
                            .font(.nexa(.regular, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Next Button
                    Button(action: onNext) {
                        Text("Continue")
                            .font(.nexa(.bold, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(
                                        selectedStatus != nil ? 
                                        Color("Seaweed") :
                                        Color.gray.opacity(0.4)
                                    )
                            )
                    }
                    .disabled(selectedStatus == nil)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 100)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    showContent = true
                }
            }
        }
    }
}

