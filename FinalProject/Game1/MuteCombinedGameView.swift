//
//  MuteCombinedGameView.swift
//  FinalProject
//
//  SIMPLIFIED: Removed random battery system and sounds - using fixed sequence
//

import SwiftUI
import AVFoundation

struct MuteCombinedGameView: View {
    // MuteGameOne states
    @State private var batteries: [Battery] = []
    @State private var slots: [BatterySlot] = []
    @State private var isDragging = false
    @State private var dragPosition = CGPoint.zero
    @State private var showExitAlert = false
    @State private var currentSequenceIndex = 0
    
    @ObservedObject private var gkManager = GameKitManager.shared
    @ObservedObject private var sharedGameState = SharedGameStateManager.shared
    
    @State private var showInfoAlert = true
    @State private var hasInitializedTimer = false
    
    // Fixed sequence: Yellow -> Green -> Red -> Blue (slots 1, 2, 3, 4)
    private let fixedBatterySequence: [Color] = [.yellow, .green, .red, .blue]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                HStack(spacing: 60) {
                    // Left side - WalkieTalkie
                    ZStack {
                        if let channelId = gkManager.lobbyVoiceChannelId {
                            MuteWalkieTalkieView(geometry: geometry, channelId: channelId)
                        } else {
                            // Placeholder se non c'è channel
                            VStack {
                                Text("SETTING UP\nVOICE CHANNEL...")
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
                    
                    // Right side - MuteGameOne
                    ZStack {
                        Image("minigioco1")
                            .resizable()
                            .padding(.top, 20)
                            .padding(.bottom, -10)
                            .padding(.leading, -30)
                            .padding(.trailing, -30)
                        
                        // Game content - nascosto solo se c'è un risultato globale
                        if !sharedGameState.shouldShowGameResult {
                            gameContent(geometry: geometry)
                        }
                    }
                    .frame(width: geometry.size.width * 0.65)
                }
                
                // Game Result Overlay globale
                if sharedGameState.shouldShowGameResult {
                    GameResultOverlay(
                        isWon: sharedGameState.isGameWon,
                        errorCount: sharedGameState.totalErrors,
                        onRestart: {
                            print("🎮 ECHO: Complete restart")
                            resetGame()
                        },
                        onExit: {
                            GameKitManager.shared.exitGameAndNotifyOthers()
                        }
                    )
                }
                
                // Exit button - nascosto quando c'è il game result overlay
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
                    GameKitManager.shared.exitGameAndNotifyOthers()
                }
                
                if showInfoAlert {
                    BrutalistAlert(alertType: .mute) {
                        showInfoAlert = false
                    }
                }
                
                UnifiedExitAlert(
                    playerName: gkManager.exitedPlayerName,
                    isPresented: $gkManager.showPlayerExitAlert
                ) {
                    gkManager.returnToMainMenu()
                }
            }
            .onAppear {
                setupGame(geometry: geometry)
                setupErrorSoundObserver()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .errorSoundTriggered, object: nil)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            initializeTimerSafely()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
            
            print("🎮 ECHO appeared - using lobby voice channel: \(gkManager.lobbyVoiceChannelId ?? "nil")")
            print("🔋 Fixed sequence: \(fixedBatterySequence.map { colorName($0) })")
        }
        .onDisappear {
            if gkManager.currentPlayerRole == .mute && hasInitializedTimer {
                print("🎮 ECHO disappearing - stopping master timer")
                sharedGameState.stopGame()
                hasInitializedTimer = false
            }
        }
    }
    
    private func setupErrorSoundObserver() {
        NotificationCenter.default.addObserver(
            forName: .errorSoundTriggered,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let errorCount = userInfo["errorCount"] as? Int,
               let errorType = userInfo["errorType"] as? String {
                
                print("🔊 ECHO received error sound: Error \(errorCount) (\(errorType))")
                ErrorSoundManager.shared.playErrorSound(errorCount: errorCount, errorType: errorType)
            }
        }
    }
    
    private func initializeTimerSafely() {
        guard gkManager.currentPlayerRole == .mute else {
            print("⚠️ Not ECHO role - not starting timer")
            return
        }
        
        guard !hasInitializedTimer else {
            print("⚠️ Timer already initialized by ECHO")
            return
        }
        
        guard sharedGameState.timeRemaining > 0 else {
            print("⚠️ Cannot start timer - time remaining is 0")
            return
        }
        
        guard !sharedGameState.isTimerRunning else {
            print("⚠️ Timer already running - not starting duplicate")
            return
        }
        
        print("🎮 ECHO initializing master timer with \(sharedGameState.timeRemaining) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.hasInitializedTimer && self.gkManager.currentPlayerRole == .mute {
                self.sharedGameState.startGame()
                self.hasInitializedTimer = true
                print("✅ ECHO successfully started master timer")
            }
        }
    }
    
    // MARK: - Game Content
    private func gameContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // Battery slots
            ForEach(slots) { slot in
                BatterySlotView(slot: slot)
            }
            
            // Batteries
            ForEach(batteries.indices, id: \.self) { index in
                BatteryView(battery: batteries[index])
                    .position(batteries[index].position)
                    .gesture(
                        batteries[index].isPlaced ? nil :
                        DragGesture()
                            .onChanged { value in
                                if !sharedGameState.shouldShowGameResult {
                                    batteries[index].position = value.location
                                    isDragging = true
                                    dragPosition = value.location
                                }
                            }
                            .onEnded { value in
                                if !sharedGameState.shouldShowGameResult {
                                    isDragging = false
                                    checkForSlotMatch(batteryIndex: index, location: value.location)
                                }
                            }
                    )
            }
            
            // Drag cursor
            if isDragging {
                Image("closedmano")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .position(dragPosition)
                    .allowsHitTesting(false)
                    .zIndex(1000)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Setup Functions
    private func setupGame(geometry: GeometryProxy) {
        let rightSideWidth = geometry.size.width * 0.65
        let rightSideHeight = geometry.size.height
        let centerX = rightSideWidth / 2 + 10
        let centerY = rightSideHeight / 2 + 34
        
        // Setup slots (sempre gli stessi)
        let slotSpacing: CGFloat = 5
        let totalSlotsWidth = (4 * 50) + (3 * slotSpacing)
        let startX = centerX - totalSlotsWidth / 2 + 25
        
        slots = [
            BatterySlot(id: 1, expectedColor: .yellow, position: CGPoint(x: startX, y: centerY)),
            BatterySlot(id: 2, expectedColor: .green, position: CGPoint(x: startX + 40 + slotSpacing, y: centerY)),
            BatterySlot(id: 3, expectedColor: .red, position: CGPoint(x: startX + (40 + slotSpacing) * 2, y: centerY)),
            BatterySlot(id: 4, expectedColor: .blue, position: CGPoint(x: startX + (40 + slotSpacing) * 3, y: centerY))
        ]
        
        // Setup batteries (posizioni sempre le stesse, corrispondenti ai loro slot)
        let batteryYStart = centerY - 100
        let batterySpacing: CGFloat = 160
        let sideOffset: CGFloat = 80
        
        batteries = [
            Battery(id: 1, name: "BATTERY_YELLOW", color: .yellow, position: CGPoint(x: centerX - sideOffset * 2.5, y: batteryYStart)),
            Battery(id: 2, name: "BATTERY_GREEN", color: .green, position: CGPoint(x: centerX - sideOffset * 2.5, y: batteryYStart + batterySpacing)),
            Battery(id: 3, name: "BATTERY_RED", color: .red, position: CGPoint(x: centerX + sideOffset * 2.5, y: batteryYStart)),
            Battery(id: 4, name: "BATTERY_BLUE", color: .blue, position: CGPoint(x: centerX + sideOffset * 2.5, y: batteryYStart + batterySpacing))
        ]
        
        isDragging = false
        currentSequenceIndex = 0
        
        // Reset shared state when starting new game (but don't reset timer settings)
        if !sharedGameState.shouldShowGameResult {
            sharedGameState.totalErrors = 0
            sharedGameState.isGameWon = false
            sharedGameState.isGameOver = false
            sharedGameState.isGameTimeExpired = false
        }
        
        print("✅ ECHO: Game setup completed with fixed sequence")
    }
    
    private func colorName(_ color: Color) -> String {
        switch color {
        case .yellow: return "YELLOW"
        case .blue: return "BLUE"
        case .green: return "GREEN"
        case .red: return "RED"
        default: return "UNKNOWN"
        }
    }
    
    private func resetGame() {
        print("🔄 ECHO: Local game reset initiated")
        
        // Reset local game state
        for index in batteries.indices {
            batteries[index].position = batteries[index].originalPosition
            batteries[index].isPlaced = false
        }
        isDragging = false
        currentSequenceIndex = 0
        
        hasInitializedTimer = false
        
        GameStatisticsManager.shared.resetCurrentGameErrors()
        
        print("✅ Local ECHO game state reset completed")
    }
    
    // MARK: - Audio Feedback Functions
    private func playSuccessSound(for slotNumber: Int) {
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
            
            print("🔊 ECHO playing local success sound for slot \(slotNumber) (frequency: \(frequency) Hz)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
                audioEngine.stop()
            }
        } catch {
            print("❌ Error playing success sound: \(error)")
        }
    }
    
    // MARK: - Game Logic
    private func checkForSlotMatch(batteryIndex: Int, location: CGPoint) {
        let battery = batteries[batteryIndex]
        var matched = false
        
        print("🔋 DEBUG: Attempting to place \(colorName(battery.color)) battery")
        print("   Current sequence index: \(currentSequenceIndex)")
        print("   Fixed sequence: \(fixedBatterySequence.map { colorName($0) })")
        
        if currentSequenceIndex < fixedBatterySequence.count {
            let expectedColor = fixedBatterySequence[currentSequenceIndex]
            print("   Expected next color: \(colorName(expectedColor))")
            print("   Battery being placed: \(colorName(battery.color))")
            print("   Colors match: \(battery.color == expectedColor)")
        } else {
            print("   ⚠️ All batteries already placed!")
        }
        
        for slot in slots {
            let distance = sqrt(pow(location.x - slot.position.x, 2) + pow(location.y - slot.position.y, 2))
            
            if distance < 30 {
                print("   ✅ Close enough to slot \(slot.id)")
                
                if battery.color == slot.expectedColor {
                    print("   ✅ Battery color matches slot color")
                    
                    // Controlla se è la batteria corretta nella sequenza fissa
                    if currentSequenceIndex < fixedBatterySequence.count &&
                       battery.color == fixedBatterySequence[currentSequenceIndex] {
                        // Batteria corretta nella sequenza giusta
                        print("   🎉 CORRECT! Battery is next in fixed sequence")
                        
                        batteries[batteryIndex].position = slot.position
                        batteries[batteryIndex].isPlaced = true
                        matched = true
                        currentSequenceIndex += 1
                        
                        print("✅ Correct battery in sequence: \(colorName(battery.color)) placed in slot \(slot.id) (\(currentSequenceIndex)/\(fixedBatterySequence.count))")
                        
                        playSuccessSound(for: slot.id)
                        
                        sharedGameState.sendBatteryPlacedEvent(
                            slotNumber: slot.id,
                            currentProgress: currentSequenceIndex,
                            totalSteps: fixedBatterySequence.count,
                            colorName: colorName(battery.color)
                        )
                        
                        // Check win condition
                        if currentSequenceIndex >= fixedBatterySequence.count {
                            print("🎉 ALL BATTERIES PLACED! Winning game...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                sharedGameState.sendGameWon()
                            }
                        }
                        break
                    } else {
                        // Batteria giusta ma fuori sequenza
                        let expectedColor = currentSequenceIndex < fixedBatterySequence.count ?
                            fixedBatterySequence[currentSequenceIndex] : .gray
                        print("   ❌ WRONG SEQUENCE! Expected: \(colorName(expectedColor)), got: \(colorName(battery.color))")
                        sharedGameState.sendErrorAdded()
                        break
                    }
                } else {
                    // Batteria sbagliata nello slot sbagliato
                    print("   ❌ WRONG SLOT! \(colorName(battery.color)) doesn't belong in \(colorName(slot.expectedColor)) slot")
                    sharedGameState.sendErrorAdded()
                    break
                }
            }
        }
        
        if !matched && !batteries[batteryIndex].isPlaced {
            print("   🔄 No valid placement - returning battery to original position")
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                batteries[batteryIndex].position = battery.originalPosition
            }
        }
    }
}

// MARK: - Data Models
struct Battery: Identifiable {
    let id: Int
    let name: String
    let color: Color
    var position: CGPoint
    let originalPosition: CGPoint
    var isPlaced: Bool = false
    
    init(id: Int, name: String, color: Color, position: CGPoint) {
        self.id = id
        self.name = name
        self.color = color
        self.position = position
        self.originalPosition = position
    }
}

struct BatterySlot: Identifiable {
    let id: Int
    let expectedColor: Color
    let position: CGPoint
}

// MARK: - Views
struct BatteryView: View {
    let battery: Battery
    
    var imageName: String {
        switch battery.color {
        case .blue: return "BLUE_BATTERY"
        case .green: return "GREEN_BATTERY"
        case .red: return "RED_BATTERY"
        case .yellow: return "YELLOW_BATTERY"
        default: return ""
        }
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .frame(width: 45, height: 150)
            .scaleEffect(battery.isPlaced ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: battery.isPlaced)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 2)
    }
}

struct BatterySlotView: View {
    let slot: BatterySlot
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.black.opacity(0.7), style: StrokeStyle(lineWidth: 3, dash: [5]))
            .frame(width: 35, height: 140)
            .position(slot.position)
    }
}

#Preview {
    MuteCombinedGameView()
}
