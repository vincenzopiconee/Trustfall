//
//  MainMenuView.swift
//  FinalProject
//
//  Created by Vincenzo Picone on 20/05/25.
//  Updated with Settings integration, fixed background and falling title animation
//  FIXED: Safe background music integration to prevent crashes + REMOVED music toggle
//

import SwiftUI
import GameKit
import AVFoundation

struct MainMenuView: View {
    @StateObject private var gkManager = GameKitManager.shared
    
    // ✅ SAFE: Optional music manager per evitare crash di inizializzazione
    @StateObject private var musicManager = BackgroundMusicManager.shared
    
    // ✅ NUOVO: State per mostrare Settings e How to Play
    @State private var showSettings = false
    @State private var showHowToPlay = false
    
    // ✅ SAFE: State per controllare se la musica è stata inizializzata
    @State private var musicInitialized = false

    var body: some View {
        ZStack {
            // Animated background effect
            AnimatedBackground()
            
            VStack(spacing: 40) {
                // ✅ NUOVO: Animated falling title
                AnimatedFallingTitle()
                    .padding(.top, 50)
                
                Spacer()
                
                VStack(spacing: 20) {
                    if gkManager.isAuthenticated {
                        
                        Button(action: {
                            gkManager.startHosting()
                        }) {
                            Text("START GAME")
                                .padding(.vertical, 10)
                                .padding(.horizontal, 30)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .background(Color.white)
                        }
                        
                        // ✅ UPDATED: Solo Settings e How to Play (rimosso music toggle)
                        HStack(spacing: 15) {
                            // Settings button
                            Button(action: {
                                showSettings = true
                            }) {
                                Text("SETTINGS")
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 30)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .background(Color.clear)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                            
                            // How to Play button
                            Button(action: {
                                showHowToPlay = true
                            }) {
                                Text("HOW TO PLAY")
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 30)
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .background(Color.clear)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                        }
                    } else {
                        Text("CONNECTING TO GAME CENTER...")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // ✅ SAFE: Inizializzazione musica con controllo errori
            initializeBackgroundMusic()
            
            // ✅ SAFE: Audio permission con controllo errori
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    DispatchQueue.main.async {
                        setupAudioSession()
                    }
                }
            }
        }
        .onDisappear {
            // ✅ SAFE: Handle music quando si esce dal menu
            handleMusicOnDisappear()
        }
        // ✅ NUOVO: Settings presentation
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        // ✅ NUOVO: How to Play presentation
        .sheet(isPresented: $showHowToPlay) {
            ManualView()
        }
        .fullScreenCover(isPresented: $gkManager.inLobby) {
            if gkManager.gameStarted {
                // Fixed: Check if role exists before creating cutscene
                let characterNames = gkManager.players.map { player in
                    gkManager.selectedCharacters[player.gamePlayerID] ?? "PLAYER"
                }
                
                if let role = gkManager.currentPlayerRole {
                    CutsceneSequenceView(
                        playerRole: role,
                        playerID: getPlayerIndex(),
                        characterNames: characterNames
                    )
                    .onAppear {
                        // ✅ SAFE: Lower music volume durante il gioco
                        handleGameStart()
                    }
                } else {
                    // Fallback view if role is not assigned yet
                    VStack {
                        Text("WAITING FOR ROLE ASSIGNMENT...")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Button("EXIT") {
                            exitGame()
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 120, height: 40)
                        .background(Color.white)
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                }
            } else {
                LobbyView()
                    .onDisappear {
                        // ✅ SAFE: Restore music quando si torna dalla lobby
                        handleReturnFromLobby()
                    }
            }
        }
        .alert(isPresented: Binding(
            get: { gkManager.errorMessage != nil },
            set: { _ in gkManager.errorMessage = nil }
        )) {
            Alert(
                title: Text("ERROR"),
                message: Text(gkManager.errorMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - ✅ SAFE: Helper Functions per evitare crash
    
    private func initializeBackgroundMusic() {
        guard !musicInitialized else { return }
        
        // ✅ SAFE: Inizializzazione con delay per evitare race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                musicManager.playBackgroundMusic(filename: "menu_background_music", fileType: "wav")
                musicInitialized = true
                print("✅ Background music initialized successfully")
            } catch {
                print("⚠️ Failed to initialize background music: \(error)")
                // Fallback: continua senza musica
            }
        }
    }
    
    private func handleMusicOnDisappear() {
        guard musicInitialized else { return }
        
        if gkManager.inLobby {
            do {
                // ✅ NEW: Stop music when entering lobby
                musicManager.stopBackgroundMusic()
                print("🔇 Background music stopped for lobby")
            } catch {
                print("⚠️ Error stopping music for lobby: \(error)")
            }
        }
    }
    
    private func handleGameStart() {
        guard musicInitialized else { return }
        
        do {
            musicManager.handleGameStart()
        } catch {
            print("⚠️ Error handling music during game start: \(error)")
        }
    }
    
    private func handleReturnFromLobby() {
        guard musicInitialized else { return }
        
        if !gkManager.inLobby {
            do {
                // ✅ NEW: Restart background music when returning from lobby
                musicManager.playBackgroundMusic(filename: "menu_background_music", fileType: "wav")
                print("🎵 Background music restarted after lobby")
            } catch {
                print("⚠️ Error restarting music: \(error)")
            }
        }
    }
    
    private func exitGame() {
        // ✅ SAFE: Exit con cleanup musicale
        do {
            gkManager.exitGame()
            AgoraVoiceManager.shared.leaveChannel()
            AgoraVoiceManager.shared.destroyInstance()
            
            // Restore music quando si esce
            if musicInitialized {
                musicManager.playBackgroundMusic(filename: "menu_background_music", fileType: "wav")
            }
        } catch {
            print("⚠️ Error during exit: \(error)")
        }
    }
    
    private func getPlayerIndex() -> Int {
        return gkManager.players.firstIndex { player in
            player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
        } ?? 0
    }
    
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // ✅ SAFE: Usa .ambient per compatibility
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("🎙️ AVAudioSession configurata!")
        } catch {
            print("❌ Errore AVAudioSession: \(error)")
            // Continue without audio session - non blocking
        }
    }
}

// ✅ UNCHANGED: Keep existing views as they are
struct AnimatedFallingTitle: View {
    @State private var letterAnimations: [Bool] = Array(repeating: false, count: 9)
    @State private var glowEffect = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array("TRUSTFALL".enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(glowEffect ? 0.8 : 0.3), radius: glowEffect ? 15 : 10, x: 0, y: 0)
                    .offset(y: letterAnimations[index] ? 0 : -200)
                    .opacity(letterAnimations[index] ? 1 : 0)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)
                        .delay(Double(index) * 0.1),
                        value: letterAnimations[index]
                    )
            }
        }
        .onAppear {
            // Reset animations
            letterAnimations = Array(repeating: false, count: 9)
            glowEffect = false
            
            // Anima le lettere una per una
            for i in 0..<letterAnimations.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                    letterAnimations[i] = true
                }
            }
            
            // Effetto glow dopo che tutte le lettere sono cadute
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowEffect = true
                }
            }
        }
    }
}

// ✅ FIXED: Background senza effetto zoom
struct AnimatedBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base black background
            Color.black.ignoresSafeArea(.all)
            
            // Animated particles/stars effect
            ForEach(0..<50, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                    .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .scaleEffect(animate ? CGFloat.random(in: 0.5...1.5) : 1.0)
                    .opacity(animate ? Double.random(in: 0.1...0.8) : 0.3)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                        value: animate
                    )
            }
            
            // Subtle gradient overlay (FIXED: removed scaling animation)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.05),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea(.all)
            // ✅ Removed the problematic scaleEffect animation that caused zoom in/out
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    MainMenuView()
}
