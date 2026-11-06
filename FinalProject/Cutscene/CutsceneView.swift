//
//  CutsceneView.swift
//  FinalProject
//
//  FIXED: Proper audio management during cutscenes + ROLE NAMES CORRECTED + UnifiedExitAlert
//

import SwiftUI
import GameKit

struct CutsceneSequenceView: View {
    @State private var displayedText = ""
    @State private var charIndex = 0
    @State private var timer: Timer?
    @State private var isTransitioning = false
    @State private var cutsceneCompleted = false
    @State private var showExitAlert = false
    @State private var shouldStartGame = false
    @State private var showInterlude = false

    @ObservedObject private var gkManager = GameKitManager.shared

    var playerRole: PlayerRole
    var playerID: Int // 0, 1, or 2
    var characterNames: [String] // ["Anna", "Betty", "Erik"]

    let totalPlayers = 3
    
    // ✅ NUEVO: Usa la scena sincronizzata dal GameKitManager
    private var currentStep: Int {
        gkManager.currentCutsceneStep
    }

    let sharedScenes: [SceneData] = [
        .init(background: Color.black, speaker: nil, text: "SUMMER NIGHT AT THE USUAL BONFIRE", isFullCenter: true),
        .init(backgroundImage: "artwork1", speaker: "PLAYER1", text: "Uh, guys? Do you see that? What is that?!"),
        .init(backgroundImage: "artwork1", speaker: "PLAYER2", text: "See what?"),
        .init(backgroundImage: "artwork2", speaker: "PLAYER1", text: "Up there, in the sky…"),
        .init(backgroundImage: "artwork2", speaker: "PLAYER3", text: "Is that, like, a giant drone or something?"),
        .init(backgroundImage: "artwork2", speaker: "PLAYER2", text: "No way, that's way too big to be a drone…"),
        .init(background: Color.black, speaker: nil, text: "", isSilent: true),
        .init(backgroundImage: "risucchio_ufo", speaker: nil, text: "", isSilent: true),
        .init(background: Color.black, speaker: nil, text: "", isSilent: true),
        .init(backgroundImage: "stanza_esperimenti_aliena", speaker: "ALIEN", text: "⟆⟟⋉⧫⟟⋉⏃⍀⋔ ⟒⧫⍜⋏⏁⋔⟟⋉⟒⍀.", isAlienLanguage: true),
        .init(backgroundImage: "stanza_esperimenti_aliena", speaker: "", text: "SELECTED INDIVIDUALS. PROTOCOL INITIATED.", isAlienLanguage: true)
    ]

    var shouldShowRoleView: Bool {
        gkManager.allPlayersSkipRequested || (currentStep >= sharedScenes.count && cutsceneCompleted)
    }

