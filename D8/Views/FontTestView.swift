//
//  FontTestView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct FontTestView: View {
    @State private var availableFonts: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Test Nexa Fonts
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nexa Font Test")
                            .font(.nexa(.heavy, size: 24))
                            .foregroundColor(.primary)
                        
                        Text("Heavy - D8 App Title")
                            .font(.nexa(.heavy, size: 20))
                            .foregroundColor(.blue)
                        
                        Text("Bold - Section Headers")
                            .font(.nexa(.bold, size: 18))
                            .foregroundColor(.green)
                        
                        Text("Regular - Body Text")
                            .font(.nexa(.regular, size: 16))
                            .foregroundColor(.primary)
                        
                        Text("Light - Subtle Text")
                            .font(.nexa(.light, size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Available Fonts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Fonts")
                            .font(.nexa(.bold, size: 18))
                            .foregroundColor(.primary)
                        
                        if availableFonts.isEmpty {
                            Text("Tap 'Load Fonts' to see available fonts")
                                .font(.nexa(.regular, size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(availableFonts.filter { $0.contains("Nexa") }, id: \.self) { font in
                                Text("✅ \(font)")
                                    .font(.nexa(.regular, size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button("Load Fonts") {
                            loadAvailableFonts()
                        }
                        .font(.nexa(.bold, size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color("Seaweed"))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Font Test")
            .onAppear {
                loadAvailableFonts()
            }
        }
    }
    
    private func loadAvailableFonts() {
        var fonts: [String] = []
        for family in UIFont.familyNames.sorted() {
            for name in UIFont.fontNames(forFamilyName: family) {
                fonts.append(name)
            }
        }
        availableFonts = fonts
    }
}

#Preview {
    FontTestView()
}
