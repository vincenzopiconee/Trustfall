//
//  BackgroundMusicManager.swift
//  FinalProject
//
//  FIXED: Proper audio session management to avoid conflicts with game audio
//

import Foundation
import AVFoundation

class BackgroundMusicManager: ObservableObject {
    static let shared = BackgroundMusicManager()
    
    private var backgroundPlayer: AVAudioPlayer?
    @Published var isMusicEnabled = true
    @Published var musicVolume: Float = 0.3
    
    // ✅ NEW: Track if game audio is active
    private var isGameAudioActive = false
    private var savedVolume: Float = 0.3
    
    private init() {
        loadMusicSettings()
    }
    
    func playBackgroundMusic(filename: String, fileType: String = "mp3") {
        guard isMusicEnabled else { return }
        
        // Stop any existing music
        stopBackgroundMusic()
        
        guard let path = Bundle.main.path(forResource: filename, ofType: fileType) else {
            print("❌ Background music file not found: \(filename).\(fileType)")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            // ✅ FIXED: Configure audio session to allow mixing and ducking
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)
            
            // Create and configure player
            backgroundPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.numberOfLoops = -1 // Infinite loop
            backgroundPlayer?.volume = isGameAudioActive ? 0.05 : musicVolume  // ✅ Lower volume if game audio active
            backgroundPlayer?.prepareToPlay()
            backgroundPlayer?.play()
            
            print("🎵 Background music started: \(filename) (Volume: \(backgroundPlayer?.volume ?? 0))")
            
        } catch {
            print("❌ Error playing background music: \(error)")
        }
    }
    
    func stopBackgroundMusic() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
        print("🛑 Background music stopped")
    }
    
    func pauseBackgroundMusic() {
        backgroundPlayer?.pause()
        print("⏸️ Background music paused")
    }
    
    func resumeBackgroundMusic() {
        guard isMusicEnabled else { return }
        
        // ✅ NEW: Don't resume if game audio is active
        if isGameAudioActive {
            print("🔇 Background music kept quiet - game audio is active")
            return
        }
        
        backgroundPlayer?.play()
        print("▶️ Background music resumed")
    }
    
    func setVolume(_ volume: Float) {
        let newVolume = max(0.0, min(1.0, volume))
        musicVolume = newVolume
        
        // ✅ NEW: Apply even lower volume if game audio is active
        let actualVolume = isGameAudioActive ? min(newVolume, 0.05) : newVolume
        backgroundPlayer?.volume = actualVolume
        
        saveMusicSettings()
        print("🔊 Background music volume set to: \(actualVolume) (requested: \(newVolume))")
    }
    
    func toggleMusic() {
        isMusicEnabled.toggle()
        
        if isMusicEnabled {
            resumeBackgroundMusic()
        } else {
            pauseBackgroundMusic()
        }
        
        saveMusicSettings()
    }
    
    // ✅ NEW: Game audio state management
    func setGameAudioActive(_ active: Bool) {
        isGameAudioActive = active
        
        if active {
            // Game audio started - duck background music heavily
            savedVolume = backgroundPlayer?.volume ?? musicVolume
            backgroundPlayer?.volume = 0.05  // Very quiet
            print("🔇 Background music ducked for game audio")
        } else {
            // Game audio stopped - restore background music
            backgroundPlayer?.volume = savedVolume
            print("🔊 Background music restored after game audio")
        }
    }
    
    // MARK: - Settings Persistence
    private func saveMusicSettings() {
        UserDefaults.standard.set(isMusicEnabled, forKey: "backgroundMusicEnabled")
        UserDefaults.standard.set(musicVolume, forKey: "backgroundMusicVolume")
    }
    
    private func loadMusicSettings() {
        if UserDefaults.standard.object(forKey: "backgroundMusicEnabled") != nil {
            isMusicEnabled = UserDefaults.standard.bool(forKey: "backgroundMusicEnabled")
        } else {
            isMusicEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: "backgroundMusicVolume") != nil {
            musicVolume = UserDefaults.standard.float(forKey: "backgroundMusicVolume")
        } else {
            musicVolume = 0.3
        }
        
        if musicVolume <= 0 {
            musicVolume = 0.3
        }
    }
    
    // MARK: - Game State Management
    func handleGameStart() {
        // ✅ IMPROVED: Mark game audio as active and reduce volume
        setGameAudioActive(true)
    }
    
    func handleGameEnd() {
        // ✅ IMPROVED: Mark game audio as inactive and restore volume
        setGameAudioActive(false)
    }
    
    // ✅ NEW: For BLIND player specifically
    func handleBlindPlayerSequenceStart() {
        print("🔇 BLIND sequence starting - pausing background music")
        pauseBackgroundMusic()
    }
    
    func handleBlindPlayerSequenceEnd() {
        print("🔊 BLIND sequence ended - resuming background music")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.resumeBackgroundMusic()
        }
    }
}
