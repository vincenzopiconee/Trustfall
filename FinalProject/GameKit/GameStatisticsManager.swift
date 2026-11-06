//
//  GameStatisticsManager.swift
//  FinalProject
//
//  FIXED: Added reset current game errors functionality for restart
//

import GameKit
import SwiftUI

// MARK: - Game Statistics Manager
class GameStatisticsManager: ObservableObject {
    static let shared = GameStatisticsManager()
    
    @Published var totalGamesPlayed: Int = 0
    @Published var totalGamesWon: Int = 0
    @Published var totalErrors: Int = 0
    @Published var bestTimeSeconds: Int = 0
    @Published var totalTimeSeconds: Int = 0
    @Published var gamesAsMute: Int = 0
    @Published var gamesAsBlind: Int = 0
    @Published var fastestWinSeconds: Int = 0
    
    // ✅ IMPROVED: Tracking errori correnti per sincronizzazione e reset
    private var currentGameErrors: Int = 0
    
    private init() {
        loadStatistics()
    }
    
    private func loadStatistics() {
        totalGamesPlayed = UserDefaults.standard.integer(forKey: "totalGamesPlayed")
        totalGamesWon = UserDefaults.standard.integer(forKey: "totalGamesWon")
        totalErrors = UserDefaults.standard.integer(forKey: "totalErrors")
        bestTimeSeconds = UserDefaults.standard.integer(forKey: "bestTimeSeconds")
        totalTimeSeconds = UserDefaults.standard.integer(forKey: "totalTimeSeconds")
        gamesAsMute = UserDefaults.standard.integer(forKey: "gamesAsMute")
        gamesAsBlind = UserDefaults.standard.integer(forKey: "gamesAsBlind")
        fastestWinSeconds = UserDefaults.standard.integer(forKey: "fastestWinSeconds")
    }
    
    private func saveStatistics() {
        UserDefaults.standard.set(totalGamesPlayed, forKey: "totalGamesPlayed")
        UserDefaults.standard.set(totalGamesWon, forKey: "totalGamesWon")
        UserDefaults.standard.set(totalErrors, forKey: "totalErrors")
        UserDefaults.standard.set(bestTimeSeconds, forKey: "bestTimeSeconds")
        UserDefaults.standard.set(totalTimeSeconds, forKey: "totalTimeSeconds")
        UserDefaults.standard.set(gamesAsMute, forKey: "gamesAsMute")
        UserDefaults.standard.set(gamesAsBlind, forKey: "gamesAsBlind")
        UserDefaults.standard.set(fastestWinSeconds, forKey: "fastestWinSeconds")
        
        // ✅ IMPROVED: Debug logging with restart info
        print("📊 Statistics saved:")
        print("   Games: \(totalGamesPlayed), Won: \(totalGamesWon)")
        print("   Errors: \(totalErrors), Current Game: \(currentGameErrors)")
        print("   Win Rate: \(winRatePercentage)%")
        print("   Best Time: \(bestTimeString)")
    }
    
    // MARK: - ✅ IMPROVED: Real-time Synchronization with Reset Support
    func syncCurrentErrors(_ currentErrors: Int, isReset: Bool = false) {
        if isReset {
            // ✅ NEW: Reset current game errors explicitly
            currentGameErrors = 0
            print("📊 Current game errors reset via sync")
        } else {
            // Aggiorna gli errori della partita corrente
            let newErrors = max(0, currentErrors - currentGameErrors)
            if newErrors > 0 {
                currentGameErrors = currentErrors
                print("📊 Synced current game errors: \(currentGameErrors)")
            }
        }
    }
    
    // ✅ NEW: Reset current game errors (chiamato durante restart)
    func resetCurrentGameErrors() {
        currentGameErrors = 0
        print("📊 Current game errors reset to 0 for restart")
    }
    
    func syncWithGameState() {
        // Sincronizza errori dal SharedGameStateManager
        let gameStateErrors = SharedGameStateManager.shared.totalErrors
        syncCurrentErrors(gameStateErrors)
    }
    
    // MARK: - Game Event Tracking
    func recordGameStart(isHost: Bool) {
        totalGamesPlayed += 1
        currentGameErrors = 0 // ✅ IMPROVED: Reset errori partita corrente
        
        if isHost {
            gamesAsMute += 1
        } else {
            gamesAsBlind += 1
        }
        saveStatistics()
        
        print("📊 Game started recorded - Total games: \(totalGamesPlayed), IsHost: \(isHost)")
    }
    
    // Alternative method with string role
    func recordGameStart(role: String) {
        totalGamesPlayed += 1
        currentGameErrors = 0 // ✅ IMPROVED: Reset errori partita corrente
        
        if role.lowercased() == "mute" || role.lowercased() == "host" {
            gamesAsMute += 1
        } else {
            gamesAsBlind += 1
        }
        saveStatistics()
        
        print("📊 Game started recorded - Role: \(role), Total games: \(totalGamesPlayed)")
    }
    
