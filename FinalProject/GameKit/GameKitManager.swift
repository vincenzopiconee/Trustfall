//
//  GameKitManager.swift
//  FinalProject
//
//  ADDED: Player exit notification system
//

import SwiftUI
import GameKit

class GameKitManager: NSObject, ObservableObject, GKMatchDelegate, GKMatchmakerViewControllerDelegate, GKLocalPlayerListener {
    static let shared = GameKitManager()

    @Published var isAuthenticated = false
    @Published var match: GKMatch?
    @Published var players: [GKPlayer] = []
    @Published var assignedRoles: [String: PlayerRole] = [:]
    @Published var selectedCharacters: [String: String] = [:] // gamePlayerID -> character name
    @Published var errorMessage: String?
    @Published var gameStarted = false
    @Published var isHost: Bool = false
    @Published var inLobby: Bool = false
    @Published var currentPlayerRole: PlayerRole? = nil
    @Published var cutsceneFinished = false
    @Published var skipRequests: Set<String> = [] // Track who requested skip
    @Published var allPlayersSkipRequested = false
    
    // Stati per coordinamento post-cutscene
    @Published var playersReadyForGame: Set<String> = []
    @Published var allPlayersReadyForGame = false
    
    // Stati per restart ready system
    @Published var playersReadyForRestart: Set<String> = []
    @Published var allPlayersReadyForRestart = false
    
    // Sincronizzazione scene cutscene
    @Published var currentCutsceneStep: Int = 0
    @Published var canAdvanceScene: Bool = false
    
    // ✅ NEW: Player exit alert system
    @Published var showPlayerExitAlert = false
    @Published var exitedPlayerName = ""
    
    // Voice Channel fisso per tutta la sessione
    @Published var lobbyVoiceChannelId: String?

    private override init() {
        super.init()
        authenticateLocalPlayer()
    }

