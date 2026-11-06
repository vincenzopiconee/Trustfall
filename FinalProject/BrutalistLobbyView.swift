//
//  BrutalistLobbyView.swift
//  FinalProject
//
//  FIXED: Mute button functionality and difficulty selection
//

import SwiftUI

struct BrutalistLobbyView: View {
    let players: [Player]
    let maxPlayers: Int
    let onInvitePlayer: (() -> Void)?
    let onSelectCharacter: ((String) -> Void)?
    let onStart: (() -> Void)?
    let onBack: (() -> Void)?
    let canStartGame: Bool
    let shouldShowStartButton: Bool
    let startButtonMessage: String?
    
    // ✅ NEW: Difficulty parameters
    let selectedDifficulty: GameDifficulty
    let onDifficultyChanged: (GameDifficulty) -> Void
    
    // ✅ FIXED: Mute state from VoiceChannelManager
    @State private var showDifficultySelector: Bool = false
    @State private var showProAlert: Bool = false
    @State private var hasProVersion: Bool = false
    
    @ObservedObject private var voiceManager = AgoraVoiceManager.shared
    @ObservedObject private var voiceChannelManager = VoiceChannelManager.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Back button and mute button at the top
                    HStack {
                        Button(action: {
                            onBack?()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                Text("BACK")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                        }
                        .padding(.top, 20)
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // ✅ FIXED: Mute button using VoiceChannelManager
                        Button(action: {
                            toggleMute()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: voiceChannelManager.isLocalAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text(voiceChannelManager.isLocalAudioMuted ? "UNMUTE" : "MUTE")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(voiceChannelManager.isLocalAudioMuted ? Color.red : Color.white)
                            .foregroundColor(voiceChannelManager.isLocalAudioMuted ? .white : .black)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                        }
                        .disabled(!voiceManager.isJoined)
                        .opacity(voiceManager.isJoined ? 1.0 : 0.5)
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                    }
                    
                    HStack(spacing: 20) {
                        // Left panel with lobby info and controls
                        VStack(alignment: .leading, spacing: 15) {
                            Text("LOBBY")
                                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.leading, 20)
                            
                            Text("PLAYERS: \(players.count)/\(maxPlayers)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 20)
                            
                            // ✅ Voice status indicator
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(voiceManager.isJoined ? .green : .red)
                                    .frame(width: 12, height: 12)
                                
                                Text(voiceStatusText)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(voiceManager.isJoined ? .green : .red)
                            }
                            .padding(.leading, 20)
                            
                            // ✅ NEW: Difficulty selector (only for host)
                            if GameKitManager.shared.isHost {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DIFFICULTY:")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.leading, 20)
                                    
                                    Button(action: {
                                        showDifficultySelector = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(selectedDifficulty.localized)
                                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.black)
                                                
                                                Text(selectedDifficulty.timeString)
                                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.black.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(selectedDifficulty.color)
                                        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                                    }
                                    .padding(.leading, 20)
                                }
                            } else {
                                // Show current difficulty for non-hosts
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DIFFICULTY:")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.leading, 20)
                                    
                                    HStack {
                                        Text(selectedDifficulty.localized)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.black)
                                        
                                        Text(selectedDifficulty.timeString)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(.black.opacity(0.7))
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(selectedDifficulty.color.opacity(0.7))
                                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                                    .padding(.leading, 20)
                                }
                            }
                                                        
                            // ✅ UPDATED: Pulsanti in basso affiancati e allungati
                            HStack(spacing: 12) {
                                // Invite Player button (left)
                                if let onInvitePlayer = onInvitePlayer {
                                    Button(action: onInvitePlayer) {
                                        Text("INVITE")
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .frame(minWidth: 140, maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 4)
                                            .background(Color.white)
                                            .foregroundColor(.black)
                                            .overlay(Rectangle().stroke(Color.black, lineWidth: 4))
                                    }
                                }
                                
                                // Start button (right)
                                if shouldShowStartButton {
                                    Button(action: {
                                        if canStartGame {
                                            startGameWithDifficulty()
                                        }
                                    }) {
                                        Text("START GAME")
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .frame(minWidth: 120, maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 4)
                                            .background(canStartGame ? Color.white : Color.gray.opacity(0.5))
                                            .foregroundColor(canStartGame ? .black : .black.opacity(0.6))
                                            .overlay(Rectangle().stroke(Color.black, lineWidth: 4))
                                    }
                                    .disabled(!canStartGame)
                                }
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 20)
                            
                            // Start button message (below buttons)
                            if shouldShowStartButton, let message = startButtonMessage {
                                Text(message)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .padding(.leading, 20)
                                    .padding(.trailing, 20)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(width: geometry.size.width * 0.4)
                        .padding(.bottom, 20)
                        // Right panel with player grid
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                                spacing: 12
                            ) {
                                // Show current players
                                ForEach(players) { player in
                                    PlayerCard(
                                        player: player,
                                        onTap: player.isCurrentUser ? {
                                            onSelectCharacter?(player.id.uuidString)
                                        } : nil
                                    )
                                }
                                
                                // Show empty slots
                                ForEach(0..<(maxPlayers - players.count), id: \.self) { _ in
                                    EmptyPlayerSlot()
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(width: geometry.size.width * 0.55)
                    }
                }
                
                // ✅ NEW: Difficulty selector overlay
                if showDifficultySelector {
                    DifficultySelector(
                        selectedDifficulty: selectedDifficulty,
                        isPresented: $showDifficultySelector,
                        hasProVersion: hasProVersion,
                        onDifficultySelected: { difficulty in
                            onDifficultyChanged(difficulty)
                            showDifficultySelector = false
                        },
                        onProAlert: {
                            showProAlert = true
                        }
                    )
                    .zIndex(100)
                }
            }
        }
        .alert("PRO VERSION REQUIRED", isPresented: $showProAlert) {
            Button("GET PRO") {
                purchaseProVersion()
            }
            Button("CANCEL", role: .cancel) {}
        } message: {
            Text("EXTREME difficulty is only available in the PRO version. Upgrade to unlock the ultimate 5-minute challenge!")
        }
        .onAppear {
            checkProVersion()
        }
    }
    
    // ✅ FIXED: Voice status text
    private var voiceStatusText: String {
        if !voiceManager.isJoined {
            return NSLocalizedString("Voice Disconnected", comment: "")
        } else if voiceChannelManager.isLocalAudioMuted {
            return NSLocalizedString("Voice Muted", comment: "")
        } else {
            return NSLocalizedString("Voice Connected", comment: "")
        }
    }
    
    // ✅ FIXED: Mute functionality using VoiceChannelManager
    private func toggleMute() {
        voiceChannelManager.toggleLocalAudioMute()
        print("🔄 Toggled lobby mute - Now: \(voiceChannelManager.isLocalAudioMuted ? "muted" : "unmuted")")
    }
    
    // ✅ NEW: Start game with selected difficulty
    private func startGameWithDifficulty() {
        print("🎮 Starting game with difficulty: \(selectedDifficulty.localized) (\(selectedDifficulty.timeString))")
        onStart?()
    }
    
    // ✅ NEW: Pro version check
    private func checkProVersion() {
        hasProVersion = UserDefaults.standard.bool(forKey: "hasProVersion")
    }
    
    // ✅ NEW: Purchase Pro version
    private func purchaseProVersion() {
        print("🛒 Initiating PRO version purchase...")
        
        // For demo purposes, we'll just set it to true
        // In real app, this would trigger StoreKit purchase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hasProVersion = true
            UserDefaults.standard.set(true, forKey: "hasProVersion")
            print("✅ PRO version purchased!")
        }
    }
}

