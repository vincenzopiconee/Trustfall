//
//  UnifiedWalkieTalkieView.swift - VERSIONE COMPLETA CON AUDIO FIXES + ROLE NAMES CORRECTED + ERROR SOUNDS
//
//  COMPLETELY FIXED: Proper audio management and reliable voice handling + CORRECTED ROLE NAMES + ERROR SOUNDS
//

import SwiftUI
import AVFoundation
import GameKit

// MARK: - Unified WalkieTalkie Component
struct UnifiedWalkieTalkieView: View {
    let geometry: GeometryProxy
    let playerRole: PlayerRole
    let showTalkButton: Bool
    let imageAsset: String
    let timerPosition: CGPoint
    let errorsPosition: CGPoint
    let talkButtonPosition: CGPoint?
    let roleIndicatorPosition: CGPoint
    let testButtonsPosition: CGPoint?
    let channelId: String
    
    @State private var isPressed = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var hasConnectedToChannel = false
    @State private var connectionAttempts = 0
    @State private var lastConnectionAttempt: Date?
    
    @ObservedObject private var voiceManager = AgoraVoiceManager.shared
    @ObservedObject private var voiceChannelManager = VoiceChannelManager.shared
    @ObservedObject private var sharedGameState = SharedGameStateManager.shared
    