    var body: some View {
        ZStack {
            if showInterlude {
                InterludeGameOne()
                    .transition(.opacity)
                    .zIndex(100)
            } else if shouldStartGame {
                GameRouterView(playerRole: playerRole)
                    .transition(.opacity)
            } else if !shouldShowRoleView {
                if let scene = sharedScenes[safe: currentStep] {
                    let speakerName = replacedSpeaker(scene.speaker)
                    let text = replacedText(scene.text)
                    BrutalistSceneView(
                        scene: scene.withSpeaker(speakerName).withText(text),
                        displayedText: displayedText
                    )
                    .opacity(1.0)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
                    .animation(.easeInOut(duration: 0.6), value: currentStep)
                }
                
                // Exit button
                VStack {
                    HStack {
                        Button(action: { showExitAlert = true }) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 120, height: 40)
                                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                                HStack(spacing: 4) {
                                    Text("EXIT")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                    Spacer()
                }
                
            } else {
                BrutalistRoleView(role: playerRole)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .animation(.easeInOut(duration: 0.8), value: shouldShowRoleView)
                
                // Exit e Ready buttons per la role view
                VStack {
                    HStack {
                        Button(action: { showExitAlert = true }) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 120, height: 40)
                                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                                HStack(spacing: 4) {
                                    Text("EXIT")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                    Spacer()
                    
                    // Ready button con contatore (ridotto)
                    Button(action: {
                        gkManager.markPlayerReadyForGame()
                        gkManager.sendCutsceneFinished()
                    }) {
                        VStack(spacing: 4) {
                            Text(gkManager.playersReadyForGame.contains(GKLocalPlayer.local.gamePlayerID) ? "WAITING FOR OTHERS" : "READY FOR GAME")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                            
                            if gkManager.playersReadyForGame.count > 0 {
                                Text("(\(gkManager.playersReadyForGame.count)/3) READY")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                        .frame(width: 200, height: 56)
                        .background(Color.white)
                    }
                    .disabled(gkManager.playersReadyForGame.contains(GKLocalPlayer.local.gamePlayerID))
                    .opacity(gkManager.playersReadyForGame.contains(GKLocalPlayer.local.gamePlayerID) ? 0.6 : 1.0)
                    .scaleEffect(gkManager.playersReadyForGame.contains(GKLocalPlayer.local.gamePlayerID) ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: gkManager.playersReadyForGame.contains(GKLocalPlayer.local.gamePlayerID))
                    .padding(.bottom, 10)
                }
            }

            // ✅ FIXED: Skip button sempre visibile durante le scene cutscene
            if !shouldShowRoleView && !showInterlude && !shouldStartGame {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            // Solo richiedi skip se non lo hai già fatto
                            if !gkManager.skipRequests.contains(GKLocalPlayer.local.gamePlayerID) {
                                gkManager.requestSkip()
                            }
                        }) {
                            ZStack {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 120, height: 40)
                                    .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                                HStack(spacing: 4) {
                                    Text("SKIP")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text("(\(gkManager.skipRequests.count)/\(totalPlayers))")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        // ✅ FIXED: Rimuovi la disabilitazione del pulsante - mostra sempre il contatore
                        .scaleEffect(gkManager.skipRequests.contains(GKLocalPlayer.local.gamePlayerID) ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: gkManager.skipRequests)
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }
            
            // ✅ FIXED: Use UnifiedExitAlert instead of ExitGameAlert
            UnifiedExitAlert(isPresented: $showExitAlert) {
                GameKitManager.shared.exitGameAndNotifyOthers()
            }
            
            // ✅ UNIFIED: Remote player exit alert
            UnifiedExitAlert(
                playerName: gkManager.exitedPlayerName,
                isPresented: $gkManager.showPlayerExitAlert
            ) {
                gkManager.returnToMainMenu()
            }
        }
        .onTapGesture {
            // ✅ MODIFICATO: Solo l'host può avanzare le scene con tap
            if !isTransitioning && !shouldShowRoleView && !showInterlude && !shouldStartGame && gkManager.isHost {
                nextScene()
            }
        }
        .onAppear {
            startTyping()
            // ✅ FIXED: Configura audio per cutscene
            configureCutsceneAudio()
        }
        .onDisappear {
            // ✅ FIXED: Ripristina audio quando si esce dalle cutscene
            restoreAudioAfterCutscene()
        }
        .onChange(of: currentStep) { _, _ in
            // ✅ MODIFICATO: Reagisce ai cambiamenti della scena sincronizzata
            startTyping()
            if currentStep >= sharedScenes.count && !cutsceneCompleted {
                cutsceneCompleted = true
            }
        }
        .onChange(of: gkManager.allPlayersSkipRequested) { _, newValue in
            if newValue {
                withAnimation {
                    // ✅ MODIFICATO: Salta direttamente alla role view
                    cutsceneCompleted = true
                }
            }
        }
        .onChange(of: shouldShowRoleView) { _, newValue in
            // ✅ FIXED: Gestisci audio quando passi alla role view
            if newValue {
                restoreAudioAfterCutscene() // Riattiva audio per role view
            } else {
                configureCutsceneAudio() // Disattiva audio per cutscene
            }
        }
        // ✅ MODIFICATO: Observer per mostrare l'interlude prima del gioco
        .onChange(of: gkManager.allPlayersReadyForGame) { _, newValue in
            if newValue {
                print("🎮 All players ready - showing interlude...")
                
                // ✅ NUEVO: Mostra l'interlude per 4 secondi
                withAnimation(.easeInOut(duration: 0.5)) {
                    showInterlude = true
                }
                
                // ✅ NUEVO: Dopo 4 secondi, inizia il gioco vero
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showInterlude = false
                        shouldStartGame = true
                    }

                    print("🚀 Starting actual game after interlude")
                }
            }
        }
    }

    
    // ✅ FIXED: Funzioni per gestire l'audio durante le cutscene
    private func configureCutsceneAudio() {
        print("📺 Configuring audio for cutscene mode")
        
        // Use the voice channel manager to properly configure cutscene mode
        VoiceChannelManager.shared.transitionToCutscene()
    }
    
    private func restoreAudioAfterCutscene() {
        print("🔊 Restoring audio after cutscene")
        
        // Check if we're going to game or back to lobby
        if shouldStartGame {
            // Don't restore here - the game will configure audio appropriately
            print("   → Game will configure audio based on player role")
        } else {
            // Return to lobby configuration
            VoiceChannelManager.shared.transitionToLobby()
        }
    }

    private func startTyping() {
        timer?.invalidate()
        displayedText = ""
        charIndex = 0
        guard !shouldShowRoleView, let fullText = sharedScenes[safe: currentStep]?.text, !fullText.isEmpty else { return }
        let replacedFullText = replacedText(fullText)
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            if charIndex < replacedFullText.count {
                let index = replacedFullText.index(replacedFullText.startIndex, offsetBy: charIndex)
                displayedText.append(replacedFullText[index])
                charIndex += 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func nextScene() {
        // ✅ NUEVO: Solo l'host può avanzare le scene, e invia a tutti
        guard gkManager.isHost else { return }
        
        withAnimation {
            gkManager.advanceCutsceneScene()
        }
    }

    // MARK: - REPLACEMENT LOGIC
    private func replacedSpeaker(_ speaker: String?) -> String? {
        guard let speaker = speaker else { return nil }
        
        // Hide speaker when it's ALIEN
        if speaker == "ALIEN" {
            return nil
        }
        
        switch speaker {
        case "PLAYER1":
            return characterNames[safe: 0] ?? "PLAYER1"
        case "PLAYER2":
            return characterNames[safe: 1] ?? "PLAYER2"
        case "PLAYER3":
            return characterNames[safe: 2] ?? "PLAYER3"
        default:
            return speaker
        }
    }

    private func replacedText(_ text: String) -> String {
        var replaced = text
        for i in 0..<3 {
            replaced = replaced.replacingOccurrences(of: "PLAYER\(i+1)", with: characterNames[safe: i] ?? "PLAYER\(i+1)")
        }
        return replaced
    }
}


struct BrutalistSceneView: View {
    let scene: SceneData
    let displayedText: String
    @State private var textBoxScale: Double = 0.95
    @State private var textBoxOpacity: Double = 0
    @State private var alienGlowIntensity: Double = 0.0
    @State private var alienFlickerTimer: Timer?
    
    private var isBonfireScene: Bool {
        scene.backgroundImage == "artwork1"
    }
    
    private var isAlienSpeaking: Bool {
        scene.speaker == "ALIEN" || scene.isAlienLanguage
    }

    var body: some View {
        ZStack {
            if let bgImage = scene.backgroundImage {
                Image(bgImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()
            } else {
                scene.background.ignoresSafeArea()
            }

            if !scene.isSilent {
                if scene.isFullCenter {
                    fullCenterView()
                } else {
                    dialogueView()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                textBoxScale = 1.0
                textBoxOpacity = 1.0
            }
            
            if isAlienSpeaking {
                startAlienEffects()
            }
        }
        .onDisappear {
            alienFlickerTimer?.invalidate()
        }
    }
    
    private func startAlienEffects() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            alienGlowIntensity = 1.0
        }
        
        alienFlickerTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                textBoxOpacity = Double.random(in: 0.7...1.0)
            }
        }
    }

    private func fullCenterView() -> some View {
        VStack {
            Spacer()
            Text(displayedText)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(scene.isAlienLanguage ? .red : .white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white, lineWidth: 5))
                .padding(.horizontal, 20)
                .scaleEffect(textBoxScale)
                .opacity(textBoxOpacity)
            Spacer()
        }
    }

    private func dialogueView() -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: isBonfireScene ? 8 : 12) {
                if let speaker = scene.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(.system(size: (isBonfireScene || isAlienSpeaking) ? 20 : 25, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.bottom, 4)
                        .shadow(color: isAlienSpeaking ? .red : .clear, radius: alienGlowIntensity * 10)

                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.white)
                        .shadow(color: isAlienSpeaking ? .red : .clear, radius: alienGlowIntensity * 5)
                        .padding(.bottom, 6)
                }

