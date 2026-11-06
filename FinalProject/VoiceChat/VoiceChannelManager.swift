//
//  VoiceChannelManager.swift
//  FinalProject
//
//  COMPLETELY FIXED: Proper voice management for all modes with reliable state handling + MUTE BUG FIXED
//

import SwiftUI
import GameKit

// MARK: - Voice Channel Manager
class VoiceChannelManager: ObservableObject {
    static let shared = VoiceChannelManager()
    
    @Published var currentChannelId: String = ""
    @Published var isInLobby: Bool = true
    @Published var isInGame: Bool = false
    @Published var isInCutscene: Bool = false
    @Published var playersInChannel: Set<String> = []
    
    private let voiceManager = AgoraVoiceManager.shared
    private var userRequestedMute: Bool = false // Track if user manually muted in lobby
    private var currentPlayerRole: PlayerRole = .blind // Track current role for game mode
    private var isConfiguring: Bool = false // Prevent configuration conflicts
    
    // ✅ NEW: Fix for lobby mute bug
    private var muteStateBeforeJoin: Bool = false // Store mute state before joining channel
    private var hasAppliedInitialMuteState: Bool = false // Track if we've applied initial mute state
    private var muteStateSync: DispatchWorkItem? // Delayed mute state application
    
    private init() {
        loadMuteState()
    }
    
    private func loadMuteState() {
        userRequestedMute = UserDefaults.standard.bool(forKey: "localAudioMuted")
        muteStateBeforeJoin = userRequestedMute // Store for later application
        print("🔇 Loaded mute state: \(userRequestedMute)")
    }
    
    private func saveMuteState() {
        UserDefaults.standard.set(userRequestedMute, forKey: "localAudioMuted")
        print("💾 Saved mute state: \(userRequestedMute)")
    }
    
    // MARK: - Single Channel ID Generation
    func generateChannelId(from matchId: String) -> String {
        let cleanMatchId = matchId.replacingOccurrences(of: "-", with: "").prefix(16)
        let channelId = "unified_\(cleanMatchId)"
        return String(channelId)
    }
    