// ✅ NEW: Difficulty Selector Component
struct DifficultySelector: View {
    let selectedDifficulty: GameDifficulty
    @Binding var isPresented: Bool
    let hasProVersion: Bool
    let onDifficultySelected: (GameDifficulty) -> Void
    let onProAlert: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            ScrollView {
                VStack(spacing: 20) {
                    Text("SELECT DIFFICULTY")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 150, height: 3)
                    
                    VStack(spacing: 12) {
                        ForEach(GameDifficulty.allCases, id: \.self) { difficulty in
                            DifficultyOption(
                                difficulty: difficulty,
                                isSelected: selectedDifficulty == difficulty,
                                onTap: {
                                    onDifficultySelected(difficulty)
                                }
                            )
                        }
                    }
                    
                    Button("CANCEL") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                }
                .padding(30)
                .background(Color.black)
                .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
                .frame(maxWidth: 400)
            }
            
        }
        .padding(.top)
        .padding(.bottom, 5)
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

// ✅ NEW: Difficulty Option Component
struct DifficultyOption: View {
    let difficulty: GameDifficulty
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(difficulty.localized)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                        
                        
                        
                        Spacer()
                        
                        Text(difficulty.timeString)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    
                    Text(difficulty.description)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.black.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(isSelected ? difficulty.color :
                Color.white.opacity(0.9)
            )
            .overlay(
                Rectangle().stroke(isSelected ? Color.black :
                    Color.gray,
                    lineWidth: isSelected ? 3 : 1
                )
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct PlayerCard: View {
    let player: Player
    let onTap: (() -> Void)?

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Rectangle()
                        .fill(player.isCurrentUser ? Color.white : Color.gray)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Rectangle().stroke(Color.white, lineWidth: player.isCurrentUser ? 3 : 1))
                    
                    if player.characterName != nil {
                        // Show character image if selected
                        Image(player.characterName!)
                            .resizable()
                            .scaledToFit()
                    } else {
                        // Show default icon
                        Image(systemName: player.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(player.isCurrentUser ? .black : .white)
                    }
                }
                .frame(height: 80)
                
                // Mostra sempre il nome di Game Center
                Text(player.gameCenterName)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                // Mostra il nome del personaggio se selezionato, altrimenti "NO CHARACTER"
                Text(player.characterName ?? NSLocalizedString("NO CHARACTER", comment: "") )
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(player.characterName != nil ? Color.white : Color.white)
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if player.isCurrentUser {
                    Text(player.characterName != nil ? "CHANGE" : "SELECT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .foregroundColor(.black)
                }
            }
            .padding(12)
            .background(
                ZStack {
                    Color.black
                    Color.white.opacity(0.1)
                }
            )
            .overlay(Rectangle().stroke(player.isCurrentUser ? Color.white : Color.white, lineWidth: player.isCurrentUser ? 2 : 1))
        }
        .disabled(onTap == nil)
    }
}

struct EmptyPlayerSlot: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 1))
                
                Image(systemName: "person.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.gray)
            }
            .frame(height: 80)
            
            Text("EMPTY")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            Text("SLOT")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray)
                .foregroundColor(.white)
            
            Spacer()
                .frame(height: 20)
        }
        .padding(12)
        .background(Color.black)
        .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
    }
}

#Preview {
    let players = [
        Player(name: "SARA", gameCenterName: "Sara_GC", isCurrentUser: true, icon: "person.fill"),
        Player(name: "MATILDE", gameCenterName: "Matilde_GC", isCurrentUser: false, icon: "person.fill")
    ]
    BrutalistLobbyView(
        players: players,
        maxPlayers: 3,
        onInvitePlayer: {},
        onSelectCharacter: { _ in },
        onStart: {},
        onBack: {},
        canStartGame: false,
        shouldShowStartButton: true,
        startButtonMessage: "Select character to START GAME",
        selectedDifficulty: .normal,
        onDifficultyChanged: { _ in }
    )
    .environment(\.locale, .init(identifier: "it"))
}
