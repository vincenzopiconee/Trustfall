import SwiftUI

struct Character: Identifiable {
    let id = UUID()
    let name: String
    var takenByPlayer: String? = nil // Name of player who took this character
}

struct BrutalistCharacterSelectionView: View {
    // Sample data with some characters already taken
    @State var characters: [Character] = [
        Character(name: "Anna"),
        Character(name: "Mandy"),
        Character(name: "Betty"),
        Character(name: "Erik"),
        Character(name: "Marvin"),
        Character(name: "Andrea")
    ]
    
    @State private var currentIndex: Int = 0
    @State private var selectedCharacter: Character?
    @State private var isCharacterSelected: Bool = false
    @State private var isSelectionConfirmed: Bool = false
    @State private var playerName: String = "You"
    
    // Callbacks for integration with GameKit
    let onCharacterConfirmed: ((String) -> Void)?
    let onExit: (() -> Void)?
    
    // New: Get already selected characters from GameKit
    let selectedCharacterNames: Set<String>
    
    init(onCharacterConfirmed: ((String) -> Void)? = nil,
         onExit: (() -> Void)? = nil,
         selectedCharacterNames: Set<String> = []) {
        self.onCharacterConfirmed = onCharacterConfirmed
        self.onExit = onExit
        self.selectedCharacterNames = selectedCharacterNames
    }
    
    // Card size constants - calculated based on screen size
    private func cardSize(for geometry: GeometryProxy) -> CGFloat {
        let isLandscape = geometry.size.width > geometry.size.height
        return isLandscape ?
            min(geometry.size.height * 0.65, geometry.size.width * 0.25) :
            min(geometry.size.width * 0.7, geometry.size.height * 0.35)
    }
    
    // Check if character is already taken by another player
    private func isCharacterTaken(_ character: Character) -> Bool {
        return selectedCharacterNames.contains(character.name)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Header with Exit button and Title
                    HStack {
                        Button(action: {
                            onExit?()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                Text("EXIT")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    // Title
                    Text("CHOOSE YOUR CHARACTER")
                        .font(.system(size: min(geometry.size.width * 0.035, 28), weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // Card carousel
                    ScrollViewReader { scrollView in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 25) {
                                ForEach(0..<characters.count, id: \.self) { index in
                                    let character = characters[index]
                                    let isTaken = isCharacterTaken(character)
                                    
                                    characterCard(for: character,
                                                  size: cardSize(for: geometry),
                                                  isSelected: selectedCharacter?.id == character.id,
                                                  isTaken: isTaken)
                                    .id(index)
                                    .onTapGesture {
                                        // Prevent selection if already confirmed or character is taken
                                        if !isSelectionConfirmed && !isTaken {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedCharacter = character
                                                isCharacterSelected = true
                                                currentIndex = index
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                        }
                        .onChange(of: currentIndex) {
                            withAnimation {
                                scrollView.scrollTo(currentIndex, anchor: .center)
                            }
                        }
                    }
                    
                    // Navigation controls
                    HStack(spacing: 40) {
                        // Confirm selection button
                        Button(action: {
                            guard let selectedCharacter = selectedCharacter else { return }
                            
                            // Update character as taken by current player
                            if let index = characters.firstIndex(where: { $0.id == selectedCharacter.id }) {
                                characters[index].takenByPlayer = playerName
                            }
                            
                            // Lock the selection
                            isSelectionConfirmed = true
                            
                            // Call the callback with selected character name
                            onCharacterConfirmed?(selectedCharacter.name)
                            
                            print("Selected and confirmed: \(selectedCharacter.name)")
                        }) {
                            ZStack {
                                Rectangle()
                                    .fill(isCharacterSelected ? Color.white : Color.gray.opacity(0.5))
                                    .frame(width: 120, height: 44)
                                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                                
                                Text("CONFIRM")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                            }
                        }
                        .disabled(!isCharacterSelected || isSelectionConfirmed)
                        .opacity((isCharacterSelected && !isSelectionConfirmed) ? 1.0 : 0.5)
                        .padding(.top, -10)
                    }
                    .padding(.bottom, 25)
                }
            }
        }
        .onAppear {
            // Update characters state with already selected ones
            updateCharactersWithSelected()
        }
    }
    
    // Update characters to mark already selected ones as taken
    private func updateCharactersWithSelected() {
        for index in characters.indices {
            if selectedCharacterNames.contains(characters[index].name) {
                characters[index].takenByPlayer = "OTHER PLAYER"
            }
        }
    }
    
    // Character card view
    private func characterCard(for character: Character, size: CGFloat, isSelected: Bool?, isTaken: Bool) -> some View {
        ZStack {
            // Card background with brutalist effect
            Rectangle()
                .fill(Color.white)
                .frame(width: size, height: size)
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: isSelected == true ? 5 : 2)
                )
                .offset(x: -3, y: -3)
                .opacity(isTaken ? 0.6 : 1.0)
            
            Rectangle()
                .fill(Color.black)
                .frame(width: size, height: size)
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: isSelected == true ? 5 : 2)
                )
                .opacity(isTaken ? 0.6 : 1.0)
            
            // Character content
            VStack(spacing: 15) {
                // Character image
                Image(character.name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.7, height: size * 0.7)
                    .clipped()
                    .saturation(isTaken ? 0.3 : 1.0) // Desaturate taken characters
                
                // Character name plate with brutalist effect
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 40)
                    
                    Text(character.name.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .frame(width: size * 0.85)
            }
            .padding(.bottom, 10)
            .opacity(isTaken ? 0.7 : 1.0)
            
            // Selection indicator for current user's selection
            if isSelected == true {
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: size + 10, height: size + 10)
                
                // Selected text badge
                Text("SELECTED")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .rotationEffect(Angle(degrees: -45))
                    .position(x: size * 0.15, y: size * 0.15)
            }
            
            // Taken indicator
            if isTaken {
                // Visual "TAKEN" overlay
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: size, height: size)
                
                // Show "TAKEN" indicator
                VStack {
                    Text("TAKEN")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.white)
                        .border(Color.white, width: 2)
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .border(Color.white, width: 2)
                .rotationEffect(Angle(degrees: -10))
            }
            
            // Overlay to prevent further selection after confirmation
            if isSelectionConfirmed && !isTaken && isSelected != true {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: size, height: size)
            }
        }
        .shadow(color: isSelected == true ? (.white.opacity(0.2)) : .clear, radius: 10)
    }
}

// Previews
struct BrutalistCharacterSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BrutalistCharacterSelectionView(selectedCharacterNames: ["Anna", "Erik"])
                .previewDisplayName("Portrait")
            
            BrutalistCharacterSelectionView(selectedCharacterNames: ["Mandy"])
                .previewInterfaceOrientation(.landscapeLeft)
                .previewDisplayName("Landscape")
        }
    }
}
