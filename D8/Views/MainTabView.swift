//
//  MainTabView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0 // Default to Explore tab
    @State private var showingDateFlow = false
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        ExploreView()
                    case 2:
                        CalendarView()
                    default:
                        ExploreView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
//                Spacer()
                
                // Custom Tab Bar
                CustomTabBar(selectedTab: $selectedTab) {
                    showingDateFlow = true
                }
            }
            .ignoresSafeArea()
            
            // Floating Find Date Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingDateFlow = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
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
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                    .offset(y: -10) // Position above the curved indentation
                    Spacer()
                }
            }
        }
        .accentColor(Color(red: 0.0, green: 0.4, blue: 0.2)) // Dark green accent
        .fullScreenCover(isPresented: $showingDateFlow) {
            CombinedDateFlowView()
        }
    }
}
