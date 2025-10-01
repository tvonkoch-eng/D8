import SwiftUI

struct BudgetRangeView: View {
    @Binding var selectedBudget: BudgetRange?
    @State private var showContent = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Text("What's your budget range for dates?")
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
                    ForEach(Array(BudgetRange.allCases.enumerated()), id: \.element) { index, budget in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedBudget = budget
                            }
                        }) {
                            Text(budget.displayName)
                                .font(.nexa(.regular, size: 18))
                                .foregroundColor(selectedBudget == budget ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(
                                            selectedBudget == budget ? 
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
                                                    selectedBudget == budget ? 
                                                    Color.clear :
                                                    Color.gray.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(
                                            color: selectedBudget == budget ? Color("Seaweed").opacity(0.4) : Color.clear,
                                            radius: selectedBudget == budget ? 6 : 0,
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
                                        selectedBudget != nil ? 
                                        Color("Seaweed") :
                                        Color.gray.opacity(0.4)
                                    )
                            )
                    }
                    .disabled(selectedBudget == nil)
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
