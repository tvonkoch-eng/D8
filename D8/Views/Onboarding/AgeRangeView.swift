import SwiftUI

struct AgeRangeView: View {
    @Binding var selectedAgeRange: AgeRange?
    @State private var showContent = false
    
    let onNext: () -> Void
    
    var body: some View {
        ZStack {
            // Full screen overlay
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("What's your age?")
                        .font(.nexa(.bold, size: 28))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.top, 100)
                .padding(.bottom, 80)
                
                // Age Range Options - Simple Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(AgeRange.allCases.enumerated()), id: \.element) { index, ageRange in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedAgeRange = ageRange
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        selectedAgeRange == ageRange ? 
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
                                                selectedAgeRange == ageRange ? 
                                                Color.clear :
                                                Color.gray.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(
                                        color: selectedAgeRange == ageRange ? Color("Seaweed").opacity(0.4) : Color.clear,
                                        radius: selectedAgeRange == ageRange ? 6 : 0,
                                        x: 0,
                                        y: 3
                                    )
                                
                                Text(ageRange.displayName)
                                    .font(.nexa(.regular, size: 18))
                                    .foregroundColor(selectedAgeRange == ageRange ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.1), value: showContent)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Skip Button - Below age options
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
                
                // Next Button - Moved down
                Button(action: onNext) {
                    Text("Continue")
                        .font(.nexa(.bold, size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    selectedAgeRange != nil ? 
                                    Color("Seaweed") :
                                    Color.gray.opacity(0.4)
                                )
                        )
                }
                .disabled(selectedAgeRange == nil)
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


#Preview {
    AgeRangeView(selectedAgeRange: .constant(nil)) {
        print("Next tapped")
    }
}
