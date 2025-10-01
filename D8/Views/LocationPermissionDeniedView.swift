//
//  LocationPermissionDeniedView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct LocationPermissionDeniedView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var isRequestingPermission = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "location.slash")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 16) {
                    Text("Location Permission Required")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("This app needs your location to suggest dates in your area. Please enable location access and set it to 'While Using App' to continue.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Text("To enable location access:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Open Settings")
                        }
                        HStack {
                            Text("2.")
                                .fontWeight(.bold)
                            Text("Find and tap \"D8\"")
                        }
                        HStack {
                            Text("3.")
                                .fontWeight(.bold)
                            Text("Tap \"Location\"")
                        }
                        HStack {
                            Text("4.")
                                .fontWeight(.bold)
                            Text("Select \"While Using App\" (not \"When Shared\")")
                        }
                    }
                    .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Add a button to request permission if it hasn't been requested yet
                if locationManager.authorizationStatus == .notDetermined {
                    Button(action: requestPermission) {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isRequestingPermission ? "Requesting..." : "Grant Location Access")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRequestingPermission)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Location Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func requestPermission() {
        isRequestingPermission = true
        locationManager.requestLocationPermission { granted in
            DispatchQueue.main.async {
                isRequestingPermission = false
                if granted {
                    dismiss()
                }
            }
        }
    }
}
