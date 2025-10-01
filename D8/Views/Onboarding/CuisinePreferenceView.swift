import SwiftUI

struct CuisinePreferenceView: View {
    @Binding var selectedCuisines: Set<CuisinePreference>
    @State private var showContent = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("What cuisines do you like?")
                            .font(.nexa(.bold, size: 28))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Select at least 3")
                            .font(.nexa(.regular, size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.top, 100)
                .padding(.bottom, 60)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(Array(CuisinePreference.allCases.enumerated()), id: \.element) { index, cuisine in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedCuisines.contains(cuisine) {
                                    selectedCuisines.remove(cuisine)
                                } else {
                                    selectedCuisines.insert(cuisine)
                                }
                            }
                        }) {
                            Text(cuisine.displayName)
                                .font(.nexa(.regular, size: cuisine.displayName.count > 10 ? 14 : 16))
                                .foregroundColor(selectedCuisines.contains(cuisine) ? .white : .primary)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            selectedCuisines.contains(cuisine) ? 
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
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    selectedCuisines.contains(cuisine) ? 
                                                    Color.clear :
                                                    Color.gray.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(
                                            color: selectedCuisines.contains(cuisine) ? Color("Seaweed").opacity(0.4) : Color.clear,
                                            radius: selectedCuisines.contains(cuisine) ? 4 : 0,
                                            x: 0,
                                            y: 2
                                        )
                                )
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.05), value: showContent)
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
                                        selectedCuisines.count >= 3 ? 
                                        Color("Seaweed") :
                                        Color.gray.opacity(0.4)
                                    )
                            )
                    }
                    .disabled(selectedCuisines.count < 3)
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
