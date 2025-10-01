//
//  FirebaseTestView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct FirebaseTestView: View {
    @State private var testResult = ""
    @State private var isTesting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase Test")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Test your Firebase connection")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: testFirebase) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isTesting ? "Testing..." : "Test Firebase Connection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isTesting)
            
            if !testResult.isEmpty {
                Text(testResult)
                    .font(.body)
                    .foregroundColor(testResult.contains("✅") ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func testFirebase() {
        isTesting = true
        testResult = ""
        
        Task {
            do {
                let result = try await FirebaseService.shared.testFirebaseConnection()
                await MainActor.run {
                    testResult = result
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ Firebase error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    FirebaseTestView()
}
