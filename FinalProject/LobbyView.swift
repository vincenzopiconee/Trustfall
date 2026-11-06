//
//  LobbyView.swift
//  FinalProject
//
//  Updated with difficulty selection, mute functionality and BACKGROUND MUSIC STOPPED
//

import SwiftUI
import GameKit

struct LobbyView: View {
    @ObservedObject var gkManager = GameKitManager.shared
    @ObservedObject private var voiceManager = AgoraVoiceManager.shared
    @ObservedObject private var voiceChannelManager = VoiceChannelManager.shared
    @ObservedObject private var musicManager = BackgroundMusicManager.shared // ✅ NEW: Access to music manager
    
    @State private var showInviteSheet = false
    @State private var showCharacterSelection = false
    @State private var showExitConfirmation = false
    @State private var isInitializingVoice = false
    @State private var voiceError: String?
    @State private var showVoiceErrorAlert = false
    @State private var voiceSetupAttempts = 0
    @State private var lastVoiceSetupTime: Date?
    
    // ✅ NEW: Difficulty state
    @State private var selectedDifficulty: GameDifficulty = .normal

    var body: some View {
        ZStack {
            BrutalistLobbyView(
                players: makePlayersArray(),
                maxPlayers: 3,
                onInvitePlayer: shouldShowInviteButton ? { showInviteSheet = true } : nil,
                onSelectCharacter: { _ in
                    showCharacterSelection = true
                },
                onStart: canStartGame ? {
                    startGameWithUnifiedVoice()
                } : nil,
                onBack: {
                    showExitConfirmation = true
                },
                canStartGame: canStartGame,
                shouldShowStartButton: gkManager.isHost && gkManager.players.count == 3,
                startButtonMessage: getStartButtonMessage(),
                selectedDifficulty: selectedDifficulty, // ✅ Pass difficulty
                onDifficultyChanged: { difficulty in     // ✅ Handle difficulty changes
                    selectedDifficulty = difficulty
                    if gkManager.isHost {
                        gkManager.sendDifficultyToOthers(difficulty)
                    }
                }
            )
            .sheet(isPresented: $showInviteSheet) {
                GameCenterInviteView(
                    minPlayers: 3,
                    maxPlayers: 3,
                    isPresented: $showInviteSheet
                )
            }
            
            if showCharacterSelection {
                BrutalistCharacterSelectionView(
                    onCharacterConfirmed: { characterName in
                        gkManager.selectCharacter(characterName)
                        showCharacterSelection = false
                    },
                    onExit: {
                        showCharacterSelection = false
                    },
                    selectedCharacterNames: gkManager.getSelectedCharacterNames()
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
            
            UnifiedExitAlert(isPresented: $showExitConfirmation) {
                cleanupAndExit()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCharacterSelection)
        .alert("Voice Connection Error", isPresented: $showVoiceErrorAlert) {
            Button("Retry") {
                retryVoiceConnection()
            }
            Button("Continue Without Voice") {
                gkManager.startGame()
            }
        } message: {
            Text(voiceError ?? "Failed to connect to voice chat")
        }
        .onAppear {
            print("🏠 Lobby appeared with \(gkManager.players.count) players")
            
            // ✅ NEW: Stop background music when entering lobby
            stopBackgroundMusicForLobby()
            
            setupUnifiedVoiceConnection()
        }
        .onDisappear {
            // ✅ NEW: Restart background music when leaving lobby (if going back to menu)
            if !gkManager.gameStarted {
                restartBackgroundMusicForMenu()
            }
        }
        .onChange(of: gkManager.players.count) { oldCount, newCount in
            print("👥 Players count changed: \(oldCount) -> \(newCount)")
            if newCount >= 2 && !voiceManager.isJoined && !isInitializingVoice {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    setupUnifiedVoiceConnection()
                }
            }
        }
        .onChange(of: voiceManager.connectionState) { oldState, newState in
            print("🔗 Lobby - Voice connection state: \(oldState.rawValue) -> \(newState.rawValue)")
            
            if newState == .failed && voiceSetupAttempts < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    retryVoiceConnection()
                }
            }
        }
        .onChange(of: voiceManager.isJoined) { oldValue, newValue in
            print("📡 Lobby - Voice joined: \(oldValue) -> \(newValue)")
            if newValue {
                isInitializingVoice = false
                voiceError = nil
            }
        }
        // ✅ NEW: Listen for difficulty changes from host
        .onReceive(NotificationCenter.default.publisher(for: .difficultyChanged)) { notification in
            if let difficulty = notification.object as? GameDifficulty {
                selectedDifficulty = difficulty
                print("📡 Received difficulty change: \(difficulty.rawValue)")
            }
        }
    }

    // MARK: - ✅ NEW: Background Music Management for Lobby
    
    private func stopBackgroundMusicForLobby() {
        guard musicManager.isMusicEnabled else { return }
        
        do {
            musicManager.stopBackgroundMusic()
            print("🔇 Background music stopped for lobby mode")
        } catch {
            print("⚠️ Error stopping background music for lobby: \(error)")
        }
    }
    