    func authenticateLocalPlayer() {
        GKLocalPlayer.local.authenticateHandler = { vc, error in
            if let vc = vc {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.present(vc, animated: true)
                }
            } else if GKLocalPlayer.local.isAuthenticated {
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    GKLocalPlayer.local.register(self)
                }
            }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Errore autenticazione: \(error.localizedDescription)"
                }
            }
        }
    }

    func startHosting() {
        guard isAuthenticated else { return }
        print("🎮 Starting to host game...")
        
        isHost = true
        players = [GKLocalPlayer.local]
        inLobby = true
        resetAllGameStates()
        
        // Genera il voice channel ID subito quando crei la lobby
        generateLobbyVoiceChannel()
        
        // Assign role to host immediately
        assignRoleToPlayer(GKLocalPlayer.local)
        
        print("✅ Host setup completed with voice channel: \(lobbyVoiceChannelId ?? "error")")
    }

    // Genera voice channel quando si crea la lobby
    private func generateLobbyVoiceChannel() {
        let timestamp = Int(Date().timeIntervalSince1970)
        let hostId = GKLocalPlayer.local.gamePlayerID.prefix(6)
        let channelId = "lobby_\(hostId)_\(timestamp)"
        
        lobbyVoiceChannelId = channelId
        
        print("🆔 HOST created lobby voice channel: \(channelId)")
        print("   This channel will be used for both lobby and game modes")
    }

    // Reset completo di tutti gli stati
    private func resetAllGameStates() {
        assignedRoles = [:]
        selectedCharacters = [:]
        gameStarted = false
        currentPlayerRole = nil
        cutsceneFinished = false
        skipRequests = []
        allPlayersSkipRequested = false
        playersReadyForGame = []
        allPlayersReadyForGame = false
        playersReadyForRestart = []
        allPlayersReadyForRestart = false
        currentCutsceneStep = 0
        canAdvanceScene = false
        
        // ✅ NEW: Reset player exit states
        showPlayerExitAlert = false
        exitedPlayerName = ""
    }

    func updatePlayers() {
        guard let match = self.match else {
            if isHost {
                players = [GKLocalPlayer.local]
            }
            return
        }
        
        let allPlayers = [GKLocalPlayer.local] + match.players.filter { $0.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
        let oldCount = self.players.count
        self.players = allPlayers
        
        print("👥 Players updated: \(oldCount) -> \(allPlayers.count)")
        
        // Assign roles to new players if host
        if isHost {
            for player in allPlayers {
                if assignedRoles[player.gamePlayerID] == nil {
                    assignRoleToPlayer(player)
                }
            }
            sendRolesToOthers()
            
            // Invia voice channel a nuovi player che si uniscono
            if let channelId = lobbyVoiceChannelId {
                sendVoiceChannelIdToOthers(channelId)
            }
        }
    }

    func assignRoleToPlayer(_ player: GKPlayer) {
        guard isHost else { return }
        
        let availableRoles = PlayerRole.allCases.filter { role in
            !assignedRoles.values.contains(role)
        }
        
        if let randomRole = availableRoles.randomElement() {
            assignedRoles[player.gamePlayerID] = randomRole
            print("🎭 Assigned role \(randomRole) to \(player.displayName)")
            
            if player.gamePlayerID == GKLocalPlayer.local.gamePlayerID {
                currentPlayerRole = randomRole
            }
        }
    }

    // Solo condivisione del channel ID
    private func sendVoiceChannelIdToOthers(_ channelId: String) {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.voiceChannelAssigned(channelId)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
                print("📤 Sent lobby voice channel ID to all players: \(channelId)")
            } catch {
                print("❌ Error sending voice channel ID: \(error)")
            }
        }
    }

    // Sempre lo stesso channel ID
    func getVoiceChannelId() -> String? {
        if let channelId = lobbyVoiceChannelId {
            print("🆔 Using lobby voice channel: \(channelId)")
            return channelId
        }
        
        // Fallback solo per sviluppo
        print("⚠️ No lobby voice channel available")
        return nil
    }
    
    // Debug function
    func debugVoiceChannelSync() {
        print("🔍 VOICE CHANNEL DEBUG:")
        print("  - Is Host: \(isHost)")
        print("  - Players count: \(players.count)")
        print("  - Players IDs: \(players.map { $0.gamePlayerID })")
        print("  - Lobby Channel ID: \(lobbyVoiceChannelId ?? "nil")")
        
        if let channelId = lobbyVoiceChannelId {
            print("✅ All players should use channel: \(channelId)")
        } else {
            print("❌ No lobby channel - this is a problem!")
        }
    }

    // Send difficulty to other players
    func sendDifficultyToOthers(_ difficulty: GameDifficulty) {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.difficultyChanged(difficulty)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
                print("📤 Sent difficulty setting: \(difficulty.rawValue) (\(difficulty.timeString))")
            } catch {
                print("❌ Error sending difficulty: \(error)")
            }
        }
    }

    func selectCharacter(_ characterName: String) {
        selectedCharacters[GKLocalPlayer.local.gamePlayerID] = characterName
        sendCharacterSelectionToOthers(characterName: characterName)
    }

    func sendCharacterSelectionToOthers(characterName: String) {
        guard let match = match else { return }
        
        let message = GameMessage.characterSelected(GKLocalPlayer.local.gamePlayerID, characterName)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio selezione personaggio: \(error.localizedDescription)")
            }
        }
    }

    func sendRolesToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.rolesAssigned(assignedRoles)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio ruoli: \(error.localizedDescription)")
            }
        }
    }

    func requestSkip() {
        skipRequests.insert(GKLocalPlayer.local.gamePlayerID)
        sendSkipRequestToOthers()
        
        if skipRequests.count >= players.count {
            allPlayersSkipRequested = true
            if isHost {
                sendCutsceneSkippedToOthers()
            }
        }
    }
    
    func sendSkipRequestToOthers() {
        guard let match = match else { return }
        
        let message = GameMessage.skipRequested(GKLocalPlayer.local.gamePlayerID)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio richiesta skip: \(error.localizedDescription)")
            }
        }
    }
    
    func advanceCutsceneScene() {
        guard isHost else { return }
        
        currentCutsceneStep += 1
        sendSceneAdvancedToOthers()
    }
    
    func sendSceneAdvancedToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.sceneAdvanced(currentCutsceneStep)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio avanzamento scena: \(error.localizedDescription)")
            }
        }
    }
    
    func sendCutsceneSkippedToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.cutsceneSkipped
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio cutscene saltata: \(error.localizedDescription)")
            }
        }
    }

    func markPlayerReadyForGame() {
        playersReadyForGame.insert(GKLocalPlayer.local.gamePlayerID)
        sendPlayerReadyToOthers()
        
        if playersReadyForGame.count >= players.count {
            allPlayersReadyForGame = true
            if isHost {
                sendAllPlayersReadyToOthers()
            }
        }
    }
    
    func sendPlayerReadyToOthers() {
        guard let match = match else { return }
        
        let message = GameMessage.playerReady(GKLocalPlayer.local.gamePlayerID)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio player ready: \(error.localizedDescription)")
            }
        }
    }
    
    func sendAllPlayersReadyToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.allPlayersReady
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio all players ready: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Restart Ready System
    func requestRestart() {
        playersReadyForRestart.insert(GKLocalPlayer.local.gamePlayerID)
        sendRestartRequestToOthers()
        
        if playersReadyForRestart.count >= players.count {
            allPlayersReadyForRestart = true
            if isHost {
                sendAllPlayersReadyForRestartToOthers()
            }
        }
    }
    
    func cancelRestartRequest() {
        playersReadyForRestart.remove(GKLocalPlayer.local.gamePlayerID)
        sendRestartCancelToOthers()
        
        allPlayersReadyForRestart = false
        if isHost {
            sendRestartCancelledToOthers()
        }
    }
    
    func resetForRestart() {
        // Reset solo gli stati del gioco, mantenendo lobby e voice channel
        playersReadyForRestart = []
        allPlayersReadyForRestart = false
        gameStarted = false
        cutsceneFinished = false
        skipRequests = []
        allPlayersSkipRequested = false
        playersReadyForGame = []
        allPlayersReadyForGame = false
        currentCutsceneStep = 0
        canAdvanceScene = false
        
        print("🔄 Game states reset for restart - keeping lobby and voice channel")
    }
    
    private func sendRestartRequestToOthers() {
        guard let match = match else { return }
        
        let message = GameMessage.restartRequested(GKLocalPlayer.local.gamePlayerID)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio restart request: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendRestartCancelToOthers() {
        guard let match = match else { return }
        
        let message = GameMessage.restartCancelled(GKLocalPlayer.local.gamePlayerID)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio restart cancel: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendAllPlayersReadyForRestartToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.allPlayersReadyForRestart
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio all players ready for restart: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendRestartCancelledToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.allRestartsCancelled
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio all restarts cancelled: \(error.localizedDescription)")
            }
        }
    }

    // ✅ NEW: Player Exit System
    func exitGameAndNotifyOthers() {
        print("🚪 Player exiting and notifying others...")
        
        // Get player name for the alert
        let playerName = GKLocalPlayer.local.displayName
        
        // Send exit message to other players
        if let match = self.match {
            let message = GameMessage.playerExitedGame(playerName)
            if let data = try? JSONEncoder().encode(message) {
                do {
                    try match.sendData(toAllPlayers: data, with: .reliable)
                    print("📤 Sent player exit notification: \(playerName)")
                } catch {
                    print("❌ Error sending exit notification: \(error)")
                }
            }
        }
        
        // Clean up and exit
        VoiceChannelManager.shared.leaveAllChannels()
        AgoraVoiceManager.shared.destroyInstance()
        SharedGameStateManager.shared.resetGame()
        resetMatch()
    }
    
    func returnToMainMenu() {
        print("🏠 Returning all players to main menu...")
        
        // Clean up voice and game state
        VoiceChannelManager.shared.leaveAllChannels()
        AgoraVoiceManager.shared.destroyInstance()
        SharedGameStateManager.shared.resetGame()
        
        // Reset match and return to menu
        resetMatch()
        
        // Reset alert state
        showPlayerExitAlert = false
        exitedPlayerName = ""
    }

    func startGame() {
        guard isHost, players.count == 3, allPlayersHaveCharacters() else { return }
        
        print("🚀 Starting game with lobby voice channel: \(getVoiceChannelId() ?? "unknown")")
        print("   Voice channel switches to GAME MODE with push-to-talk")
        
        trackGameStart()
        
        DispatchQueue.main.async {
            SharedGameStateManager.shared.generateAndShareBatterySequence()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sendStartGameToOthers()
                self.gameStarted = true
            }
        }
    }

    func sendStartGameToOthers() {
        guard let match = match, isHost else { return }
        
        let message = GameMessage.gameStarted
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio start: \(error.localizedDescription)")
            }
        }
    }

    func sendCutsceneFinished() {
        guard let match = match else { return }
        
        let message = GameMessage.cutsceneFinished(GKLocalPlayer.local.gamePlayerID)
        if let data = try? JSONEncoder().encode(message) {
            do {
                try match.sendData(toAllPlayers: data, with: .reliable)
            } catch {
                print("Errore invio cutscene finita: \(error.localizedDescription)")
            }
        }
    }

    func exitGame() {
        print("🚪 Exiting game...")
        
        VoiceChannelManager.shared.leaveAllChannels()
        resetMatch()
    }

    func allPlayersHaveCharacters() -> Bool {
        guard players.count == 3 else { return false }
        return players.allSatisfy { player in
            selectedCharacters[player.gamePlayerID] != nil
        }
    }

    func getSelectedCharacterNames() -> Set<String> {
        return Set(selectedCharacters.values)
    }

    func resetMatch() {
        if let match = self.match {
            match.disconnect()
        }
        
        DispatchQueue.main.async {
            self.match = nil
            self.players = []
            self.resetAllGameStates()
            self.errorMessage = nil
            self.isHost = false
            self.inLobby = false
            
            // Reset anche il voice channel quando esci completamente
            self.lobbyVoiceChannelId = nil
            
            print("✅ Game state reset - including voice channel")
        }
    }

    // MARK: - Statistics Integration
    func trackGameStart() {
        guard let role = currentPlayerRole else {
            print("⚠️ Cannot track game start - no role assigned")
            return
        }
        
        let isHost = (role == .mute)
        GameStatisticsManager.shared.recordGameStart(isHost: isHost)
        
        print("📊 Game started - Role: \(role), IsHost: \(isHost)")
    }

    func trackGameEnd(won: Bool, timeRemaining: Int) {
        if won {
            GameStatisticsManager.shared.recordGameWon(timeRemainingSeconds: timeRemaining)
            print("📊 Game won - Time remaining: \(timeRemaining)s")
        }
        
        print("📊 Game ended - Won: \(won), Errors: \(SharedGameStateManager.shared.totalErrors)")
    }

    // MARK: - GKMatchDelegate
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        // Gestione messaggi game state (priorità massima)
        if let gameStateMessage = try? JSONDecoder().decode(GameStateMessage.self, from: data) {
            SharedGameStateManager.shared.handleReceivedMessage(gameStateMessage)
            return
        }
        
        // Gestione GameMessage
        guard let message = try? JSONDecoder().decode(GameMessage.self, from: data) else { return }
        
        DispatchQueue.main.async {
            switch message {
            case .rolesAssigned(let roles):
                self.assignedRoles = roles
                self.currentPlayerRole = roles[GKLocalPlayer.local.gamePlayerID]
                print("🎭 Received role assignment: \(self.currentPlayerRole?.rawValue ?? "none")")
                
            case .gameStarted:
                print("🚀 Game started by host - switching voice channel to GAME MODE")
                self.gameStarted = true
                self.trackGameStart()
                
                if SharedGameStateManager.shared.batterySequence.isEmpty {
                    print("🔄 Requesting battery sequence from host...")
                    SharedGameStateManager.shared.requestBatterySequence()
                }
                
            case .characterSelected(let playerID, let characterName):
                self.selectedCharacters[playerID] = characterName
                print("👤 Player selected character: \(characterName)")
                
            case .cutsceneFinished(_):
                break
                
            case .skipRequested(let playerID):
                self.skipRequests.insert(playerID)
                if self.skipRequests.count >= self.players.count {
                    self.allPlayersSkipRequested = true
                }
                
            case .playerReady(let playerID):
                self.playersReadyForGame.insert(playerID)
                print("✅ Player ready for game: \(playerID)")
                if self.playersReadyForGame.count >= self.players.count {
                    self.allPlayersReadyForGame = true
                }
                
            case .allPlayersReady:
                self.allPlayersReadyForGame = true
                print("🎮 All players ready - game starting!")
                
            case .sceneAdvanced(let stepNumber):
                self.currentCutsceneStep = stepNumber
                print("📺 Scene advanced to step: \(stepNumber)")
                
            case .cutsceneSkipped:
                self.allPlayersSkipRequested = true
                print("⏭️ Cutscene skipped by all players")
                
            case .restartRequested(let playerID):
                self.playersReadyForRestart.insert(playerID)
                print("🔄 Player ready for restart: \(playerID)")
                if self.playersReadyForRestart.count >= self.players.count {
                    self.allPlayersReadyForRestart = true
                }
                
            case .restartCancelled(let playerID):
                self.playersReadyForRestart.remove(playerID)
                print("❌ Player cancelled restart: \(playerID)")
                
            case .allPlayersReadyForRestart:
                self.allPlayersReadyForRestart = true
                print("🔄 All players ready for restart!")
                
            case .allRestartsCancelled:
                self.playersReadyForRestart.removeAll()
                self.allPlayersReadyForRestart = false
                print("❌ All restart requests cancelled")
                
            case .voiceChannelAssigned(let channelId):
                print("📡 Received lobby voice channel from host: \(channelId)")
                self.lobbyVoiceChannelId = channelId
                
            case .difficultyChanged(let difficulty):
                print("📡 Received difficulty change: \(difficulty.rawValue) (\(difficulty.timeString))")
                SharedGameStateManager.shared.setGameDuration(difficulty.timeInSeconds)
                
            // ✅ NEW: Handle player exit
            case .playerExitedGame(let playerName):
                print("📡 Received: Player \(playerName) exited the game")
                self.exitedPlayerName = playerName
                self.showPlayerExitAlert = true
                
                // After showing alert, return to menu
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    self.returnToMainMenu()
                }
            }
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("👤 Player connected: \(player.displayName)")
                self.updatePlayers()
            case .disconnected:
                print("👋 Player disconnected: \(player.displayName)")
                self.updatePlayers()
                if self.players.isEmpty {
                    self.resetMatch()
                }
            default:
                break
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async {
            self.errorMessage = error?.localizedDescription ?? "Errore match"
            print("❌ Match failed: \(self.errorMessage ?? "unknown error")")
        }
    }

    // MARK: - GKMatchmakerViewControllerDelegate
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        print("❌ Matchmaking cancelled")
        viewController.dismiss(animated: true)
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Errore matchmaking: \(error.localizedDescription)"
            print("❌ Matchmaking failed: \(error.localizedDescription)")
        }
        viewController.dismiss(animated: true)
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        print("✅ Match found")
        self.match = match
        match.delegate = self
        
        DispatchQueue.main.async {
            self.updatePlayers()
            self.inLobby = true
        }
        
        viewController.dismiss(animated: true)
    }

    // MARK: - GKLocalPlayerListener
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        guard let mmvc = GKMatchmakerViewController(invite: invite) else { return }
        mmvc.matchmakerDelegate = self
        isHost = false
        
        print("📧 Accepted invite from: \(invite.sender.displayName)")
        
        DispatchQueue.main.async {
            UIApplication.shared.topViewController?.present(mmvc, animated: true)
        }
    }
}