                Text(displayedText)
                    .font(.system(size: (isBonfireScene || isAlienSpeaking) ? 20 : 25, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: isAlienSpeaking ? .red : .clear, radius: alienGlowIntensity * 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding((isBonfireScene || isAlienSpeaking) ? 15 : 20)
            .frame(maxWidth: (isBonfireScene || isAlienSpeaking) ? 600 : .infinity, alignment: .leading)
            .background(
                Color.black.opacity(0.6)
                    .overlay(
                        isAlienSpeaking ?
                        Color.red.opacity(alienGlowIntensity * 0.1) :
                        Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(.white, lineWidth: 3)
                    .shadow(color: isAlienSpeaking ? .red : .clear, radius: alienGlowIntensity * 15)
            )
            .padding(.horizontal, (isBonfireScene || isAlienSpeaking) ? 8 : 20)
            .padding(.bottom, (isBonfireScene || isAlienSpeaking) ? 3 : 30)
            .scaleEffect(textBoxScale * (isAlienSpeaking ? (1.0 + alienGlowIntensity * 0.02) : 1.0))
            .opacity(textBoxOpacity)
        }
    }
}

struct BrutalistRoleView: View {
    let role: PlayerRole
    @State private var displayedTitle = ""
    @State private var displayedRole = ""
    @State private var timer: Timer?
    @State private var titleBoxOffset: CGFloat = -100
    @State private var roleBoxOffset: CGFloat = 100
    @State private var linesOpacity: Double = 0
    