    // MARK: - ✅ FIXED: Unified Voice Management - SEMPRE STESSO CANALE
    func joinVoiceChannel(channelId: String) {
        print("🎤 Joining unified voice channel: \(channelId)")
        
        // Se già connesso allo stesso canale, non fare nulla
        if voiceManager.isJoined && currentChannelId == channelId {
            print("✅ Already connected to channel: \(channelId)")
            
            // ✅ CRITICAL FIX: Apply mute state if not yet applied
            if !hasAppliedInitialMuteState {
                applyInitialMuteState()
            }
            return
        }
        
        // ✅ CRITICAL FIX: Store current mute preference before leaving
        muteStateBeforeJoin = userRequestedMute
        hasAppliedInitialMuteState = false
        
        // Leave any existing channel first
        if voiceManager.isJoined {
            print("🔄 Leaving current channel before joining new one")
            voiceManager.leaveChannel()
            
            // Wait before joining new channel
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.performChannelJoin(channelId: channelId)
            }
        } else {
            performChannelJoin(channelId: channelId)
        }
    }
    
    private func performChannelJoin(channelId: String) {
        currentChannelId = channelId
        
        // Initialize if needed
        voiceManager.initializeAgoraEngine()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.voiceManager.joinChannel(channelId: channelId)
            
            // ✅ CRITICAL FIX: Wait for connection and then apply proper mute state
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.voiceManager.isJoined {
                    print("✅ Voice channel joined - applying lobby configuration with mute fix")
                    self.transitionToLobby()
                } else {
                    print("❌ Voice channel join failed")
                }
            }
        }
    }
    
    // MARK: - ✅ FIXED: Lobby Mute Functionality with Bug Fix
    func muteLocalAudio() {
        userRequestedMute = true
        saveMuteState()
        
        print("🔇 User requested mute in lobby")
        
        // Apply mute immediately if in lobby and connected
        if isInLobby && voiceManager.isJoined {
            voiceManager.muteMic(true)
            print("✅ Mute applied immediately")
        } else {
            print("🔄 Mute state saved for later application")
        }
    }
    
    func unmuteLocalAudio() {
        userRequestedMute = false
        saveMuteState()
        
        print("🔊 User requested unmute in lobby")
        
        // Apply unmute immediately if in lobby and connected
        if isInLobby && voiceManager.isJoined {
            voiceManager.muteMic(false)
            print("✅ Unmute applied immediately")
        } else {
            print("🔄 Unmute state saved for later application")
        }
    }
    
    func toggleLocalAudioMute() {
        if userRequestedMute {
            unmuteLocalAudio()
        } else {
            muteLocalAudio()
        }
    }
    
    var isLocalAudioMuted: Bool {
        return userRequestedMute
    }
    
    // ✅ NEW: Apply initial mute state with proper timing
    private func applyInitialMuteState() {
        guard voiceManager.isJoined && isInLobby && !hasAppliedInitialMuteState else {
            print("⚠️ Cannot apply initial mute state - not ready")
            return
        }
        
        // Cancel any pending mute state sync
        muteStateSync?.cancel()
        
        // Create new mute state sync with delay
        muteStateSync = DispatchWorkItem { [weak self] in
            guard let self = self, self.voiceManager.isJoined && self.isInLobby else { return }
            
            let targetMuteState = self.muteStateBeforeJoin
            print("🔧 Applying initial mute state: \(targetMuteState)")
            
            // Force apply the correct mute state
            self.voiceManager.muteMic(targetMuteState)
            self.hasAppliedInitialMuteState = true
            
            // Verify the state was applied correctly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.voiceManager.isMuted != targetMuteState {
                    print("⚠️ Mute state verification failed - reapplying")
                    self.voiceManager.muteMic(targetMuteState)
                } else {
                    print("✅ Initial mute state applied and verified: \(targetMuteState)")
                }
            }
        }
        
        // Execute with appropriate delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: muteStateSync!)
    }
    
    // MARK: - ✅ COMPLETELY FIXED: Mode Configuration with Mute Bug Fix
    func transitionToLobby() {
        guard voiceManager.isJoined && !isConfiguring else {
            print("❌ Cannot configure for lobby: not connected or already configuring")
            return
        }
        
        isConfiguring = true
        print("🏠 🔄 Transitioning to LOBBY mode - open mic chat with user mute preference")
        
        isInLobby = true
        isInGame = false
        isInCutscene = false
        
        // Configure audio levels for lobby - everyone can hear
        voiceManager.adjustPlaybackVolume(200) // Can hear others
        voiceManager.adjustRecordingVolume(200) // Normal recording level
        
        // ✅ CRITICAL FIX: Apply mute state with proper timing
        print("🔧 Current mute preference: \(userRequestedMute)")
        
        // Force apply the user's mute preference with a small delay to ensure channel is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.voiceManager.muteMic(self.userRequestedMute)
            
            if self.userRequestedMute {
                print("✅ LOBBY configured: User muted (can hear, cannot speak)")
            } else {
                print("✅ LOBBY configured: Open mic for chat (can hear and speak)")
            }
            
            self.isConfiguring = false
            
            // ✅ CRITICAL FIX: Apply initial mute state if not yet applied
            if !self.hasAppliedInitialMuteState {
                self.applyInitialMuteState()
            }
        }
    }
    
    func transitionToCutscene() {
        guard voiceManager.isJoined && !isConfiguring else {
            print("❌ Cannot configure for cutscene: not connected or already configuring")
            return
        }
        
        isConfiguring = true
        print("📺 🔄 Transitioning to CUTSCENE mode - all audio disabled")
        
        isInLobby = false
        isInGame = false
        isInCutscene = true
        
        // Cancel any pending mute state sync
        muteStateSync?.cancel()
        hasAppliedInitialMuteState = true // Mark as applied to prevent interference
        
        // CUTSCENES: Nobody can speak or hear
        voiceManager.muteMic(true) // Nobody can speak
        voiceManager.adjustPlaybackVolume(0) // Nobody can hear
        voiceManager.adjustRecordingVolume(0) // Recording disabled
        
        print("✅ CUTSCENE configured: All audio disabled for all players")
        isConfiguring = false
    }
    
    func transitionToGame(playerRole: PlayerRole) {
        guard voiceManager.isJoined && !isConfiguring else {
            print("❌ Cannot configure for game: not connected or already configuring")
            return
        }
        
        isConfiguring = true
        currentPlayerRole = playerRole
        print("🎮 🔄 Transitioning to GAME mode with role: \(playerRole)")
        
        isInLobby = false
        isInGame = true
        isInCutscene = false
        
        // Cancel any pending mute state sync
        muteStateSync?.cancel()
        hasAppliedInitialMuteState = true // Mark as applied to prevent interference
        
        // Configure based on role with proper volume levels
        switch playerRole {
        case .blind:
            // BLIND (LUMO): Can hear and talk (push-to-talk)
            voiceManager.adjustPlaybackVolume(250) // CAN HEAR others clearly
            voiceManager.adjustRecordingVolume(200) // Normal recording when talking
            voiceManager.muteMic(true) // Start muted (push-to-talk)
            print("✅ BLIND (LUMO) configured: Can HEAR and TALK (push-to-talk)")
            
        case .deaf:
            // DEAF (VIBE): Cannot hear but can talk (push-to-talk)
            voiceManager.adjustPlaybackVolume(0) // CANNOT HEAR others
            voiceManager.adjustRecordingVolume(200) // Normal recording when talking
            voiceManager.muteMic(true) // Start muted (push-to-talk)
            print("✅ DEAF (VIBE) configured: Can TALK but CANNOT HEAR")
            
        case .mute:
            // MUTE (ECHO): Can hear but cannot talk (always muted)
            voiceManager.adjustPlaybackVolume(250) // CAN HEAR others clearly
            voiceManager.adjustRecordingVolume(0) // CANNOT TALK (recording disabled)
            voiceManager.muteMic(true) // Always muted
            print("✅ MUTE (ECHO) configured: Can HEAR but CANNOT TALK")
        }
        
        print("✅ Game mode configured successfully for \(playerRole)")
        isConfiguring = false
    }
    
    // MARK: - ✅ FIXED: Voice Actions for Game (Push-to-Talk)
    func startTalking(role: PlayerRole) -> Bool {
        guard voiceManager.isJoined && isInGame && !isConfiguring else {
            print("❌ Cannot talk: not in game mode, not connected, or configuring")
            return false
        }
        
        switch role {
        case .blind, .deaf:
            // Only these roles can talk in game
            if voiceManager.adjustRecordingVolume(200) == 0 { // Ensure recording is enabled
                voiceManager.adjustRecordingVolume(200)
            }
            voiceManager.muteMic(false)
            print("🎤 \(role) started talking (push-to-talk)")
            return true
            
        case .mute:
            print("🚫 MUTE cannot talk - role restriction (recording disabled)")
            return false
        }
    }
    
    func stopTalking(role: PlayerRole) {
        guard voiceManager.isJoined && isInGame && !isConfiguring else { return }
        
        switch role {
        case .blind, .deaf:
            voiceManager.muteMic(true)
            print("🎤 \(role) stopped talking (push-to-talk)")
            
        case .mute:
            break // Always muted anyway
        }
    }
    
    // MARK: - ✅ FIXED: Reconnection with proper state restoration and mute fix
    func reconnectCurrentChannel(playerRole: PlayerRole? = nil) {
        guard !currentChannelId.isEmpty else {
            print("⚠️ No channel to reconnect to")
            return
        }
        
        print("🔄 Reconnecting to same channel: \(currentChannelId)")
        
        // ✅ CRITICAL FIX: Store current mute state before leaving
        muteStateBeforeJoin = userRequestedMute
        hasAppliedInitialMuteState = false
        muteStateSync?.cancel()
        
        voiceManager.leaveChannel()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.voiceManager.joinChannel(channelId: self.currentChannelId)
            
            // Restore proper mode after reconnection
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let role = playerRole, self.isInGame {
                    self.transitionToGame(playerRole: role)
                } else if self.isInCutscene {
                    self.transitionToCutscene()
                } else {
                    self.transitionToLobby()
                }
                
                print("✅ Voice reconnected and mode restored")
            }
        }
    }
    
    // MARK: - Channel Cleanup with Mute State Reset
    func leaveAllChannels() {
        print("🚪 Leaving voice channel and cleaning up")
        
        // Cancel any pending mute state operations
        muteStateSync?.cancel()
        
        if voiceManager.isJoined {
            voiceManager.leaveChannel()
        }
        
        currentChannelId = ""
        isInLobby = false
        isInGame = false
        isInCutscene = false
        playersInChannel.removeAll()
        isConfiguring = false
        
        // ✅ CRITICAL FIX: Reset mute state tracking
        hasAppliedInitialMuteState = false
        muteStateBeforeJoin = userRequestedMute
        
        // Don't reset userRequestedMute - preserve user preference
        print("✅ Voice channels left and state cleaned up")
    }
    
    // MARK: - Connection Status
    var isConnected: Bool {
        return voiceManager.isJoined && !currentChannelId.isEmpty
    }
    
    var connectionStatus: String {
        if !isConnected {
            return "Disconnected"
        }
        
        if isInCutscene {
            return "Cutscene (All Muted)"
        } else if isInGame {
            let roleCapability = currentPlayerRole.voiceDescription
            return "Game: \(roleCapability)"
        } else if isInLobby {
            let muteStatus = userRequestedMute ? " (Self-Muted)" : ""
            return "Lobby\(muteStatus)"
        }
        
        return "Connected"
    }
    
    // MARK: - ✅ IMPROVED: Voice Status for UI
    var voiceStatusForUI: String {
        if !isConnected {
            return "Connecting..."
        }
        
        if isInCutscene {
            return "Cutscene Mode"
        } else if isInGame {
            switch currentPlayerRole {
            case .blind: return "LUMO (Hear+Talk)"   // BLIND = LUMO
            case .deaf: return "VIBE (Talk Only)"    // DEAF = VIBE
            case .mute: return "ECHO (Hear Only)"    // MUTE = ECHO
            }
        } else if isInLobby {
            return userRequestedMute ? "Lobby (Muted)" : "Lobby Chat"
        }
        
        return "Connected"
    }
    
    var canTalk: Bool {
        if isConfiguring {
            return false
        }
        
        if isInCutscene {
            return false // Nobody can talk during cutscenes
        } else if isInLobby {
            return !userRequestedMute // In lobby, can talk unless manually muted
        } else if isInGame {
            // In game, depends on role
            switch currentPlayerRole {
            case .blind, .deaf: return true // Can use push-to-talk
            case .mute: return false // Cannot talk at all
            }
        }
        
        return false
    }
    
    var canHear: Bool {
        if isConfiguring {
            return false
        }
        
        if isInCutscene {
            return false // Nobody can hear during cutscenes
        } else if isInLobby {
            return true // Can always hear in lobby
        } else if isInGame {
            // In game, depends on role
            switch currentPlayerRole {
            case .blind, .mute: return true // Can hear
            case .deaf: return false // Cannot hear
            }
        }
        
        return false
    }
    
    // MARK: - ✅ IMPROVED: Debug Info with Mute State Details
    func getDebugInfo() -> String {
        return """
        📡 Current Channel: \(currentChannelId)
        🔗 Voice Connected: \(voiceManager.isJoined)
        🏛️ In Lobby: \(isInLobby)
        📺 In Cutscene: \(isInCutscene)
        🎮 In Game: \(isInGame) (Role: \(currentPlayerRole))
        👥 Remote Users: \(voiceManager.remoteUsers.count)
        🎤 Currently Muted: \(voiceManager.isMuted)
        🔇 User Requested Mute: \(userRequestedMute)
        🔧 Mute Before Join: \(muteStateBeforeJoin)
        ✅ Initial Mute Applied: \(hasAppliedInitialMuteState)
        ⚙️ Is Configuring: \(isConfiguring)
        🔊 Can Talk: \(canTalk)
        👂 Can Hear: \(canHear)
        """
    }
    
    func debugChannelInfo() {
        print("🔍 VoiceChannelManager Debug Info:")
        print("   - Current Channel: \(currentChannelId)")
        print("   - Is Connected: \(isConnected)")
        print("   - Mode: Lobby:\(isInLobby) | Cutscene:\(isInCutscene) | Game:\(isInGame)")
        print("   - Role: \(currentPlayerRole) | Can Talk: \(canTalk) | Can Hear: \(canHear)")
        print("   - User Muted: \(userRequestedMute) | System Muted: \(voiceManager.isMuted)")
        print("   - Mute Before Join: \(muteStateBeforeJoin) | Initial Applied: \(hasAppliedInitialMuteState)")
        print("   - Remote Users: \(voiceManager.remoteUsers.count)")
        print("   - Agora State: \(voiceManager.connectionState.rawValue)")
        print("   - Is Configuring: \(isConfiguring)")
    }
    
    // MARK: - Error Handling with State Recovery and Mute Fix
    func handleVoiceError(_ error: Error) {
        print("❌ Voice error: \(error.localizedDescription)")
        
        // Cancel any pending mute operations
        muteStateSync?.cancel()
        hasAppliedInitialMuteState = false
        
        // Attempt to recover with current mode
        if !currentChannelId.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("🔄 Attempting to recover from voice error...")
                
                let wasInGame = self.isInGame
                let wasInCutscene = self.isInCutscene
                let role = self.currentPlayerRole
                
                self.reconnectCurrentChannel()
                
                // Restore the correct mode after reconnection
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if wasInGame {
                        self.transitionToGame(playerRole: role)
                    } else if wasInCutscene {
                        self.transitionToCutscene()
                    } else {
                        self.transitionToLobby()
                    }
                }
            }
        }
    }
    
    // MARK: - Force Configuration Refresh (for troubleshooting)
    func forceRefreshConfiguration() {
        print("🔄 Force refreshing voice configuration...")
        
        guard voiceManager.isJoined else {
            print("❌ Cannot refresh: not connected to voice")
            return
        }
        
        // Cancel any pending operations
        muteStateSync?.cancel()
        hasAppliedInitialMuteState = false
        
        if isInGame {
            transitionToGame(playerRole: currentPlayerRole)
        } else if isInCutscene {
            transitionToCutscene()
        } else {
            transitionToLobby()
        }
    }
    
    // ✅ NEW: Force apply correct mute state (for debugging)
    func forceApplyMuteState() {
        guard voiceManager.isJoined && isInLobby else {
            print("⚠️ Cannot force apply mute state - not in lobby or not connected")
            return
        }
        
        print("🔧 Force applying mute state: \(userRequestedMute)")
        voiceManager.muteMic(userRequestedMute)
        hasAppliedInitialMuteState = true
        
        // Verify after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.voiceManager.isMuted == self.userRequestedMute {
                print("✅ Force mute state application successful")
            } else {
                print("❌ Force mute state application failed")
            }
        }
    }
}

// MARK: - PlayerRole Extension - ✅ FIXED: Mapping corretto dei ruoli
extension PlayerRole {
    var voiceCapabilities: (canHear: Bool, canTalk: Bool) {
        switch self {
        case .blind: return (canHear: true, canTalk: true)   // LUMO
        case .deaf: return (canHear: false, canTalk: true)   // VIBE
        case .mute: return (canHear: true, canTalk: false)   // ECHO
        }
    }
    
    var voiceDescription: String {
        switch self {
        case .blind: return "LUMO (Hear+Talk)"    // BLIND = LUMO
        case .deaf: return "VIBE (Talk Only)"     // DEAF = VIBE
        case .mute: return "ECHO (Hear Only)"     // MUTE = ECHO
        }
    }
    
    var gameVoiceDescription: String {
        switch self {
        case .blind: return "Can hear and talk (push-to-talk)"    // LUMO
        case .deaf: return "Can talk but cannot hear (push-to-talk)"  // VIBE
        case .mute: return "Can hear but cannot talk (listen-only)"   // ECHO
        }
    }
}
