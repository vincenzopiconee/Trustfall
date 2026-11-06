//
//  DeafCombinedGameView.swift
//  FinalProject
//
//  FIXED: Proper restart behavior - DEAF waits for MUTE to handle restart + ERROR SOUNDS
//

import SwiftUI
import AVFoundation

struct DeafCombinedGameView: View {
    @State private var currentPage: Int = 0
    @State private var showExitAlert = false
    @ObservedObject private var gkManager = GameKitManager.shared
    @ObservedObject private var sharedGameState = SharedGameStateManager.shared
    
    // Stati per feedback visivo
    @State private var batteryFeedbackText: String = ""
    @State private var showBatteryFeedback: Bool = false
    @State private var feedbackColor: Color = .green
        
    let playerRole: PlayerRole = .deaf
    
    private let sectionTitles = [NSLocalizedString("INTRODUCTION", comment: ""), NSLocalizedString("SCORING", comment: ""), NSLocalizedString("OBJECTIVE", comment: ""), NSLocalizedString("PAIRINGS", comment: "")]
    
    @State private var showInfoAlert = true
    
    // ✅ FIXED: Mapping corretto dei ruoli
    private var roleData: String {
        return "VIBE"  // DEAF = VIBE (non più "LUMO")
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                HStack(spacing: 60) {
                    // Left Side - WalkieTalkie
                    ZStack {
                        if let channelId = gkManager.lobbyVoiceChannelId {
                            DeafWalkieTalkieView(geometry: geometry, channelId: channelId)
                        } else {
                            // Placeholder mentre aspettiamo il voice channel
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
                    
                    // Right Side - Manual Content
                    if !sharedGameState.shouldShowGameResult {
                        HStack(spacing: -40) {
                            // Content Area
                            TabView(selection: $currentPage) {
                                BrutalistModule(
                                    icon: NSLocalizedString("⟆", comment: "Simbolo a forma di ⟆"),
                                    title: NSLocalizedString("INTRODUCTION", comment: "Titolo: INTRODUCTION"),
                                    subtitle: NSLocalizedString("ZORBONIAN OPERATIONAL MANUAL", comment: "Sottotitolo: ZORBONIAN OPERATIONAL MANUAL"),
                                    description: NSLocalizedString(
                                        "GREETINGS, BIPEDAL CREATURE!\nCongratulations on finding this precious document! Your tiny grasping appendages should be sufficient to complete this operation... maybe.\n\nWARNING: If you're reading this, it means our security system has failed miserably. We also hope you have friends, because you'll need them.",
                                        comment: "Descrizione introduttiva del modulo Brutalist"
                                    ),
                                    rules: [
                                        NSLocalizedString(
                                            "CLASSIFICATION: ⟆⟟⋉⧫⟟⋏⏃⍀⋔ ⟒⧫⍜⋏⁅⋔⟟⋏⟒⍀",
                                            comment: "Regola: CLASSIFICATION con simboli Zorboniani"
                                        ),
                                        NSLocalizedString(
                                            "Guide for Primitive Terrestrial Life Forms",
                                            comment: "Regola: Guida per forme di vita primitive"
                                        )
                                    ]
                                )                                .tag(0)

                                BrutalistModule(
                                    icon: NSLocalizedString("◼", comment: "Simbolo a forma di ◼"),
                                    title: NSLocalizedString("SCORING", comment: "Titolo: SCORING"),
                                    subtitle: NSLocalizedString("PERFORMANCE METRICS", comment: "Sottotitolo: PERFORMANCE METRICS"),
                                    description: NSLocalizedString(
                                        "TIME LIMIT: 10 Earth minutes\nERROR TOLERANCE: Maximum 2 mistakes allowed",
                                        comment: "Descrizione: TIME LIMIT e ERROR TOLERANCE"
                                    ),
                                    rules: [
                                        NSLocalizedString("SUCCESS CONDITIONS:", comment: "Regola: SUCCESS CONDITIONS"),
                                        NSLocalizedString("• All fuses placed in correct sequence", comment: "Regola: All fuses placed in correct sequence"),
                                        NSLocalizedString("• Proper symbol matches", comment: "Regola: Proper symbol matches"),
                                        NSLocalizedString("• Device activation (probably)", comment: "Regola: Device activation (probably)"),
                                        NSLocalizedString("• Prove Earth creatures aren't hopeless", comment: "Regola: Prove Earth creatures aren't hopeless"),
                                        NSLocalizedString("", comment: "Riga vuota di separazione"),
                                        NSLocalizedString("FEEDBACK SYSTEM:", comment: "Regola: FEEDBACK SYSTEM"),
                                        NSLocalizedString("• When ECHO places battery correctly:", comment: "Regola: When ECHO places battery correctly:"),
                                        NSLocalizedString("  - VIBE receives visual notification", comment: "Regola indentata: VIBE receives visual notification"),
                                        NSLocalizedString("  - LUMO receives audio confirmation sound", comment: "Regola indentata: LUMO receives audio confirmation sound"),
                                        NSLocalizedString("  - Progress tracking for all team members", comment: "Regola indentata: Progress tracking for all team members"),
                                        NSLocalizedString("", comment: "Riga vuota di separazione"),
                                        NSLocalizedString("FAILURE CONDITIONS:", comment: "Regola: FAILURE CONDITIONS"),
                                        NSLocalizedString("• Wrong sequence or pairings", comment: "Regola: Wrong sequence or pairings"),
                                        NSLocalizedString("• Timeout", comment: "Regola: Timeout"),
                                        NSLocalizedString("• Cosmic disappointment", comment: "Regola: Cosmic disappointment"),
                                        NSLocalizedString("• Alien disdain", comment: "Regola: Alien disdain")
                                    ]
                                )

                                .tag(1)

                                BrutalistModule(
                                    icon: NSLocalizedString("◍", comment: "Simbolo a forma di ◍"),
                                    title: NSLocalizedString("OBJECTIVE", comment: "Titolo: OBJECTIVE"),
                                    subtitle: NSLocalizedString("MISSION PARAMETERS", comment: "Sottotitolo: MISSION PARAMETERS"),
                                    description: NSLocalizedString(
                                        "Open the door of the room you are trapped in by inserting four fuses into the corresponding slots following a precise order.",
                                        comment: "Descrizione: obiettivo della missione"
                                    ),
                                    rules: [
                                        NSLocalizedString("ECHO DIRECTIVES:", comment: "Regola: ECHO DIRECTIVES"),
                                        NSLocalizedString("• Access fuse configuration", comment: "Regola: Access fuse configuration"),
                                        NSLocalizedString("• Find combinations on last page", comment: "Regola: Find combinations on last page"),
                                        NSLocalizedString("• Each contains:", comment: "Regola: Each contains:"),
                                        NSLocalizedString("  - Alien symbol", comment: "Regola indentata: Alien symbol"),
                                        NSLocalizedString("  - Color", comment: "Regola indentata: Color"),
                                        NSLocalizedString("  - Morse code letter", comment: "Regola indentata: Morse code letter"),
                                        NSLocalizedString("", comment: "Riga vuota di separazione"),
                                        NSLocalizedString("VIBE ROLE:", comment: "Regola: VIBE ROLE"),
                                        NSLocalizedString("• Decodes correct order from sound", comment: "Regola: Decodes correct order from sound"),
                                        NSLocalizedString("• Matches Morse codes with descriptions", comment: "Regola: Matches Morse codes with descriptions"),
                                        NSLocalizedString("", comment: "Riga vuota di separazione"),
                                        NSLocalizedString("LUMO ROLE:", comment: "Regola: LUMO ROLE"),
                                        NSLocalizedString("• Physically inserts fuses", comment: "Regola: Physically inserts fuses"),
                                        NSLocalizedString("• Drags colored fuse to symbol", comment: "Regola: Drags colored fuse to symbol"),
                                        NSLocalizedString("• Releases to attempt pairing", comment: "Regola: Releases to attempt pairing")
                                    ]
                                )
                                .tag(2)

                                BrutalistModule(
                                    icon: NSLocalizedString("▣", comment: "Simbolo a forma di ▣"),
                                    title: NSLocalizedString("PAIRINGS", comment: "Titolo: PAIRINGS"),
                                    subtitle: NSLocalizedString("FUSE MATRIX", comment: "Sottotitolo: FUSE MATRIX"),
                                    imageNames: ["pairing_1", "pairing_2", "pairing_3", "pairing_4"]
                                )
                                .tag(3)
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(width: geometry.size.width * 0.46)
                            .padding(.leading, -40)
                            
                            // Navigation Section
                            VStack(alignment: .trailing) {
                                VStack(alignment: .leading) {
                                    Text("ZORBONIAN")
                                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text("OPERATIONAL MANUAL")
                                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 10)

                                VStack(spacing: 16) {
                                    Text("SECTIONS")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .tracking(1)
                                        .padding(.trailing, 20)
                                        .padding(.top, 0.2)

                                    VStack(spacing: 20) {
                                        ForEach(0..<sectionTitles.count, id: \.self) { index in
                                            HStack(spacing: 5) {
                                                
                                                ZStack {
                                                    Rectangle()
                                                        .fill(Color.white.opacity(0.2))
                                                        .frame(width: 25, height: 8)

                                                    Rectangle()
                                                        .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                                                        .frame(width: currentPage == index ? 25 : 12, height: 3)
                                                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                                                }

                                                Text(sectionTitles[index])
                                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                    .foregroundColor(currentPage == index ? .white : .white.opacity(0.6))
                                                    .tracking(0.5)

                                                Spacer()
                                            }
                                            .padding(.vertical, 3)
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    currentPage = index
                                                }
                                            }
                                        }
                                    }
                                    .padding(.leading, 70)
                                }

                                Spacer()

                                VStack(alignment: .leading, spacing: 12) {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(height: 1)
                                        .frame(maxWidth: 100)

                                    Text("SWIPE OR TAP TO NAVIGATE")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                        .tracking(0.5)
                                }
                                .padding(.bottom, 20)
                            }
                        }
                        .frame(width: geometry.size.width * 0.65)
                    }
                }

                // Battery placement visual feedback overlay
                if showBatteryFeedback {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(feedbackColor)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(showBatteryFeedback ? 1.0 : 0.5)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showBatteryFeedback)
                            
                            Text(batteryFeedbackText)
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                        .background(
                            Rectangle()
                                .fill(Color.black.opacity(0.9))
                                .overlay(Rectangle().stroke(feedbackColor, lineWidth: 3))
                        )
                        .padding(.horizontal, 40)
                        .padding(.bottom, 80)
                        
                        Spacer()
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .zIndex(999)
                }

                // Game Result Overlay globale
                if sharedGameState.shouldShowGameResult {
                    GameResultOverlay(
                        isWon: sharedGameState.isGameWon,
                        errorCount: sharedGameState.totalErrors,
                        onRestart: {
                            // ✅ CRITICAL FIX: DEAF waits for MUTE to handle complete restart
                            print("🎮 VIBE: Waiting for complete restart by ECHO...")
                            // VIBE doesn't do anything local, waits for the complete system reset
                        },
                        onExit: {
                            // ✅ UPDATED: Use new exit system
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

                // ✅ UNIFIED: Use UnifiedExitAlert for both local and remote exits
                UnifiedExitAlert(isPresented: $showExitAlert) {
                    GameKitManager.shared.exitGameAndNotifyOthers()
                }
                
                if showInfoAlert {
                    BrutalistAlert(alertType: .deaf) {
                        showInfoAlert = false
                    }
                }
                
                // ✅ UNIFIED: Remote player exit alert
                UnifiedExitAlert(
                    playerName: gkManager.exitedPlayerName,
                    isPresented: $gkManager.showPlayerExitAlert
                ) {
                    gkManager.returnToMainMenu()
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
            
            print("🎮 VIBE appeared - using lobby voice channel: \(gkManager.lobbyVoiceChannelId ?? "nil")")
            
            setupBatteryPlacedObserver()
            
            // ✅ NUOVO: Setup error sound observer
            setupErrorSoundObserver()
            
            // Debug voice channel
            #if DEBUG
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                gkManager.debugVoiceChannelSync()
            }
            #endif
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .batteryPlacedCorrectly, object: nil)
            // ✅ NUOVO: Rimuovi observer per error sounds
            NotificationCenter.default.removeObserver(self, name: .errorSoundTriggered, object: nil)
        }
        // ✅ NEW: React to game reset for UI reset
        .onChange(of: sharedGameState.gameStateVersion) { oldVersion, newVersion in
            print("🔄 VIBE detected game state reset (v\(oldVersion) → v\(newVersion))")
            
            // Reset local UI state
            currentPage = 0
            showBatteryFeedback = false
            batteryFeedbackText = ""
            
            print("✅ VIBE: UI state reset completed")
        }
    }
    
    // ✅ NUOVO: Setup observer per suoni di errore
    private func setupErrorSoundObserver() {
        NotificationCenter.default.addObserver(
            forName: .errorSoundTriggered,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let errorCount = userInfo["errorCount"] as? Int,
               let errorType = userInfo["errorType"] as? String {
                
                print("🔊 VIBE received error sound: Error \(errorCount) (\(errorType))")
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
                
                print("📖 VIBE received battery placed: Slot \(slotNumber), \(colorName), Progress: \(currentProgress)/\(totalSteps)")
                
                self.showBatteryPlacedVisualFeedback(
                    slotNumber: slotNumber,
                    colorName: colorName,
                    progress: currentProgress,
                    total: totalSteps
                )
            }
        }
    }
    
    private func showBatteryPlacedVisualFeedback(slotNumber: Int, colorName: String, progress: Int, total: Int) {
        feedbackColor = colorFromName(colorName)
        
        batteryFeedbackText = """
        ✅ BATTERY PLACED SUCCESSFULLY!
        
        \(colorName) → SLOT \(slotNumber)
        PROGRESS: \(progress)/\(total) COMPLETED
        """
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showBatteryFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showBatteryFeedback = false
            }
        }
    }
    
    private func colorFromName(_ colorName: String) -> Color {
        switch colorName.uppercased() {
        case "YELLOW": return .yellow
        case "GREEN": return .green
        case "RED": return .red
        case "BLUE": return .blue
        default: return .white
        }
    }
}