    // ✅ FIXED: Mapping corretto dei ruoli
    private var roleData: (title: String, name: String) {
        switch role {
        case .blind: return ("YOU CANNOT SEE", "LUMO")     // BLIND = LUMO
        case .deaf: return ("YOU CANNOT HEAR", "VIBE")     // DEAF = VIBE
        case .mute: return ("YOU CANNOT SPEAK", "ECHO")    // MUTE = ECHO
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                    .opacity(linesOpacity)

                Text(displayedTitle)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
                    .padding(.horizontal, 30)
                    .offset(x: titleBoxOffset)

                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.white)
                    .padding(.vertical, 20)
                    .opacity(linesOpacity)

                Text("ROLE:")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .kerning(2)
                    .foregroundColor(.white)
                    .padding(.bottom, 12)
                    .opacity(linesOpacity)

                Text(displayedRole)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .overlay(Rectangle().stroke(Color.white, lineWidth: 3))
                    .padding(.horizontal, 40)
                    .offset(x: roleBoxOffset)
            }
            .padding()
        }
        .onAppear {
            startEntranceAnimation()
            startTyping()
        }
    }
    
    private func startEntranceAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            linesOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4)) {
            titleBoxOffset = 0
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6)) {
            roleBoxOffset = 0
        }
    }
    
    private func startTyping() {
        displayedTitle = ""
        displayedRole = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.typeText(text: self.roleData.title) {
                self.typeText(text: self.roleData.name)
            }
        }
    }
    
    private func typeText(text: String, completion: (() -> Void)? = nil) {
        var currentIndex = 0
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                if text == roleData.title {
                    displayedTitle.append(text[index])
                } else {
                    displayedRole.append(text[index])
                }
                currentIndex += 1
            } else {
                timer.invalidate()
                completion?()
            }
        }
    }
}

// MARK: - SceneData Struct
struct SceneData {
    var background: Color = .black
    var backgroundImage: String? = nil
    var speaker: String?
    var text: String
    var isSilent: Bool = false
    var isAlienLanguage: Bool = false
    var isFullCenter: Bool = false
}

extension SceneData {
    func withSpeaker(_ newSpeaker: String?) -> SceneData {
        var copy = self
        copy.speaker = newSpeaker
        return copy
    }
    func withText(_ newText: String) -> SceneData {
        var copy = self
        copy.text = newText
        return copy
    }
}

// MARK: - Collection Extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Previews
struct CutsceneSequenceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CutsceneSequenceView(
                playerRole: .blind,
                playerID: 0,
                characterNames: ["Anna", "Betty", "Erik"]
            )
            .previewDisplayName("LUMO Role")
            
            CutsceneSequenceView(
                playerRole: .deaf,
                playerID: 1,
                characterNames: ["Anna", "Betty", "Erik"]
            )
            .previewDisplayName("VIBE Role")
            
            CutsceneSequenceView(
                playerRole: .mute,
                playerID: 2,
                characterNames: ["Anna", "Betty", "Erik"]
            )
            .previewDisplayName("ECHO Role")
        }
        .previewInterfaceOrientation(.landscapeLeft)
    }
}
