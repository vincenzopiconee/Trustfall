//
//  SharedGameStateManager.swift
//  FinalProject
//
//  FIXED: Complete restart functionality with timer and error reset + SYNCHRONIZED RANDOM BATTERY SEQUENCE
//

import SwiftUI
import GameKit

class SharedGameStateManager: ObservableObject {
    static let shared = SharedGameStateManager()
    
    // Timer state (Master)
    @Published var timeRemaining: Int = 600 // 10 minutes
    @Published var isTimerRunning = false
    @Published var timeString: String = "10:00"
    
    // Game state
    @Published var totalErrors: Int = 0
    @Published var isGameWon = false
    @Published var isGameOver = false
    @Published var shouldShowGameResult = false
    @Published var isGameTimeExpired = false
    
    // Battery sequence synchronization
    @Published var batterySequence: [Color] = []
    @Published var isSequenceSynced = false
    @Published var sequenceSyncAttempts = 0
    @Published var isWaitingForSequence = false
    
    private var gameTimer: Timer?
    private var gkManager = GameKitManager.shared
    private let maxErrors = 3
    private var gameStartTime: Date?
    
    // Bug prevention variables
    private var timerOwner: PlayerRole? = nil
    @Published var gameStateVersion: Int = 0
    private var lastTimerUpdate: Date = Date()
    private var processedGameMessages: Set<String> = []
    private var gameEndTriggered: Bool = false
    
    // Store original difficulty for resets
    private var originalDifficultyTimeSeconds: Int = 600
    
    private var sequenceRetryTimer: Timer?
    
    // ✅ NEW: Essential variables for sequence generation fix
    private var hasEverGeneratedSequence = false
    private var lastSequenceGenerationTime: Date?
    private var sequenceGenerationAttempts = 0
    
    // ✅ FIXED: Mappatura fissa per garantire coerenza tra MUTE e BLIND
    private let BATTERY_SOUND_MAPPING: [Color: String] = [
        .yellow: "alieno",    // Suono alieno = giallo = slot 1
        .green: "ufo",        // Suono UFO = verde = slot 2
        .red: "uovo",         // Suono uovo = rosso = slot 3
        .blue: "occhio"       // Suono occhio = blu = slot 4
    ]
    