    // ✅ FIXED: Mapping corretto dei ruoli
    private var roleData: String {
        switch playerRole {
        case .blind: return "LUMO"    // BLIND = LUMO
        case .deaf: return "VIBE"     // DEAF = VIBE
        case .mute: return "ECHO"     // MUTE = ECHO
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Walkie-talkie background image
                Image(imageAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // ✅ Timer display
                Text(sharedGameState.timeString)
                    .font(.system(size: min(geo.size.width * 30, 30), weight: .black, design: .monospaced))
                    .foregroundColor(sharedGameState.timeRemaining <= 10 ? .red : .black)
                    .position(timerPosition)
                
                // Error indicators
                HStack(spacing: geo.size.width * 0.03) {
                    ForEach(0..<3, id: \.self) { index in
                        Text(index < sharedGameState.totalErrors ? "X" : "")
                            .font(.system(size: min(geo.size.width * 90, 35), weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                            .frame(width: geo.size.width * 0.2, height: geo.size.width * 2)
                    }
                }
                .position(errorsPosition)
                
                // ✅ FIXED: TALK button (Push-to-Talk in game mode)
                if showTalkButton, let talkPos = talkButtonPosition {
                    Button(action: {}) {
                        Text("TALK")
                            .font(.system(size: min(geo.size.width * 2, 16), weight: .black, design: .monospaced))
                            .foregroundColor(isPressed ? .white : .black)
                            .frame(width: geo.size.width * 4, height: geo.size.width * 0.4)
                            .background(
                                Circle()
                                    .fill(isPressed ? Color.black : Color.clear)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            )
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressed && canTalk {
                                    playTalkSound()
                                    let success = voiceChannelManager.startTalking(role: playerRole)
                                    if success {
                                        isPressed = true
                                        print("🎤 \(roleData) started talking (push-to-talk)")
                                    }
                                }
                            }
                            .onEnded { _ in
                                if isPressed {
                                    voiceChannelManager.stopTalking(role: playerRole)
                                    isPressed = false
                                    print("🎤 \(roleData) stopped talking (push-to-talk)")
                                }
                            }
                    )
                    .position(talkPos)
                    .disabled(!canTalk)
                    .opacity(canTalk ? 1.0 : 0.5)
                }
            }
        }
        .onAppear {
            print("🎮 \(roleData) walkie-talkie appeared for unified channel: \(channelId)")
            setupUnifiedVoiceForGame()
            
            // Solo ECHO (MUTE) avvia il master timer
            if playerRole == .mute {
                sharedGameState.startGame()
            }
            
            // ✅ NUOVO: Setup observer per suoni di errore
            setupErrorSoundObserver()
        }
        .onDisappear {
            print("🎮 \(roleData) walkie-talkie disappeared")
            cleanup()
            
            // ✅ NUOVO: Rimuovi observer
            NotificationCenter.default.removeObserver(self, name: .errorSoundTriggered, object: nil)
        }
        .onChange(of: voiceManager.connectionState) { oldState, newState in
            print("🔗 \(roleData) voice connection state: \(oldState.rawValue) -> \(newState.rawValue)")
            
            // Handle connection failures
            if newState == .failed && connectionAttempts < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    retryConnection()
                }
            }
        }
        .onChange(of: voiceManager.isJoined) { oldValue, newValue in
            print("📡 \(roleData) voice joined status: \(oldValue) -> \(newValue)")
            if newValue && !hasConnectedToChannel {
                hasConnectedToChannel = true
                print("✅ \(roleData) successfully connected to unified voice channel")
                
                // Transition to game mode after connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.voiceChannelManager.transitionToGame(playerRole: self.playerRole)
                }
            } else if !newValue && hasConnectedToChannel {
                // Connection lost
                hasConnectedToChannel = false
                print("❌ \(roleData) lost connection to voice channel")
            }
        }
        .onChange(of: voiceManager.remoteUsers.count) { oldCount, newCount in
            print("👥 \(roleData) remote users count: \(oldCount) -> \(newCount)")
        }
        .onChange(of: voiceChannelManager.isInGame) { oldValue, newValue in
            print("🎮 \(roleData) game mode: \(oldValue) -> \(newValue)")
        }
        // Timer sound effects
        .onChange(of: sharedGameState.timeRemaining) { oldTime, newTime in
            // Warning beep negli ultimi 10 secondi
            if newTime <= 10 && newTime > 0 && oldTime != newTime {
                playWarningBeep()
            }
            
            // Beep ogni minuto
            if newTime % 60 == 0 && newTime > 0 && newTime < 600 {
                playMinuteBeep()
            }
        }
    }
    
    // ✅ NUOVO: Setup observer per suoni di errore
    private func setupErrorSoundObserver() {
        NotificationCenter.default.addObserver(
            forName: .errorSoundTriggered,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let errorCount = userInfo["errorCount"] as? Int,
               let errorType = userInfo["errorType"] as? String {
                
                print("🔊 \(self.roleData) received error sound: Error \(errorCount) (\(errorType))")
                ErrorSoundManager.shared.playErrorSound(errorCount: errorCount, errorType: errorType)
            }
        }
    }
    
    // MARK: - ✅ FIXED: Voice Connection Properties
    private var canTalk: Bool {
        return voiceManager.isJoined &&
               voiceChannelManager.isInGame &&
               voiceChannelManager.canTalk &&
               !voiceChannelManager.isInCutscene
    }
    
    private var currentModeColor: Color {
        if voiceChannelManager.isInCutscene {
            return .purple
        } else if voiceChannelManager.isInGame {
            return .orange
        } else if voiceChannelManager.isInLobby {
            return .blue
        } else {
            return .gray
        }
    }
    
    // MARK: - ✅ IMPROVED: Voice Connection Color
    private var voiceConnectionColor: Color {
        if !voiceManager.isJoined {
            return .red // Not connected
        }
        
        if voiceChannelManager.isInCutscene {
            return .purple // Cutscene mode (all muted)
        }
        
        if voiceChannelManager.isInLobby {
            return voiceChannelManager.isLocalAudioMuted ? .orange : .blue // Lobby mode
        }
        
        if voiceChannelManager.isInGame {
            switch playerRole {
            case .blind, .deaf:
                return isPressed ? .green : .orange // Green when talking, orange when listening
            case .mute:
                return .green // Always green for MUTE (can only listen)
            }
        }
        
        return .gray
    }
    
    // MARK: - ✅ FIXED: UNIFIED Voice Setup for Game
    private func setupUnifiedVoiceForGame() {
        let now = Date()
        if let lastAttempt = lastConnectionAttempt, now.timeIntervalSince(lastAttempt) < 5.0 {
            print("⚠️ \(roleData) skipping connection - too soon since last attempt")
            return
        }
        
        guard !hasConnectedToChannel else {
            print("⚠️ \(roleData) already connected to unified channel")
            return
        }
        
        lastConnectionAttempt = now
        connectionAttempts += 1
        
        print("🎤 \(roleData) setting up UNIFIED voice (attempt \(connectionAttempts)) in channel: \(channelId)")
        print("   This is the same channel used in lobby, transitioning to game mode")
        
        // Check if already connected to the same unified channel
        if voiceChannelManager.currentChannelId == channelId && voiceManager.isJoined {
            print("✅ \(roleData) already connected to unified channel - transitioning to game mode")
            voiceChannelManager.transitionToGame(playerRole: playerRole)
            hasConnectedToChannel = true
        } else if voiceChannelManager.currentChannelId != channelId {
            print("⚠️ \(roleData) not connected to expected unified channel")
            print("   Expected: \(channelId)")
            print("   Current: \(voiceChannelManager.currentChannelId)")
            
            // Join the unified channel
            voiceChannelManager.joinVoiceChannel(channelId: channelId)
            
            // Wait for connection, then transition to game mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if self.voiceManager.isJoined {
                    self.voiceChannelManager.transitionToGame(playerRole: self.playerRole)
                    self.hasConnectedToChannel = true
                    print("✅ \(self.roleData) connected and configured for game mode")
                } else if self.connectionAttempts < 3 {
                    print("❌ \(self.roleData) connection failed, will retry...")
                } else {
                    print("❌ \(self.roleData) max connection attempts reached")
                }
            }
        }
    }
    
    private func retryConnection() {
        guard connectionAttempts < 3 else {
            print("❌ \(roleData) max retry attempts reached")
            return
        }
        
        print("🔄 \(roleData) retrying voice connection...")
        hasConnectedToChannel = false
        
        // Use the VoiceChannelManager's reconnection method
        voiceChannelManager.reconnectCurrentChannel(playerRole: playerRole)
        
        // Set up monitoring for the retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.voiceManager.isJoined {
                self.hasConnectedToChannel = true
                print("✅ \(self.roleData) retry successful")
            } else {
                print("❌ \(self.roleData) retry failed")
            }
        }
    }
    
    private func cleanup() {
        print("🧹 Cleaning up \(roleData) voice connection")
        
        // Solo ECHO (MUTE) ferma il master timer
        if playerRole == .mute {
            sharedGameState.stopGame()
        }
        
        // Reset local state only
        hasConnectedToChannel = false
        connectionAttempts = 0
        lastConnectionAttempt = nil
        isPressed = false
    }
    
    // MARK: - Audio Functions
    private func playWarningBeep() {
        playBeep(frequency: 1200, duration: 0.3, volume: 0.5)
    }
    
    private func playMinuteBeep() {
        playBeep(frequency: 800, duration: 0.2, volume: 0.3)
    }
    
    private func playTalkSound() {
        // Double beep for talk button
        playBeep(frequency: 800, duration: 0.1, volume: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.playBeep(frequency: 900, duration: 0.1, volume: 0.4)
        }
    }
    
    private func playBeep(frequency: Double, duration: Double, volume: Float) {
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: audioFormat)
        
        let sampleRate = audioFormat.sampleRate
        let length = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: length)!
        buffer.frameLength = length
        
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(length) {
            let time = Double(i) / sampleRate
            let envelope = max(0, 1.0 - (time / duration))
            let sample = sin(2.0 * Double.pi * frequency * time) * envelope
            samples[i] = Float(sample * Double(volume))
        }
        
        do {
            try audioEngine.start()
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            playerNode.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                audioEngine.stop()
            }
        } catch {
            print("❌ Error playing beep: \(error)")
        }
    }
}