// MARK: - ✅ UPDATED: Game Messages with Player Exit
enum GameMessage: Codable {
    case rolesAssigned([String: PlayerRole])
    case gameStarted
    case characterSelected(String, String) // playerID, characterName
    case cutsceneFinished(String) // playerID
    case skipRequested(String) // playerID
    case playerReady(String) // playerID quando pronto per iniziare il gioco
    case allPlayersReady // tutti i giocatori sono pronti
    case sceneAdvanced(Int) // sincronizzazione scene cutscene
    case cutsceneSkipped // cutscene saltata da tutti
    
    // Messaggi per restart ready system
    case restartRequested(String) // playerID che vuole restart
    case restartCancelled(String) // playerID che cancella restart
    case allPlayersReadyForRestart // tutti pronti per restart
    case allRestartsCancelled // tutti i restart cancellati
    
    // Voice channel assignment
    case voiceChannelAssigned(String) // Host → Players: ecco il channel ID della lobby
    
    // Difficulty support
    case difficultyChanged(GameDifficulty) // Host → Players: difficoltà cambiata
    
    // ✅ NEW: Player exit notification
    case playerExitedGame(String) // playerName
}

// MARK: - UIApplication Extension
extension UIApplication {
    var topViewController: UIViewController? {
        guard let window = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
