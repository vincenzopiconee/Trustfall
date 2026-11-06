//
//  BlindCombinedGameView.swift
//  FinalProject
//
//  SIMPLIFIED: Removed random sound system - using fixed sequence mapping
//

import SwiftUI
import AVFoundation

struct BlindCombinedGameView: View {
    // Audio state directly in View
    @State private var isPlaying: Bool = false
    @State private var currentAmplitude: Double = 0.0
    @State private var sequenceProgress: Double = 0.0
    @State private var soundSequence: [String] = []
    @State private var audioPlayers: [AVAudioPlayer] = []
    @State private var currentSoundIndex: Int = 0
    @State private var sequenceTimer: Timer?
    @State private var amplitudeTimer: Timer?
    
    // Audio session management state
    @State private var audioSessionConfigured: Bool = false
    @State private var lastButtonPress: Date?
    
    // Game state
    @State private var showExitAlert = false
    @ObservedObject private var gkManager = GameKitManager.shared
    @ObservedObject private var voiceManager = AgoraVoiceManager.shared
    @ObservedObject private var sharedGameState = SharedGameStateManager.shared
    @State private var showInfoAlert = true
    
    // Fixed sequence mapping - Yellow -> Green -> Red -> Blue
    private let fixedSoundSequence: [String] = ["alieno", "ufo", "uovo", "occhio"]
    