    private init() {
        // ✅ Generate test sequence immediately for simulator
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.generateRandomSequenceForSimulator()
        }
        #endif
    }
    
    // ✅ SIMULATOR: Sequenza casuale per testing
    #if targetEnvironment(simulator)
    private func generateRandomSequenceForSimulator() {
        let colors: [Color] = [.yellow, .green, .red, .blue]
        let randomSequence = colors.shuffled()
        
        batterySequence = randomSequence
        isSequenceSynced = true
        isWaitingForSequence = false
        hasEverGeneratedSequence = true
        lastSequenceGenerationTime = Date()
        
        print("🔧 SIMULATOR: Generated RANDOM sequence: \(batterySequence.map { colorName($0) })")
        print("   Sound mapping: \(batterySequence.map { BATTERY_SOUND_MAPPING[$0] ?? "unknown" })")
        
        // Validate simulator sequence
        _ = validateSequenceIntegrity()
    }
    #endif
    
    // MARK: - Game Duration Management
    func setGameDuration(_ seconds: Int) {
        guard seconds > 0 else {
            print("⚠️ Invalid game duration: \(seconds)")
            return
        }
        
        originalDifficultyTimeSeconds = seconds
        timeRemaining = seconds
        updateTimeString()
        print("⏱️ Game duration set to \(seconds) seconds (\(seconds/60) minutes)")
        
        #if !targetEnvironment(simulator)
        if gkManager.currentPlayerRole == .mute && timerOwner == .mute {
            sendTimerUpdate()
        }
        #endif
    }
    
    func getDifficultyFromTime() -> GameDifficulty {
        switch timeRemaining {
        case 900: return .easy
        case 600: return .normal
        case 420: return .hard
        default: return .normal
        }
    }
    
    private func getOriginalDifficulty() -> GameDifficulty {
        switch originalDifficultyTimeSeconds {
        case 900: return .easy
        case 600: return .normal
        case 420: return .hard
        default: return .normal
        }
    }
    
    var difficultyString: String {
        return getDifficultyFromTime().rawValue
    }
    
    // MARK: - ✅ FIXED: Synchronized Random Battery Sequence Management
    func generateAndShareBatterySequence() {
        print("🎲 generateAndShareBatterySequence called")
        print("   Current Sequence: \(batterySequence.map { colorName($0) })")
        print("   Already Generated: \(hasEverGeneratedSequence)")
        
        #if targetEnvironment(simulator)
        generateRandomSequenceForSimulator()
        return
        #endif
        
        guard gkManager.isHost || gkManager.currentPlayerRole == .mute else {
            print("⚠️ Only host/MUTE can generate battery sequence")
            return
        }
        
        // ✅ FIXED: Allow regeneration durante restart
        guard !hasEverGeneratedSequence || batterySequence.isEmpty else {
            print("✅ Sequence already generated: \(batterySequence.map { colorName($0) })")
            // ✅ CRITICAL: Verifica che la sequenza sia valida
            if !validateSequenceIntegrity() {
                print("⚠️ Existing sequence is invalid - regenerating...")
                hasEverGeneratedSequence = false
                batterySequence = []
                // Restart generation
                generateAndShareBatterySequence()
                return
            }
            
            if !isSequenceSynced {
                sendBatterySequence()
            }
            return
        }
        
        sequenceGenerationAttempts += 1
        lastSequenceGenerationTime = Date()
        
        // ✅ FIXED: Genera sequenza CASUALE ma usando SEED per sincronizzazione
        let randomSequence = generateSynchronizedRandomSequence()
        
        // Update all states together
        DispatchQueue.main.async {
            self.batterySequence = randomSequence
            self.isSequenceSynced = true
            self.isWaitingForSequence = false
            self.hasEverGeneratedSequence = true
            
            print("🎲 Generated RANDOM synchronized sequence: \(randomSequence.map { self.colorName($0) })")
            print("   Corresponding sounds for BLIND: \(randomSequence.map { self.BATTERY_SOUND_MAPPING[$0] ?? "unknown" })")
            print("   Slot assignments for MUTE:")
            for (index, color) in randomSequence.enumerated() {
                print("     Step \(index + 1): \(self.colorName(color)) → Slot \(self.getSlotForColor(color))")
            }
            
            // ✅ CRITICAL: Validate sequence before sending
            if self.validateSequenceIntegrity() {
                self.sendBatterySequence()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.verifySequenceSync()
                }
            } else {
                print("❌ Generated sequence failed validation - retrying...")
                self.hasEverGeneratedSequence = false
                self.generateAndShareBatterySequence()
            }
        }
    }
    
    // ✅ NEW: Genera sequenza casuale sincronizzata
    private func generateSynchronizedRandomSequence() -> [Color] {
        // ✅ USA SEED basato su timestamp condiviso per garantire sincronizzazione
        let gameSessionSeed = gkManager.match?.players.first?.gamePlayerID.hashValue ?? Int(Date().timeIntervalSince1970)
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(gameSessionSeed) + sequenceGenerationAttempts))
        
        let allColors: [Color] = [.yellow, .green, .red, .blue]
        let shuffledSequence = allColors.shuffled(using: &generator)
        
        print("🎲 Generated random sequence with seed \(gameSessionSeed):")
        print("   Colors: \(shuffledSequence.map { colorName($0) })")
        print("   Sounds: \(shuffledSequence.map { BATTERY_SOUND_MAPPING[$0] ?? "unknown" })")
        
        return shuffledSequence
    }
    
    // ✅ NEW: Validate che la sequenza sia integra
    private func validateSequenceIntegrity() -> Bool {
        guard batterySequence.count == 4 else {
            print("❌ Invalid sequence length: \(batterySequence.count)")
            return false
        }
        
        // Verifica che tutti i colori necessari siano presenti
        let requiredColors: Set<Color> = [.yellow, .green, .red, .blue]
        let sequenceColors = Set(batterySequence)
        
        let isComplete = requiredColors == sequenceColors
        let hasValidSounds = batterySequence.allSatisfy { BATTERY_SOUND_MAPPING[$0] != nil }
        
        if isComplete && hasValidSounds {
            print("✅ Sequence integrity validated:")
            print("   Colors: \(batterySequence.map { colorName($0) })")
            print("   Sounds: \(batterySequence.map { BATTERY_SOUND_MAPPING[$0] ?? "unknown" })")
            return true
        } else {
            print("❌ Sequence integrity failed:")
            print("   Complete colors: \(isComplete)")
            print("   Valid sounds: \(hasValidSounds)")
            print("   Missing colors: \(requiredColors.subtracting(sequenceColors))")
            return false
        }
    }
    
    // ✅ NEW: Get slot number for color (based on fixed mapping)
    private func getSlotForColor(_ color: Color) -> Int {
        switch color {
        case .yellow: return 1
        case .green: return 2
        case .red: return 3
        case .blue: return 4
        default: return 0
        }
    }
    
    func setBatterySequence(_ sequence: [Color]) {
        guard !sequence.isEmpty else {
            print("⚠️ Received empty sequence - ignoring")
            return
        }
        
        DispatchQueue.main.async {
            self.batterySequence = sequence
            self.isSequenceSynced = true
            self.isWaitingForSequence = false
            self.sequenceSyncAttempts = 0
            self.hasEverGeneratedSequence = true
            
            self.sequenceRetryTimer?.invalidate()
            self.sequenceRetryTimer = nil
            
            print("✅ Battery sequence SET: \(sequence.map { self.colorName($0) })")
            
            // ✅ Validate received sequence
            if !self.validateSequenceIntegrity() {
                print("⚠️ Received invalid sequence - requesting new one")
                self.requestBatterySequence()
            }
        }
    }
    
    func requestBatterySequence() {
        #if targetEnvironment(simulator)
        if batterySequence.isEmpty {
            generateRandomSequenceForSimulator()
        }
        return
        #endif
        
        guard !gkManager.isHost && sequenceSyncAttempts < 5 else {
            if sequenceSyncAttempts >= 5 {
                handleSequenceSyncFailure()
            }
            return
        }
        
        sequenceSyncAttempts += 1
        isWaitingForSequence = true
        
        print("📡 Requesting battery sequence (attempt \(sequenceSyncAttempts)/5)")
        sendBatterySequenceRequest()
        setupSequenceRetry()
    }
    
    private func setupSequenceRetry() {
        sequenceRetryTimer?.invalidate()
        
        sequenceRetryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.batterySequence.isEmpty && self.sequenceSyncAttempts < 5 {
                    self.requestBatterySequence()
                }
            }
        }
    }
    
    private func verifySequenceSync() {
        guard gkManager.isHost else { return }
        
        if batterySequence.isEmpty || !validateSequenceIntegrity() {
            print("⚠️ Host sequence verification FAILED - regenerating...")
            hasEverGeneratedSequence = false
            generateAndShareBatterySequence()
        } else {
            print("✅ Host sequence verification successful")
        }
    }
    
    // ✅ FIXED: Fallback con sequenza casuale valida
    private func handleSequenceSyncFailure() {
        print("❌ Battery sequence sync failed - generating fallback random sequence")
        
        #if targetEnvironment(simulator)
        generateRandomSequenceForSimulator()
        #else
        // Generate a valid random sequence as fallback
        let fallbackSequence: [Color] = [.yellow, .green, .red, .blue].shuffled()
        setBatterySequence(fallbackSequence)
        print("🆘 Using fallback random sequence: \(fallbackSequence.map { colorName($0) })")
        #endif
    }
    
    func forceBatterySequenceSync() {
        print("🔄 forceBatterySequenceSync called")
        sequenceSyncAttempts = 0
        isWaitingForSequence = true
        isSequenceSynced = false
        
        if gkManager.isHost {
            hasEverGeneratedSequence = false
            generateAndShareBatterySequence()
        } else {
            requestBatterySequence()
        }
    }
    
    // ✅ FIXED: Reset con nuova sequenza casuale
    func ensureSequenceForRestart() {
        print("🔄 ensureSequenceForRestart called - generating NEW random sequence")
        
        // Reset sequence state completely
        batterySequence = []
        isSequenceSynced = false
        hasEverGeneratedSequence = false
        sequenceSyncAttempts = 0
        sequenceGenerationAttempts = 0 // ✅ Reset attempts for new seed
        
        // Generate immediately with new random sequence
        if gkManager.isHost || gkManager.currentPlayerRole == .mute {
            generateAndShareBatterySequence()
        } else {
            requestBatterySequence()
        }
        
        // Double-check after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.batterySequence.isEmpty {
                print("⚠️ Sequence still empty - forcing generation")
                if self.gkManager.isHost || self.gkManager.currentPlayerRole == .mute {
                    self.generateAndShareBatterySequence()
                }
            } else if !self.validateSequenceIntegrity() {
                print("⚠️ Sequence invalid after restart - regenerating")
                self.hasEverGeneratedSequence = false
                self.generateAndShareBatterySequence()
            } else {
                print("✅ Random sequence ready: \(self.batterySequence.map { self.colorName($0) })")
            }
        }
    }
    
    // ✅ NEW: Funzione per ottenere la mappatura suono corrente
    func getCurrentSoundSequence() -> [String] {
        return batterySequence.compactMap { BATTERY_SOUND_MAPPING[$0] }
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
    
    // MARK: - Timer Management
    func startGame() {
        #if targetEnvironment(simulator)
        let isMute = true
        #else
        let isMute = gkManager.currentPlayerRole == .mute
        guard isMute else {
            print("⚠️ Only MUTE can control master timer")
            return
        }
        #endif
        
        guard !isTimerRunning else {
            print("⚠️ Timer already running")
            return
        }
        
        guard timeRemaining > 0 else {
            print("⚠️ Cannot start game - no time remaining")
            return
        }
        
        guard timerOwner == nil || timerOwner == .mute else {
            print("⚠️ Timer already owned")
            return
        }
        
        timerOwner = .mute
        gameStateVersion += 1
        gameEndTriggered = false
        
        print("🎮 Starting game with \(timeRemaining) seconds")
        
        gameStartTime = Date()
        isTimerRunning = true
        updateTimeString()
        
        // ✅ ENSURE SEQUENCE IS AVAILABLE
        if batterySequence.isEmpty {
            print("🎲 No sequence available - generating...")
            generateAndShareBatterySequence()
        } else {
            print("✅ Using existing sequence: \(batterySequence.map { colorName($0) })")
        }
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                guard self.timerOwner == .mute && self.isTimerRunning else {
                    self.stopGame()
                    return
                }
                
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    self.updateTimeString()
                    
                    #if !targetEnvironment(simulator)
                    if self.timeRemaining % 5 == 0 {
                        self.sendTimerUpdate()
                    }
                    #endif
                    
                    if self.timeRemaining == 0 {
                        self.sendGameTimeExpired()
                    }
                } else {
                    self.stopGame()
                }
            }
        }
    }
    
    func stopGame() {
        print("⏹️ Stopping game")
        
        isTimerRunning = false
        gameTimer?.invalidate()
        gameTimer = nil
        sequenceRetryTimer?.invalidate()
        sequenceRetryTimer = nil
        
        if timerOwner == .mute {
            timerOwner = nil
        }
    }
    
    private func updateTimeString() {
        let minutes = max(0, timeRemaining) / 60
        let seconds = max(0, timeRemaining) % 60
        timeString = String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - ✅ FIXED: Complete Game State Reset
    func resetGame() {
        print("🔄 Complete game reset initiated")
        
        stopGame()
        
        timerOwner = nil
        gameStateVersion += 1
        gameEndTriggered = false
        
        let originalDifficulty = getOriginalDifficulty()
        timeRemaining = originalDifficulty.timeInSeconds
        updateTimeString()
        
        totalErrors = 0
        isGameWon = false
        isGameOver = false
        shouldShowGameResult = false
        isGameTimeExpired = false
        gameStartTime = nil
        
        // ✅ KEY FIX: Reset sequence state completely for fresh generation
        batterySequence = []
        isSequenceSynced = false
        sequenceSyncAttempts = 0
        isWaitingForSequence = false
        hasEverGeneratedSequence = false  // This allows fresh generation
        lastSequenceGenerationTime = nil
        sequenceGenerationAttempts = 0
        
        processedGameMessages.removeAll()
        
        print("✅ Reset complete - sequence cleared for fresh generation")
        
        // ✅ IMMEDIATE regeneration for restart
        if gkManager.isHost || gkManager.currentPlayerRole == .mute {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                print("🎲 Regenerating sequence after reset...")
                self.generateAndShareBatterySequence()
            }
        }
    }
    
    // ✅ NEW: Debug completo della sincronizzazione
    func debugSynchronization() {
        print("🔍 SYNCHRONIZATION DEBUG:")
        print("   Role: \(gkManager.currentPlayerRole?.rawValue ?? "unknown")")
        print("   Is Host: \(gkManager.isHost)")
        print("   Sequence Generated: \(hasEverGeneratedSequence)")
        print("   Sequence Synced: \(isSequenceSynced)")
        print("   Generation Attempts: \(sequenceGenerationAttempts)")
        print("   Battery Sequence: \(batterySequence.map { colorName($0) })")
        print("   Sound Sequence: \(getCurrentSoundSequence())")
        print("   Sequence Valid: \(validateSequenceIntegrity())")
        
        if !batterySequence.isEmpty {
            print("   MUTE will see this order:")
            for (index, color) in batterySequence.enumerated() {
                print("     Step \(index + 1): \(colorName(color)) → Slot \(getSlotForColor(color))")
            }
            
            print("   BLIND will hear this order:")
            for (index, color) in batterySequence.enumerated() {
                let sound = BATTERY_SOUND_MAPPING[color] ?? "unknown"
                print("     Step \(index + 1): \(sound) (= \(colorName(color)))")
            }
        }
    }
    
    // MARK: - Game Events
    func sendBatteryPlacedEvent(slotNumber: Int, currentProgress: Int, totalSteps: Int, colorName: String) {
        #if targetEnvironment(simulator)
        NotificationCenter.default.post(
            name: .batteryPlacedCorrectly,
            object: nil,
            userInfo: [
                "slotNumber": slotNumber,
                "currentProgress": currentProgress,
                "totalSteps": totalSteps,
                "colorName": colorName
            ]
        )
        return
        #endif
        
        let message = GameStateMessage.batteryPlacedCorrectly(
            slotNumber: slotNumber,
            currentProgress: currentProgress,
            totalSteps: totalSteps,
            colorName: colorName
        )
        sendGameStateMessage(message)
    }
    
    func sendErrorAdded() {
        let messageId = "error_\(totalErrors)_\(Date().timeIntervalSince1970)"
        guard !processedGameMessages.contains(messageId) else { return }
        processedGameMessages.insert(messageId)
        
        totalErrors += 1
        print("❌ Error added. Total: \(totalErrors)/\(maxErrors)")
        
        GameStatisticsManager.shared.syncCurrentErrors(totalErrors)
        
        let errorType = determineErrorType()
        sendErrorSound(errorCount: totalErrors, errorType: errorType)
        
        #if !targetEnvironment(simulator)
        let message = GameStateMessage.errorAdded(totalErrors)
        sendGameStateMessage(message)
        #endif
        
        if totalErrors >= maxErrors && !gameEndTriggered {
            sendGameOver()
        }
    }
    
    private func determineErrorType() -> String {
        switch totalErrors {
        case 1: return "first_error"
        case 2: return "second_error"
        case 3: return "final_error"
        default: return "generic_error"
        }
    }
    
    private func sendErrorSound(errorCount: Int, errorType: String) {
        #if targetEnvironment(simulator)
        NotificationCenter.default.post(
            name: .errorSoundTriggered,
            object: nil,
            userInfo: [
                "errorCount": errorCount,
                "errorType": errorType
            ]
        )
        return
        #endif
        
        let message = GameStateMessage.errorSoundTriggered(errorCount: errorCount, errorType: errorType)
        sendGameStateMessage(message)
    }
    
    func sendGameWon() {
        guard !shouldShowGameResult && !gameEndTriggered else { return }
        
        gameEndTriggered = true
        isGameWon = true
        shouldShowGameResult = true
        stopGame()
        
        print("🎉 Game WON!")
        gkManager.trackGameEnd(won: true, timeRemaining: timeRemaining)
        
        #if !targetEnvironment(simulator)
        let message = GameStateMessage.gameWon
        sendGameStateMessage(message)
        #endif
    }
    
    private func sendGameOver() {
        guard !shouldShowGameResult && !gameEndTriggered else { return }
        
        gameEndTriggered = true
        isGameOver = true
        shouldShowGameResult = true
        stopGame()
        
        print("💀 Game OVER")
        gkManager.trackGameEnd(won: false, timeRemaining: timeRemaining)
        
        #if !targetEnvironment(simulator)
        let message = GameStateMessage.gameOver
        sendGameStateMessage(message)
        #endif
    }
    
    private func sendGameTimeExpired() {
        guard !shouldShowGameResult && !gameEndTriggered else { return }
        guard timeRemaining <= 0 else { return }
        guard timerOwner == .mute || timerOwner == nil else { return }
        
        gameEndTriggered = true
        isGameTimeExpired = true
        isGameOver = true
        shouldShowGameResult = true
        stopGame()
        
        print("⏰ TIME EXPIRED!")
        gkManager.trackGameEnd(won: false, timeRemaining: 0)
        
        #if !targetEnvironment(simulator)
        let message = GameStateMessage.gameTimeExpired
        sendGameStateMessage(message)
        #endif
    }
    
    func sendGameReset() {
        #if targetEnvironment(simulator)
        resetGame()
        return
        #endif
        
        guard gkManager.isHost else { return }
        
        resetGame()
        
        let message = GameStateMessage.gameReset
        sendGameStateMessage(message)
    }
    
    // MARK: - Network Communication
    private func sendTimerUpdate() {
        #if targetEnvironment(simulator)
        return
        #endif
        
        guard timerOwner == .mute else { return }
        
        let message = GameStateMessage.timerUpdate(timeRemaining)
        sendGameStateMessage(message)
    }
    
    private func sendBatterySequence() {
        #if targetEnvironment(simulator)
        return
        #endif
        
        let message = GameStateMessage.batterySequenceUpdate(batterySequence)
        sendGameStateMessage(message)
        print("📤 Sent battery sequence: \(batterySequence.map { colorName($0) })")
    }
    
    private func sendBatterySequenceRequest() {
        #if targetEnvironment(simulator)
        return
        #endif
        
        let message = GameStateMessage.batterySequenceRequest
        sendGameStateMessage(message)
    }
    
    private func sendGameStateMessage(_ message: GameStateMessage) {
        #if targetEnvironment(simulator)
        return
        #endif
        
        guard let match = gkManager.match else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            print("❌ Error sending message: \(error)")
        }
    }
    
    // MARK: - Message Handling
    func handleReceivedMessage(_ message: GameStateMessage) {
        #if targetEnvironment(simulator)
        return
        #endif
        
        if gameEndTriggered && !isResetMessage(message) { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch message {
            case .batterySequenceUpdate(let sequence):
                print("📡 Received sequence: \(sequence.map { self.colorName($0) })")
                self.setBatterySequence(sequence)
                
            case .batterySequenceRequest:
                if self.gkManager.isHost {
                    if !self.batterySequence.isEmpty && self.validateSequenceIntegrity() {
                        self.sendBatterySequence()
                    } else {
                        self.generateAndShareBatterySequence()
                    }
                }
                
            case .timerUpdate(let time):
                if self.timerOwner != .mute && !self.isTimerRunning && time > 0 {
                    self.timeRemaining = time
                    self.updateTimeString()
                }
                
            case .errorAdded(let errorCount):
                if errorCount > self.totalErrors && errorCount <= self.maxErrors {
                    self.totalErrors = errorCount
                    GameStatisticsManager.shared.syncCurrentErrors(errorCount)
                    
                    if self.totalErrors >= self.maxErrors && !self.gameEndTriggered {
                        self.gameEndTriggered = true
                        self.isGameOver = true
                        self.shouldShowGameResult = true
                        self.stopGame()
                    }
                }
                
            case .gameWon:
                if !self.gameEndTriggered {
                    self.gameEndTriggered = true
                    self.isGameWon = true
                    self.shouldShowGameResult = true
                    self.stopGame()
                    self.gkManager.trackGameEnd(won: true, timeRemaining: self.timeRemaining)
                }
                
            case .gameOver:
                if !self.gameEndTriggered {
                    self.gameEndTriggered = true
                    self.isGameOver = true
                    self.shouldShowGameResult = true
                    self.stopGame()
                    self.gkManager.trackGameEnd(won: false, timeRemaining: self.timeRemaining)
                }
                
            case .gameTimeExpired:
                if !self.gameEndTriggered {
                    self.gameEndTriggered = true
                    self.isGameTimeExpired = true
                    self.isGameOver = true
                    self.shouldShowGameResult = true
                    self.timeRemaining = 0
                    self.updateTimeString()
                    self.stopGame()
                    self.gkManager.trackGameEnd(won: false, timeRemaining: 0)
                }
                
            case .gameReset:
                self.resetGame()
                
            case .batteryPlacedCorrectly(let slotNumber, let currentProgress, let totalSteps, let colorName):
                NotificationCenter.default.post(
                    name: .batteryPlacedCorrectly,
                    object: nil,
                    userInfo: [
                        "slotNumber": slotNumber,
                        "currentProgress": currentProgress,
                        "totalSteps": totalSteps,
                        "colorName": colorName
                    ]
                )
                
            case .errorSoundTriggered(let errorCount, let errorType):
                NotificationCenter.default.post(
                    name: .errorSoundTriggered,
                    object: nil,
                    userInfo: [
                        "errorCount": errorCount,
                        "errorType": errorType
                    ]
                )
            }
        }
    }
    
    private func isResetMessage(_ message: GameStateMessage) -> Bool {
        switch message {
        case .gameReset: return true
        default: return false
        }
    }
    
    // MARK: - Computed Properties
    var gameOverReason: String {
        if isGameTimeExpired {
            return "TIME EXPIRED"
        } else if totalErrors >= maxErrors {
            return "3 MISTAKES MADE"
        } else {
            return "GAME OVER"
        }
    }
    
    var sequenceDebugInfo: String {
        if batterySequence.isEmpty {
            return isWaitingForSequence ? "Waiting for sequence..." : "No sequence"
        } else {
            return batterySequence.map { colorName($0) }.joined(separator: " → ")
        }
    }
    
    deinit {
        stopGame()
        print("🧹 SharedGameStateManager deallocated")
    }
}

