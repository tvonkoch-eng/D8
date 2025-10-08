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
        NavigationView {
            ZStack {
                // Main content area
                Group {
                    ExploreView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Tab bar positioned at bottom
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab) {
                        showingDateFlow = true
                    }
                    .ignoresSafeArea(.all, edges: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                
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
                                            Color("Seaweed")
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
            .sheet(isPresented: $showingDateFlow) {
                CombinedDateFlowView()
                    .presentationDetents([.fraction(0.6)])
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Ensure proper navigation behavior
    }
}