// MARK: - BrutalistModule
struct BrutalistModule: View {
    let icon: String
    let title: String
    let subtitle: String
    var description: String? = nil
    var rules: [String]? = nil
    var imageNames: [String]? = nil

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(icon)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(Color.white)
                            .foregroundColor(.black)

                        VStack(alignment: .leading) {
                            Text(title)
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            Text(subtitle)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.white)
                }

                if let description = description {
                    Text(description)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let rules = rules {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rules, id: \.self) { rule in
                            HStack(alignment: .top) {
                                Text("")
                                Text(rule)
                                    .font(.system(size: rule.hasPrefix("•") ? 12 : 14,
                                          weight: rule.hasPrefix("•") ? .regular : .bold,
                                          design: .monospaced))
                                    .foregroundColor(rule.hasPrefix("•") ? .white : .white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let imageNames = imageNames {
                    VStack(spacing: 16) {
                        ForEach(imageNames, id: \.self) { name in
                            HStack {
                                Spacer()
                                Image(name)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 160)
                                Spacer()
                            }
                        }
                    }
                }

                Spacer()

                HStack {
                    Spacer()
                    Text("CLASSIFIED DOCUMENT v3.2.1")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: 3)
                    .padding(1)
            )
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    DeafCombinedGameView()
        .environment(\.locale, .init(identifier: "it"))
}