// MARK: - ✅ COMPLETE: Component Views
struct BlindWalkieTalkieView: View {
    let geometry: GeometryProxy
    let channelId: String
    
    var body: some View {
        UnifiedWalkieTalkieView(
            geometry: geometry,
            playerRole: .blind,
            showTalkButton: true,
            imageAsset: "artwork_walkietalkie",
            timerPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.4),
            errorsPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.545),
            talkButtonPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.75),
            roleIndicatorPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.88),
            testButtonsPosition: nil,
            channelId: channelId
        )
    }
}

struct DeafWalkieTalkieView: View {
    let geometry: GeometryProxy
    let channelId: String?
    
    var body: some View {
        UnifiedWalkieTalkieView(
            geometry: geometry,
            playerRole: .deaf,
            showTalkButton: true,
            imageAsset: "artwork_walkietalkie",
            timerPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.4),
            errorsPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.545),
            talkButtonPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.75),
            roleIndicatorPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.88),
            testButtonsPosition: nil,
            channelId: channelId ?? "default-game-channel"
        )
    }
    
    init(geometry: GeometryProxy) {
        self.geometry = geometry
        self.channelId = nil
    }
    
    init(geometry: GeometryProxy, channelId: String) {
        self.geometry = geometry
        self.channelId = channelId
    }
}

struct MuteWalkieTalkieView: View {
    let geometry: GeometryProxy
    let channelId: String?
    
    var body: some View {
        UnifiedWalkieTalkieView(
            geometry: geometry,
            playerRole: .mute,
            showTalkButton: false, // Mute doesn't have TALK button
            imageAsset: "artwork_walkietalkie2",
            timerPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.4),
            errorsPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.545),
            talkButtonPosition: nil, // No TALK button for mute
            roleIndicatorPosition: CGPoint(x: geometry.size.width * 0.125, y: geometry.size.height * 0.88),
            testButtonsPosition: nil,
            channelId: channelId ?? "default-game-channel"
        )
    }
    
    init(geometry: GeometryProxy) {
        self.geometry = geometry
        self.channelId = nil
    }
    
    init(geometry: GeometryProxy, channelId: String) {
        self.geometry = geometry
        self.channelId = channelId
    }
}

// MARK: - ✅ COMPLETE: Preview Provider
struct UnifiedWalkieTalkieView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GeometryReader { geometry in
                DeafWalkieTalkieView(geometry: geometry, channelId: "test-channel")
            }
            .previewDisplayName("VIBE Player - Unified")
            .previewLayout(.fixed(width: 400, height: 600))
            
            GeometryReader { geometry in
                MuteWalkieTalkieView(geometry: geometry, channelId: "test-channel")
            }
            .previewDisplayName("ECHO Player - Unified")
            .previewLayout(.fixed(width: 400, height: 600))
            
            GeometryReader { geometry in
                BlindWalkieTalkieView(geometry: geometry, channelId: "test-channel")
            }
            .previewDisplayName("LUMO Player - Unified")
            .previewLayout(.fixed(width: 400, height: 600))
        }
    }
}
