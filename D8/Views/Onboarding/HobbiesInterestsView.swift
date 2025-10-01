import SwiftUI

enum HobbyInterest: String, CaseIterable {
    case music = "music"
    case sports = "sports"
    case art = "art"
    case cooking = "cooking"
    case reading = "reading"
    case photography = "photography"
    case travel = "travel"
    case fitness = "fitness"
    case gaming = "gaming"
    case movies = "movies"
    case dancing = "dancing"
    case hiking = "hiking"
    case writing = "writing"
    case gardening = "gardening"
    case technology = "technology"
    case fashion = "fashion"
    case animals = "animals"
    case meditation = "meditation"
    case volunteering = "volunteering"
    case crafts = "crafts"
    
    var displayName: String {
        switch self {
        case .music: return "Music"
        case .sports: return "Sports"
        case .art: return "Art"
        case .cooking: return "Cooking"
        case .reading: return "Reading"
        case .photography: return "Photography"
        case .travel: return "Travel"
        case .fitness: return "Fitness"
        case .gaming: return "Gaming"
        case .movies: return "Movies"
        case .dancing: return "Dancing"
        case .hiking: return "Hiking"
        case .writing: return "Writing"
        case .gardening: return "Gardening"
        case .technology: return "Technology"
        case .fashion: return "Fashion"
        case .animals: return "Animals"
        case .meditation: return "Meditation"
        case .volunteering: return "Volunteering"
        case .crafts: return "Crafts"
        }
    }
}

struct HobbiesInterestsView: View {
    @Binding var selectedHobbies: Set<HobbyInterest>
    @State private var showContent = false
    
    let onNext: () -> Void
    let onBack: () -> Void
    
    private var filteredHobbies: [HobbyInterest] {
        HobbyInterest.allCases
    }
    
    var body: some View {
        ZStack {
            // Full screen overlay
            Color.clear
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("What are you into?")
                        .font(.nexa(.bold, size: 28))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.top, 100)
                .padding(.bottom, 60)
                
                // Hobbies Grid - Simple
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredHobbies, id: \.self) { hobby in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedHobbies.contains(hobby) {
                                    selectedHobbies.remove(hobby)
                                } else {
                                    selectedHobbies.insert(hobby)
                                }
                            }
                        }) {
                            Text(hobby.displayName)
                                .font(.nexa(.regular, size: 16))
                                    .foregroundColor(selectedHobbies.contains(hobby) ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(
                                                selectedHobbies.contains(hobby) ? 
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
                                                        selectedHobbies.contains(hobby) ? 
                                                        Color.clear :
                                                        Color.gray.opacity(0.3),
                                                        lineWidth: 1
                                                    )
                                            )
                                            .shadow(
                                                color: selectedHobbies.contains(hobby) ? Color("Seaweed").opacity(0.4) : Color.clear,
                                                radius: selectedHobbies.contains(hobby) ? 4 : 0,
                                                x: 0,
                                                y: 2
                                            )
                                    )
                        }
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
                                        selectedHobbies.count >= 3 ?
                                        Color("Seaweed") :
                                        Color.gray.opacity(0.4)
                                    )
                            )
                    }
                    .disabled(selectedHobbies.count < 3)
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