    func recordGameWon(timeRemainingSeconds: Int) {
        totalGamesWon += 1
        let completionTime = max(0, 600 - timeRemainingSeconds) // 10 minutes - remaining
        
        if bestTimeSeconds == 0 || completionTime < bestTimeSeconds {
            bestTimeSeconds = completionTime
        }
        
        if fastestWinSeconds == 0 || completionTime < fastestWinSeconds {
            fastestWinSeconds = completionTime
        }
        
        totalTimeSeconds += completionTime
        
        // ✅ IMPROVED: Aggiungi errori della partita corrente al totale
        totalErrors += currentGameErrors
        currentGameErrors = 0
        
        saveStatistics()
        
        print("📊 Victory recorded: Time \(completionTime)s, Game errors: \(currentGameErrors), Total errors: \(totalErrors)")
    }
    
    func recordError() {
        totalErrors += 1
        currentGameErrors += 1 // ✅ IMPROVED: Track errori partita corrente
        saveStatistics()
        
        print("📊 Error recorded - Current game: \(currentGameErrors), Total: \(totalErrors)")
    }
    
    // ✅ IMPROVED: Metodo per registrare fine partita senza vittoria
    func recordGameEnd(won: Bool, timeRemainingSeconds: Int) {
        if won {
            recordGameWon(timeRemainingSeconds: timeRemainingSeconds)
        } else {
            // Anche se perdi, aggiungi gli errori al totale
            totalErrors += currentGameErrors
            let lostWithErrors = currentGameErrors
            currentGameErrors = 0
            saveStatistics()
            
            print("📊 Game end recorded - Lost with \(lostWithErrors) errors")
        }
    }
    
    // ✅ NEW: Record restart (for tracking restart behavior)
    func recordGameRestart() {
        print("📊 Game restart recorded - resetting current game errors")
        currentGameErrors = 0
        // Don't save statistics here, just reset current game state
    }
    
    func resetAllStatistics() {
        totalGamesPlayed = 0
        totalGamesWon = 0
        totalErrors = 0
        bestTimeSeconds = 0
        totalTimeSeconds = 0
        gamesAsMute = 0
        gamesAsBlind = 0
        fastestWinSeconds = 0
        currentGameErrors = 0 // ✅ IMPROVED: Reset anche errori correnti
        saveStatistics()
        
        print("📊 All statistics reset")
    }
    
    // MARK: - Computed Properties
    var winRatePercentage: Int {
        guard totalGamesPlayed > 0 else { return 0 }
        return Int((Double(totalGamesWon) / Double(totalGamesPlayed)) * 100)
    }
    
    var averageTimeString: String {
        guard totalGamesWon > 0 else { return "--:--" }
        let averageSeconds = totalTimeSeconds / totalGamesWon
        return formatTime(averageSeconds)
    }
    
    var bestTimeString: String {
        guard bestTimeSeconds > 0 else { return "--:--" }
        return formatTime(bestTimeSeconds)
    }
    
    var fastestWinString: String {
        guard fastestWinSeconds > 0 else { return "--:--" }
        return formatTime(fastestWinSeconds)
    }
    
    var averageErrorsPerGame: Double {
        guard totalGamesPlayed > 0 else { return 0.0 }
        return Double(totalErrors) / Double(totalGamesPlayed)
    }
    
    var communicationAccuracy: Int {
        guard totalGamesPlayed > 0 else { return 100 }
        let maxPossibleErrors = totalGamesPlayed * 3 // Max 3 errors per game
        let accuracy = Double(maxPossibleErrors - totalErrors) / Double(maxPossibleErrors) * 100
        return max(0, Int(accuracy))
    }
    
    // ✅ IMPROVED: Computed property per errori partita corrente
    var currentGameErrorCount: Int {
        return currentGameErrors
    }
    
    // ✅ NEW: Check if this is a fresh restart
    var isCurrentGameFresh: Bool {
        return currentGameErrors == 0
    }
    
    // ✅ NEW: Restart statistics summary
    var restartSummary: String {
        return """
        📊 RESTART SUMMARY:
        - Current Game Errors: \(currentGameErrors)
        - Fresh Game: \(isCurrentGameFresh ? "YES" : "NO")
        - Total Games: \(totalGamesPlayed)
        - Win Rate: \(winRatePercentage)%
        """
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    // MARK: - ✅ NEW: Debug Methods for Restart
    #if DEBUG
    func debugCurrentGameState() -> String {
        return """
        🔧 CURRENT GAME DEBUG:
        - Current Errors: \(currentGameErrors)
        - Is Fresh: \(isCurrentGameFresh)
        - Total Errors: \(totalErrors)
        - Games Played: \(totalGamesPlayed)
        - Games Won: \(totalGamesWon)
        """
    }
    
    func forceResetCurrentGameForTesting() {
        print("🔧 DEBUG: Force resetting current game errors")
        resetCurrentGameErrors()
    }
    #endif
}
