//
//  OnboardingLaunchView.swift
//  D8
//
//  Created by Tobias Vonkoch on 9/2/25.
//

import SwiftUI

struct OnboardingLaunchView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var scaleEffect: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    let onStart: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            // Animated Background
            LinearGradient(
                colors: [
                    Color("Seaweed"),
                    Color("Seaweed").opacity(0.8),
                    Color("Seaweed").opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
                .overlay(
                    // Floating circles for visual interest
                    ZStack {
                        ForEach(0..<10, id: \.self) { index in
                            FloatingCircleView(
                                index: index,
                                isAnimating: isAnimating
                            )
                        }
                    }
                )
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Icon/Logo Area
                VStack(spacing: 24) {
                    // App Name
                    Text("D8")
                        .font(.nexa(.heavy, size: 48))
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    // Tagline
                    Text("Find your perfect date")
                        .font(.nexa(.regular, size: 20))
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Welcome Message
                VStack(spacing: 16) {
                    Text("Tell us about you")
                        .font(.nexa(.bold, size: 28))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(opacity)
                    
                    Text("Help us personalize your perfect date experiences")
                        .font(.nexa(.regular, size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Start Button
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        onStart()
                    }
                }) {
                    HStack(spacing: 12) {
                        Text("Get Started")
                            .font(.nexa(.bold, size: 18))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color("Seaweed"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                }
                .scaleEffect(scaleEffect)
                .opacity(opacity)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                scaleEffect = 1.0
                opacity = 1.0
                isAnimating = true
            }
        }
    }
}

struct FloatingCircleView: View {
    let index: Int
    let isAnimating: Bool
    
    @State private var position: CGPoint = .zero
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.1
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: circleSize, height: circleSize)
            .position(position)
            .scaleEffect(scale)
            .onAppear {
                setupInitialPosition()
                startAnimations()
            }
    }
    
    private var circleSize: CGFloat {
        switch index % 3 {
        case 0: return 60
        case 1: return 80
        default: return 100
        }
    }
    
    private func setupInitialPosition() {
        // Create more varied starting positions
        let x = CGFloat.random(in: -50...screenWidth + 50)
        let y = CGFloat.random(in: -50...screenHeight + 50)
        position = CGPoint(x: x, y: y)
        
        // Random initial scale and opacity
        scale = CGFloat.random(in: 0.5...1.2)
        opacity = Double.random(in: 0.05...0.15)
    }
    
    private func startAnimations() {
        // Create multiple overlapping animations for more organic movement
        animatePosition()
        animateScale()
        animateOpacity()
    }
    
    private func animatePosition() {
        let duration = Double.random(in: 8...15) // Much slower
        let delay = Double(index) * Double.random(in: 0.3...1.2)
        
        withAnimation(
            Animation.easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            // Create a more complex path with multiple waypoints
            let newX = CGFloat.random(in: -100...screenWidth + 100)
            let newY = CGFloat.random(in: -100...screenHeight + 100)
            position = CGPoint(x: newX, y: newY)
        }
        
        // Add a secondary position animation for more randomness
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.5) {
            withAnimation(
                Animation.easeInOut(duration: duration * 0.7)
                    .repeatForever(autoreverses: true)
            ) {
                let newX = CGFloat.random(in: -50...screenWidth + 50)
                let newY = CGFloat.random(in: -50...screenHeight + 50)
                position = CGPoint(x: newX, y: newY)
            }
        }
    }
    
    private func animateScale() {
        let duration = Double.random(in: 6...12)
        let delay = Double(index) * Double.random(in: 0.2...0.8)
        
        withAnimation(
            Animation.easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            scale = CGFloat.random(in: 0.3...1.5)
        }
    }
    
    private func animateOpacity() {
        let duration = Double.random(in: 4...8)
        let delay = Double(index) * Double.random(in: 0.1...0.6)
        
        withAnimation(
            Animation.easeInOut(duration: duration)
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            opacity = Double.random(in: 0.02...0.2)
        }
    }
}

#Preview {
    OnboardingLaunchView {
        print("Get Started tapped")
    }
}