    private func restartBackgroundMusicForMenu() {
        guard musicManager.isMusicEnabled else { return }
        
        // Small delay to ensure we're really going back to menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.gkManager.inLobby && !self.gkManager.gameStarted {
                do {
                    self.musicManager.playBackgroundMusic(filename: "menu_background_music", fileType: "wav")
                    print("🎵 Background music restarted for main menu")
                } catch {
                    print("⚠️ Error restarting background music: \(error)")
                }
            }
        }
    }

    // MARK: - Computed Properties
    
    private var shouldShowInviteButton: Bool {
        return gkManager.isHost && gkManager.players.count < 3
    }
    
    private var canStartGame: Bool {
        return gkManager.isHost &&
               gkManager.players.count == 3 &&
               gkManager.allPlayersHaveCharacters() &&
               !isInitializingVoice
    }
    
    private func getStartButtonMessage() -> String? {
        guard gkManager.isHost && gkManager.players.count == 3 else { return nil }
        
        if !gkManager.allPlayersHaveCharacters() {
            return "Select character to Start Game"
        }
        
        if isInitializingVoice {
            return "Voice chat connection in progress..."
        }
        
        return nil
    }
    
    private var voiceConnectionStatus: String {
        if isInitializingVoice {
            return "Connecting..."
        } else if voiceManager.isJoined {
            return "Voice Ready"
        } else {
            return "Voice Disconnected"
        }
    }
    
    // MARK: - UNIFIED Voice Connection Methods
    
    private func setupUnifiedVoiceConnection() {
        let now = Date()
        if let lastSetup = lastVoiceSetupTime, now.timeIntervalSince(lastSetup) < 5.0 {
            print("⚠️ Skipping voice setup - too soon since last attempt")
            return
        }
        
        guard !isInitializingVoice else {
            print("⚠️ Voice initialization already in progress")
            return
        }
        
        guard gkManager.players.count >= 2 else {
            print("⚠️ Not enough players for voice chat")
            return
        }
        
        guard let channelId = gkManager.getVoiceChannelId() else {
            print("❌ No voice channel ID available")
            return
        }
        
        lastVoiceSetupTime = now
        voiceSetupAttempts += 1
        isInitializingVoice = true
        voiceError = nil
        
        print("🎤 Setting up UNIFIED voice connection (attempt \(voiceSetupAttempts)) for channel: \(channelId)")
        print("   This channel will be used for both LOBBY and GAME modes")
        
        voiceChannelManager.joinVoiceChannel(channelId: channelId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if voiceManager.isJoined {
                print("✅ Unified voice channel joined successfully")
                print("   Mode: LOBBY (open mic for general chat)")
                isInitializingVoice = false
            } else {
                print("❌ Failed to join unified voice channel")
                isInitializingVoice = false
                
                if voiceSetupAttempts < 3 {
                    voiceError = "Could not connect to voice chat. Attempting retry \(voiceSetupAttempts + 1)/3..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        setupUnifiedVoiceConnection()
                    }
                } else {
                    voiceError = "Could not connect to voice chat after 3 attempts. Please check your internet connection."
                    showVoiceErrorAlert = true
                }
            }
        }
    }
    
    private func retryVoiceConnection() {
        print("🔄 Retrying unified voice connection...")
        voiceSetupAttempts = 0
        
        voiceChannelManager.leaveAllChannels()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            setupUnifiedVoiceConnection()
        }
    }
    
    private func startGameWithUnifiedVoice() {
        guard canStartGame else { return }
        
        print("🎮 Starting game with UNIFIED voice system and difficulty: \(selectedDifficulty.rawValue)")
        
        // ✅ Set the game duration based on selected difficulty
        SharedGameStateManager.shared.setGameDuration(selectedDifficulty.timeInSeconds)
        
        if voiceManager.isJoined {
            print("✅ Starting game - voice will transition from LOBBY to GAME mode")
            print("   Same channel, different configuration (push-to-talk)")
            gkManager.startGame()
        } else if voiceSetupAttempts >= 3 {
            print("⚠️ Starting game without voice chat after failed attempts")
            voiceError = "Voice chat could not be established. Do you want to start the game anyway?"
            showVoiceErrorAlert = true
        } else {
            print("⚠️ Voice chat still connecting, please wait...")
            setupUnifiedVoiceConnection()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !voiceManager.isJoined {
                    voiceError = "Voice chat is taking longer than expected. Start anyway?"
                    showVoiceErrorAlert = true
                }
            }
        }
    }
    
    private func cleanupAndExit() {
        print("🚪 Exiting lobby...")
        
        voiceChannelManager.leaveAllChannels()
        
        isInitializingVoice = false
        voiceSetupAttempts = 0
        lastVoiceSetupTime = nil
        
        // ✅ NEW: Restart background music when exiting lobby to menu
        restartBackgroundMusicForMenu()
        
        gkManager.exitGame()
    }
    
    // MARK: - Player Array Helper

    private func makePlayersArray() -> [Player] {
        return gkManager.players.map { gkPlayer in
            let characterName = gkManager.selectedCharacters[gkPlayer.gamePlayerID]
            let icon = "person.fill"
            let role = gkManager.assignedRoles[gkPlayer.gamePlayerID]
            
            return Player(
                name: characterName ?? "NO CHARACTER",
                gameCenterName: gkPlayer.displayName,
                isCurrentUser: gkPlayer.gamePlayerID == GKLocalPlayer.local.gamePlayerID,
                icon: icon,
                characterName: characterName,
                role: role
            )
        }
    }
}

// ✅ NEW: Notification extension for difficulty changes
extension Notification.Name {
    static let difficultyChanged = Notification.Name("difficultyChanged")
}

#Preview {
    LobbyView()
}