    private let gapDuration: TimeInterval = 1.5
    private let soundDuration: TimeInterval = 5.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                HStack(spacing: 20) {
                    // Left side - Walkie Talkie
                    VStack {
                        if let channelId = gkManager.lobbyVoiceChannelId {
                            BlindWalkieTalkieView(geometry: geometry, channelId: channelId)
                        } else {
                            // Placeholder se non c'è channel
                            VStack {
                                Text("WAITING FOR\nVOICE CHANNEL...")
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            .frame(width: geometry.size.width * 0.25, height: geometry.size.height * 0.6)
                            .background(Color.gray.opacity(0.3))
                            .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                    .frame(width: geometry.size.width * 0.25)
                    
                    // Right side - Blind Game
                    VStack {
                        if !sharedGameState.shouldShowGameResult {
                            BlindGameSection(geometry: geometry)
                        }
                    }
                    .frame(width: geometry.size.width * 0.74)
                }
                
                // Game Result Overlay globale
                if sharedGameState.shouldShowGameResult {
                    GameResultOverlay(
                        isWon: sharedGameState.isGameWon,
                        errorCount: sharedGameState.totalErrors,
                        onRestart: {
                            print("🎮 LUMO: Waiting for complete restart by ECHO...")
                            // LUMO doesn't do anything local, waits for the complete system reset
                        },
                        onExit: {
                            GameKitManager.shared.exitGameAndNotifyOthers()
                        }
                    )
                    .padding(.bottom)
                }
                
                // Exit button
                if !sharedGameState.shouldShowGameResult {
                    VStack {
                        HStack {
                            Button(action: { showExitAlert = true }) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(width: 100, height: 35)
                                        .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                                    HStack(spacing: 4) {
                                        Text("EXIT")
                                            .font(.system(size: 12, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        Spacer()
                    }
                }
                
                UnifiedExitAlert(isPresented: $showExitAlert) {
                    gkManager.exitGame()
                    VoiceChannelManager.shared.leaveAllChannels()
                    AgoraVoiceManager.shared.destroyInstance()
                }
                
                if showInfoAlert {
                    BrutalistAlert(alertType: .blind) {
                        showInfoAlert = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
            
            print("🎮 LUMO appeared - using lobby voice channel: \(gkManager.lobbyVoiceChannelId ?? "nil")")
            print("🔊 Fixed sound sequence: \(fixedSoundSequence)")
            
            // Setup audio session immediately on appear
            setupAudioSessionForBlindPlayer()
            
            // Setup observers
            setupBatteryPlacedObserver()
            setupErrorSoundObserver()
            
            // Configure audio for LUMO player
            setupBlindAudioConfiguration()
            
            // Initialize fixed sound sequence
            initializeFixedSoundSequence()
        }
        .onDisappear {
            cleanupAudioResources()
            NotificationCenter.default.removeObserver(self, name: .batteryPlacedCorrectly, object: nil)
            NotificationCenter.default.removeObserver(self, name: .errorSoundTriggered, object: nil)
        }
    }
    
    // MARK: - Audio Session Setup for Real Devices
    private func setupAudioSessionForBlindPlayer() {
        guard !audioSessionConfigured else {
            print("🔊 LUMO: Audio session already configured")
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use .playAndRecord for better device compatibility
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers
            ])
            
            // Set preferred sample rate and buffer duration
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            try audioSession.setActive(true)
            
            audioSessionConfigured = true
            print("✅ LUMO: Audio session configured successfully for real device")
            
        } catch {
            print("❌ LUMO: Failed to configure audio session: \(error)")
            audioSessionConfigured = false
        }
    }
    
    // MARK: - BlindGameSection View
    @ViewBuilder
    private func BlindGameSection(geometry: GeometryProxy) -> some View {
        GeometryReader { sectionGeometry in
            ZStack {
                Image("Artwork5")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                VStack(spacing: 9) {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Text("SOUND SEQUENCE")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Circle()
                            .fill(isPlaying ? Color.green : Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .scaleEffect(isPlaying ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: isPlaying)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                        Text("FIXED SEQUENCE READY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: 23) {
                        // Make the waveform area tappable with better hit testing
                        ZStack {
                            SoundSequenceView(
                                isPlaying: isPlaying,
                                amplitude: currentAmplitude,
                                progress: sequenceProgress
                            )
                            
                            // Invisible overlay for better touch detection
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 220, height: 140)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handlePlayButtonPress()
                                }
                        }
                        
                        HStack(spacing: 15) {
                            // Improved PLAY button with debouncing
                            Button(action: {
                                handlePlayButtonPress()
                            }) {
                                Text(isPlaying ? "STOP" : "PLAY")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundColor(isPlaying ? .white : .black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(isPlaying ? Color.black : Color.white)
                                    .overlay(Rectangle().stroke(isPlaying ? Color.white : Color.black, lineWidth: 3))
                            }
                            .disabled(!audioSessionConfigured)
                            .opacity(audioSessionConfigured ? 1.0 : 0.5)
                            .scaleEffect(isPlaying ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isPlaying)
                            
                            // Improved RESET button
                            Button(action: {
                                handleResetButtonPress()
                            }) {
                                Text("RESET")
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                            }
                            .disabled(!audioSessionConfigured)
                            .opacity(audioSessionConfigured ? 1.0 : 0.5)
                        }
                        /*
                        // Debug info for troubleshooting
                        #if DEBUG
                        VStack(spacing: 4) {
                            Text("Debug: Audio Session: \(audioSessionConfigured ? "✅" : "❌")")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("Players: \(audioPlayers.count), Sounds: \(soundSequence.count)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            
                            if !soundSequence.isEmpty {
                                Text("Sequence: \(soundSequence.joined(separator: " → "))")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        #endif
                        */
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Button Handlers with Debouncing
    private func handlePlayButtonPress() {
        // Debounce rapid button presses
        let now = Date()
        if let lastPress = lastButtonPress, now.timeIntervalSince(lastPress) < 0.5 {
            print("🎮 LUMO: Button press debounced")
            return
        }
        lastButtonPress = now
        
        guard audioSessionConfigured else {
            print("⚠️ LUMO: Cannot play - audio session not ready")
            return
        }
        
        // Provide haptic feedback on real devices
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🎮 LUMO: Play button pressed - toggling sequence")
        toggleSequence()
    }
    
    private func handleResetButtonPress() {
        // Debounce rapid button presses
        let now = Date()
        if let lastPress = lastButtonPress, now.timeIntervalSince(lastPress) < 0.5 {
            print("🎮 LUMO: Reset button press debounced")
            return
        }
        lastButtonPress = now
        
        guard audioSessionConfigured else {
            print("⚠️ LUMO: Cannot reset - not ready")
            return
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("🎮 LUMO: Reset button pressed")
        resetSequence()
    }
    
    // MARK: - Audio Management Functions
    
    private func setupBlindAudioConfiguration() {
        print("🔇 LUMO player - configuring audio for sound sequence playback")
        
        // Set very low background music volume for LUMO
        if gkManager.currentPlayerRole == .blind {
            BackgroundMusicManager.shared.setVolume(0.05)
            print("🔇 LUMO player - background music volume reduced")
        }
    }
    
    // Initialize fixed sound sequence
    private func initializeFixedSoundSequence() {
        soundSequence = fixedSoundSequence
        print("🔄 LUMO: Initialized with fixed sound sequence: \(soundSequence.joined(separator: " → "))")
        
        resetSequence()
        loadAudioFilesForCurrentSequence()
    }
    
    private func loadAudioFilesForCurrentSequence() {
        // Ensure audio session is ready before loading files
        guard audioSessionConfigured else {
            print("⚠️ LUMO: Cannot load audio files - session not configured")
            setupAudioSessionForBlindPlayer()
            
            // Retry after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadAudioFilesForCurrentSequence()
            }
            return
        }
        
        audioPlayers.removeAll()
        
        // Stop and cleanup any existing audio
        stopSequence()
        
        for fileName in soundSequence {
            loadAudioFile(fileName: fileName)
        }
        
        print("🔊 LUMO: Loaded \(audioPlayers.count) audio files for fixed sequence")
    }
    
    private func loadAudioFile(fileName: String) {
        // Try both mp3 and wav extensions
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") ??
                       Bundle.main.url(forResource: fileName, withExtension: "wav") else {
            print("❌ Could not find audio file: \(fileName)")
            return
        }
        
        do {
            // Create player with improved configuration for real devices
            let player = try AVAudioPlayer(contentsOf: url)
            
            // Set audio session category for each player
            player.volume = 1.0
            player.numberOfLoops = 0
            player.enableRate = false
            
            // Prepare player immediately
            let prepared = player.prepareToPlay()
            if !prepared {
                print("⚠️ Failed to prepare audio player for \(fileName)")
            }
            
            audioPlayers.append(player)
            print("🔊 LUMO: Loaded audio file: \(fileName) (prepared: \(prepared))")
            
        } catch {
            print("❌ Error loading audio file \(fileName): \(error)")
        }
    }
    
    private func toggleSequence() {
        guard !soundSequence.isEmpty else {
            print("⚠️ LUMO: Cannot play - sound sequence not available")
            return
        }
        
        guard audioSessionConfigured else {
            print("⚠️ LUMO: Cannot play - audio session not configured")
            setupAudioSessionForBlindPlayer()
            return
        }
        
        if isPlaying {
            stopSequence()
        } else {
            playSequence()
        }
    }
    
    private func playSequence() {
        guard !audioPlayers.isEmpty && !soundSequence.isEmpty else {
            print("⚠️ LUMO: Cannot play - no audio files or empty sequence")
            return
        }
        
        guard audioSessionConfigured else {
            print("⚠️ LUMO: Cannot play - audio session not ready")
            setupAudioSessionForBlindPlayer()
            return
        }
        
        // Reactivate audio session before playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
            print("🔊 LUMO: Audio session reactivated for playback")
        } catch {
            print("❌ LUMO: Failed to reactivate audio session: \(error)")
            return
        }
        
        // Duck background music
        BackgroundMusicManager.shared.handleBlindPlayerSequenceStart()
        
        isPlaying = true
        currentSoundIndex = 0
        sequenceProgress = 0.0
        
        startAmplitudeAnimation()
        playNextInSequence()
        
        print("▶️ LUMO: Started playing fixed sequence: \(soundSequence.joined(separator: " → "))")
    }
    
    private func playNextInSequence() {
        guard currentSoundIndex < audioPlayers.count && currentSoundIndex < soundSequence.count else {
            // Loop the sequence
            currentSoundIndex = 0
            sequenceProgress = 0.0
            if isPlaying {
                playNextInSequence()
            }
            return
        }
        
        let player = audioPlayers[currentSoundIndex]
        let soundName = soundSequence[currentSoundIndex]
        
        // Ensure audio session is still active
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
        } catch {
            print("❌ LUMO: Error maintaining audio session: \(error)")
        }
        
        // Stop and prepare player properly
        player.stop()
        player.currentTime = 0
        let prepared = player.prepareToPlay()
        
        if !prepared {
            print("⚠️ LUMO: Failed to prepare player for \(soundName)")
        }
        
        player.volume = 1.0
        
        let success = player.play()
        
        if success {
            print("🔊 LUMO: Playing sound \(currentSoundIndex + 1)/\(soundSequence.count): \(soundName)")
        } else {
            print("❌ LUMO: Failed to play sound: \(soundName)")
            
            // Try to recover by reloading the audio file
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadAudioFile(fileName: soundName)
                if self.currentSoundIndex < self.audioPlayers.count {
                    let recoveredPlayer = self.audioPlayers[self.currentSoundIndex]
                    _ = recoveredPlayer.play()
                    print("🔄 LUMO: Recovered and playing \(soundName)")
                }
            }
        }
        
        let totalSteps = Double(soundSequence.count)
        sequenceProgress = Double(currentSoundIndex) / totalSteps
        
        let totalDuration = soundDuration + gapDuration
        sequenceTimer = Timer.scheduledTimer(withTimeInterval: totalDuration, repeats: false) { _ in
            self.currentSoundIndex += 1
            if self.isPlaying {
                self.playNextInSequence()
            }
        }
    }
    
    private func stopSequence() {
        isPlaying = false
        currentAmplitude = 0.0
        
        // Stop all audio players
        audioPlayers.forEach { player in
            player.stop()
            player.currentTime = 0
            _ = player.prepareToPlay()
        }
        
        sequenceTimer?.invalidate()
        sequenceTimer = nil
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        
        // Restore background music
        BackgroundMusicManager.shared.handleBlindPlayerSequenceEnd()
        
        print("⏹️ LUMO: Stopped sequence playback")
    }
    
    private func resetSequence() {
        stopSequence()
        sequenceProgress = 0.0
        currentSoundIndex = 0
        
        // Properly reset all players
        audioPlayers.forEach { player in
            player.stop()
            player.currentTime = 0
            _ = player.prepareToPlay()
        }
        
        print("🔄 LUMO: Reset sequence playback")
    }
    
    private func startAmplitudeAnimation() {
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if self.isPlaying {
                let baseAmplitude = 0.4
                let variation = Double.random(in: 0.0...0.6)
                self.currentAmplitude = baseAmplitude + variation
            }
        }
    }
    
    private func cleanupAudioResources() {
        stopSequence()
        audioPlayers.removeAll()
        
        // Properly deactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionConfigured = false
            print("🔊 LUMO: Audio session deactivated")
        } catch {
            print("⚠️ LUMO: Error deactivating audio session: \(error)")
        }
        
        // Restore background music when leaving LUMO view
        if gkManager.currentPlayerRole == .blind {
            BackgroundMusicManager.shared.setVolume(0.3)
            print("🔊 Leaving LUMO view - background music volume restored")
        }
    }
    
    // MARK: - Observer Setup
    
    private func setupErrorSoundObserver() {
        NotificationCenter.default.addObserver(
            forName: .errorSoundTriggered,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let errorCount = userInfo["errorCount"] as? Int,
               let errorType = userInfo["errorType"] as? String {
                
                print("🔊 LUMO received error sound: Error \(errorCount) (\(errorType))")
                ErrorSoundManager.shared.playErrorSound(errorCount: errorCount, errorType: errorType)
            }
        }
    }
    
    private func setupBatteryPlacedObserver() {
        NotificationCenter.default.addObserver(
            forName: .batteryPlacedCorrectly,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let slotNumber = userInfo["slotNumber"] as? Int,
               let currentProgress = userInfo["currentProgress"] as? Int,
               let totalSteps = userInfo["totalSteps"] as? Int,
               let colorName = userInfo["colorName"] as? String {
                
                print("🎵 LUMO received battery placed: Slot \(slotNumber), \(colorName), Progress: \(currentProgress)/\(totalSteps)")
                
                self.playMuteStyleSuccessSound(for: slotNumber)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.playProgressBeeps(count: currentProgress)
                }
            }
        }
    }
    
    // MARK: - Audio Feedback Functions
    
    private func playMuteStyleSuccessSound(for slotNumber: Int) {
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: audioFormat)
        
        let sampleRate = audioFormat.sampleRate
        let duration = 0.8
        let length = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: length)!
        buffer.frameLength = length
        
        let samples = buffer.floatChannelData![0]
        
        let baseFrequencies: [Double] = [
            261.63, // C4 per slot 1
            329.63, // E4 per slot 2
            392.00, // G4 per slot 3
            523.25  // C5 per slot 4
        ]
        
        let frequency = baseFrequencies[min(slotNumber - 1, baseFrequencies.count - 1)]
        
        for i in 0..<Int(length) {
            let time = Double(i) / sampleRate
            let envelope = max(0, 1.0 - (time / duration))
            
            let fundamental = sin(2.0 * Double.pi * frequency * time)
            let harmonic2 = sin(2.0 * Double.pi * frequency * 2.0 * time) * 0.3
            let harmonic3 = sin(2.0 * Double.pi * frequency * 3.0 * time) * 0.2
            
            let sample = (fundamental + harmonic2 + harmonic3) * envelope * 0.4
            samples[i] = Float(sample)
        }
        
        do {
            try audioEngine.start()
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            playerNode.play()
            
            print("🔊 LUMO playing ECHO-style success sound for slot \(slotNumber) (frequency: \(frequency) Hz)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
                audioEngine.stop()
            }
        } catch {
            print("❌ Error playing ECHO-style success sound for LUMO: \(error)")
        }
    }
    
    private func playProgressBeeps(count: Int) {
        guard count > 0 else { return }
        
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.outputNode, format: audioFormat)
        
        let sampleRate = audioFormat.sampleRate
        let beepDuration = 0.2
        let pauseDuration = 0.15
        let totalDuration = Double(count) * (beepDuration + pauseDuration)
        
        let length = AVAudioFrameCount(sampleRate * totalDuration)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: length)!
        buffer.frameLength = length
        
        let samples = buffer.floatChannelData![0]
        let frequency = 800.0
        
        var currentSample = 0
        
        for beep in 0..<count {
            let beepSamples = Int(sampleRate * beepDuration)
            for i in 0..<beepSamples {
                if currentSample < Int(length) {
                    let time = Double(i) / sampleRate
                    let envelope = sin(Double.pi * time / beepDuration)
                    let sample = sin(2.0 * Double.pi * frequency * time) * envelope * 0.4
                    samples[currentSample] = Float(sample)
                    currentSample += 1
                }
            }
            
            if beep < count - 1 {
                let pauseSamples = Int(sampleRate * pauseDuration)
                for _ in 0..<pauseSamples {
                    if currentSample < Int(length) {
                        samples[currentSample] = 0.0
                        currentSample += 1
                    }
                }
            }
        }
        
        do {
            try audioEngine.start()
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            playerNode.play()
            
            print("🎵 LUMO playing progress beeps: \(count) beeps")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.1) {
                audioEngine.stop()
            }
        } catch {
            print("❌ Error playing progress beeps for LUMO: \(error)")
        }
    }
}

// MARK: - SoundSequenceView (unchanged)

struct SoundSequenceView: View {
    let isPlaying: Bool
    let amplitude: Double
    let progress: Double

    @State private var waveOffset: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 3))

                WaveShape(
                    amplitude: isPlaying ? amplitude * 25 : 5,
                    frequency: 3.0,
                    phase: waveOffset
                )
                .stroke(Color.white, lineWidth: 2)
                .animation(.easeInOut(duration: 0.1), value: amplitude)

                VStack {
                    Spacer()
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geo.size.width * progress, height: 4)

                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: geo.size.width * (1.0 - progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
            .frame(width: 220, height: 140)
            .background(Color.white.opacity(0.05))

            Text("TAP TO PLAY/PAUSE SEQUENCE")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
            
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            if isPlaying {
                waveOffset += 0.3
            }
        }
    }
}

struct WaveShape: Shape {
    var amplitude: Double
    var frequency: Double
    var phase: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2
        
        path.move(to: CGPoint(x: 0, y: midHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX * frequency * 2 * .pi) + phase)
            let y = midHeight + (sine * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

#Preview {
    BlindCombinedGameView()
        .environment(\.locale, .init(identifier: "es"))
}