// ✅ NEW: Seeded Random Number Generator per sincronizzazione
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return state
    }
}

// MARK: - Game State Messages
enum GameStateMessage: Codable {
    case timerUpdate(Int)
    case errorAdded(Int)
    case gameWon
    case gameOver
    case gameTimeExpired
    case gameReset
    case batterySequenceUpdate([Color])
    case batterySequenceRequest
    case batteryPlacedCorrectly(slotNumber: Int, currentProgress: Int, totalSteps: Int, colorName: String)
    case errorSoundTriggered(errorCount: Int, errorType: String)
}

// MARK: - Notification extensions
extension Notification.Name {
    static let batteryPlacedCorrectly = Notification.Name("batteryPlacedCorrectly")
    static let errorSoundTriggered = Notification.Name("errorSoundTriggered")
}

// MARK: - Color Codable Extension
extension Color: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if self == .yellow {
            try container.encode("yellow")
        } else if self == .blue {
            try container.encode("blue")
        } else if self == .green {
            try container.encode("green")
        } else if self == .red {
            try container.encode("red")
        } else {
            try container.encode("unknown")
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorString = try container.decode(String.self)
        
        switch colorString {
        case "yellow":
            self = .yellow
        case "blue":
            self = .blue
        case "green":
            self = .green
        case "red":
            self = .red
        default:
            self = .gray
        }
    }
}
