//
//  ErrorSoundManager.swift
//  FinalProject
//
//  NEW: Centralized error sound management for all players
//

import Foundation
import AVFoundation

class ErrorSoundManager: ObservableObject {
    static let shared = ErrorSoundManager()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    private init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.outputNode, format: audioFormat)
        
        do {
            try engine.start()
        } catch {
            print("❌ Error starting audio engine: \(error)")
        }
    }
    
    func playErrorSound(errorCount: Int, errorType: String) {
        guard let engine = audioEngine, let player = playerNode else {
            print("❌ Audio engine not available")
            return
        }
        
        // Different error sounds based on error count
        let frequency: Double
        let duration: TimeInterval
        
        switch errorCount {
        case 1:
            frequency = 220.0  // Low warning tone
            duration = 0.5
        case 2:
            frequency = 440.0  // Medium warning tone
            duration = 0.8
        case 3:
            frequency = 880.0  // High critical tone
            duration = 1.2
        default:
            frequency = 330.0  // Default
            duration = 0.6
        }
        
        generateAndPlayErrorTone(frequency: frequency, duration: duration, errorCount: errorCount)
    }
    
    private func generateAndPlayErrorTone(frequency: Double, duration: TimeInterval, errorCount: Int) {
        guard let engine = audioEngine, let player = playerNode else { return }
        
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let sampleRate = audioFormat.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            print("❌ Could not create audio buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        guard let samples = buffer.floatChannelData?[0] else {
            print("❌ Could not access audio buffer data")
            return
        }
        
        // Generate error tone
        for i in 0..<Int(frameCount) {
            let time = Double(i) / sampleRate
            
            // Create envelope for smooth start/end
            let envelope: Float
            let fadeTime = 0.1 // 100ms fade
            if time < fadeTime {
                envelope = Float(time / fadeTime)
            } else if time > duration - fadeTime {
                envelope = Float((duration - time) / fadeTime)
            } else {
                envelope = 1.0
            }
            
            // Generate tone with harmonic for harshness on higher error counts
            var sample = sin(2.0 * Double.pi * frequency * time)
            
            if errorCount >= 2 {
                // Add harmonic distortion for urgency
                sample += sin(2.0 * Double.pi * frequency * 1.5 * time) * 0.3
            }
            
            if errorCount >= 3 {
                // Add more distortion for critical error
                sample += sin(2.0 * Double.pi * frequency * 2.0 * time) * 0.2
                sample = tanh(sample * 1.5) // Add some saturation
            }
            
            samples[i] = Float(sample) * envelope * 0.6 // Volume control
        }
        
        // Stop any currently playing error sound
        player.stop()
        
        // Play the generated error sound
        player.scheduleBuffer(buffer, completionHandler: nil)
        
        do {
            if !engine.isRunning {
                try engine.start()
            }
            player.play()
            
            print("🚨 Playing error sound: Error \(errorCount), Frequency: \(frequency)Hz, Duration: \(duration)s")
            
        } catch {
            print("❌ Error playing error sound: \(error)")
        }
    }
    
    deinit {
        audioEngine?.stop()
        print("🧹 ErrorSoundManager deallocated")
    }
}
