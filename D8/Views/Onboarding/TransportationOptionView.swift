import SwiftUI

struct TransportationOptionView: View {
    @Binding var selectedTransportation: Set<TransportationOption>
    @State private var showContent = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("How do you prefer to get around?")
                        .font(.nexa(.bold, size: 28))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.top, 100)
                .padding(.bottom, 60)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(TransportationOption.allCases.enumerated()), id: \.element) { index, transportation in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedTransportation.contains(transportation) {
                                    selectedTransportation.remove(transportation)
                                } else {
                                    selectedTransportation.insert(transportation)
                                }
                            }
                        }) {
                            Text(transportation.displayName)
                                .font(.nexa(.regular, size: 18))
                                .foregroundColor(selectedTransportation.contains(transportation) ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            selectedTransportation.contains(transportation) ? 
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
                                                    selectedTransportation.contains(transportation) ? 
                                                    Color.clear :
                                                    Color.gray.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(
                                            color: selectedTransportation.contains(transportation) ? Color("Seaweed").opacity(0.4) : Color.clear,
                                            radius: selectedTransportation.contains(transportation) ? 6 : 0,
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
                                        selectedTransportation.count >= 1 ? 
                                        Color("Seaweed") :
                                        Color.gray.opacity(0.4)
                                    )
                            )
                    }
                    .disabled(selectedTransportation.count < 1)
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
