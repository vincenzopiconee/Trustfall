//
//  GameResultOverlay.swift
//  FinalProject
//
//  FIXED: Complete restart system with battery sequence regeneration
//

import SwiftUI

// MARK: - Game Result Overlay View
struct GameResultOverlay: View {
    let isWon: Bool
    let errorCount: Int
    let onRestart: () -> Void
    let onExit: () -> Void
    
    @ObservedObject private var sharedGameState = SharedGameStateManager.shared
    @ObservedObject private var gkManager = GameKitManager.shared
    
    // States for restart system
    @State private var hasRequestedRestart = false
    @State private var showRestartReadyUI = false
    @State private var animateTitle = false
    @State private var animateDetails = false
    
    // Computed properties
    private var titleText: String {
        if isWon {
            return "VICTORY"
        } else if sharedGameState.isGameTimeExpired {
            return "TIME'S UP"
        } else {
            return "GAME OVER"
        }
    }
    
    private var subtitleText: String {
        if isWon {
            return "MISSION ACCOMPLISHED"
        } else {
            return sharedGameState.gameOverReason
        }
    }
    
    private var titleColor: Color {
        return isWon ? .green : .red
    }
    
    private var detailText: String {
        if isWon {
            return "ALL BATTERIES CONNECTED IN SEQUENCE"
        } else if sharedGameState.isGameTimeExpired {
            return "TIMER REACHED 00:00"
        } else {
            return "ERRORS: \(errorCount)/3"
        }
    }
    
    private var completionTimeText: String? {
        if isWon {
            let timeUsed = 600 - sharedGameState.timeRemaining
            let minutes = timeUsed / 60
            let seconds = timeUsed % 60
            return "COMPLETION TIME: \(minutes):\(String(format: "%02d", seconds))"
        } else if !sharedGameState.isGameTimeExpired {
            return "FINAL TIME: \(sharedGameState.timeString)"
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Full screen overlay
            Rectangle()
                .fill(Color.black.opacity(0.95))
                .ignoresSafeArea()
                .overlay(
                    VStack(spacing: 0) {
                        ForEach(0..<20, id: \.self) { _ in
                            Rectangle()
                                .fill(titleColor.opacity(0.02))
                                .frame(height: 2)
                                .offset(x: animateTitle ? 50 : -50)
                                .animation(
                                    .linear(duration: 4)
                                    .repeatForever(autoreverses: true),
                                    value: animateTitle
                                )
                        }
                    }
                    .blur(radius: 1)
                )
            
            VStack(spacing: 30) {
                // Animated title
                VStack(spacing: 15) {
                    Text(titleText)
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(titleColor)
                        .tracking(6)
                        .shadow(color: titleColor.opacity(0.8), radius: animateTitle ? 20 : 10)
                        .scaleEffect(animateTitle ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true),
                            value: animateTitle
                        )
                    
                    Rectangle()
                        .fill(titleColor)
                        .frame(width: animateTitle ? 250 : 200, height: 4)
                        .shadow(color: titleColor.opacity(0.5), radius: 5)
                        .animation(.easeInOut(duration: 1.5), value: animateTitle)
                }
                
                // Subtitle
                Text(subtitleText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(3)
                    .opacity(animateDetails ? 1.0 : 0.0)
                    .offset(y: animateDetails ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.5), value: animateDetails)
                
                // Detail info
                VStack(spacing: 8) {
                    Text(detailText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(2)
                        .opacity(animateDetails ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(0.7), value: animateDetails)
                    
                    if let timeText = completionTimeText {
                        Text(timeText)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1)
                            .opacity(animateDetails ? 1.0 : 0.0)
                            .animation(.easeOut(duration: 0.8).delay(0.9), value: animateDetails)
                    }
                    
                    Text("DIFFICULTY: \(sharedGameState.difficultyString)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1)
                        .opacity(animateDetails ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.8).delay(1.1), value: animateDetails)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Conditional UI for restart ready system
                if showRestartReadyUI {
                    restartReadySection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                        .padding(.top, -20)
                } else {
                    actionButtonsSection
                        .opacity(animateDetails ? 1.0 : 0.0)
                        .offset(y: animateDetails ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(1.3), value: animateDetails)
                        .padding(.top, -20)
                }
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            withAnimation {
                animateTitle = true
                animateDetails = true
            }
        }
        // ✅ CRITICAL FIX: Complete restart when all players ready
        .onChange(of: gkManager.allPlayersReadyForRestart) { _, isReady in
            if isReady {
                print("🔄 All players ready for restart - initiating COMPLETE game reset...")
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    showRestartReadyUI = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // 1. Reset GameKit states
                    gkManager.resetForRestart()
                    
                    // 2. ✅ CRITICAL: Ensure sequence generation FIRST
                    sharedGameState.ensureSequenceForRestart()
                    
                    // 3. Reset SharedGameState completely
                    sharedGameState.resetGame()
                    
                    // 4. Reset statistics
                    GameStatisticsManager.shared.resetCurrentGameErrors()
                    
                    // 5. Call the restart callback
                    onRestart()
                }
            }
        }
        .onDisappear {
            hasRequestedRestart = false
            showRestartReadyUI = false
        }
    }
    
    // Restart ready section
    private var restartReadySection: some View {
        VStack(spacing: 25) {
            VStack(spacing: 15) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animateTitle ? 1.5 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animateTitle
                            )
                    }
                }
                
                Text("WAITING FOR ALL PLAYERS")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.orange)
                    .tracking(2)
                
                Text("(\(gkManager.playersReadyForRestart.count)/\(gkManager.players.count)) READY FOR RESTART")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasRequestedRestart = false
                    showRestartReadyUI = false
                }
                gkManager.cancelRestartRequest()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16, weight: .bold))
                    Text("CANCEL RESTART")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    Rectangle()
                        .fill(Color.gray)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                )
                .foregroundColor(.black)
                .shadow(color: .gray.opacity(0.3), radius: 5)
            }
            .scaleEffect(0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showRestartReadyUI)
        }
    }
    
    // Action buttons section
    private var actionButtonsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // ✅ FIXED: Restart button with sequence generation
                Button(action: {
                    if !hasRequestedRestart {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasRequestedRestart = true
                            showRestartReadyUI = true
                        }
                        gkManager.requestRestart()
                    }
                }) {
                    HStack(spacing: 8) {
                        if hasRequestedRestart {
                            Image(systemName: "clock")
                                .font(.system(size: 16, weight: .bold))
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        Text(hasRequestedRestart ? "WAITING..." : "PLAY AGAIN")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        Rectangle()
                            .fill(hasRequestedRestart ? Color.orange : titleColor)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    )
                    .foregroundColor(.black)
                    .shadow(color: (hasRequestedRestart ? Color.orange : titleColor).opacity(0.5), radius: 5)
                }
                .disabled(hasRequestedRestart)
                .scaleEffect(hasRequestedRestart ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasRequestedRestart)
                
                // Exit button
                Button(action: {
                    GameKitManager.shared.exitGameAndNotifyOthers()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                        Text("EXIT GAME")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        Rectangle()
                            .fill(Color.gray)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    )
                    .foregroundColor(.black)
                    .shadow(color: .gray.opacity(0.3), radius: 5)
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasRequestedRestart)
            }
            
            if gkManager.players.count == 1 {
                Text("Playing solo? Restart is instant!")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
            }
        }
    }
}

// MARK: - Preview
#Preview("Victory") {
    GameResultOverlay(
        isWon: true,
        errorCount: 1,
        onRestart: { print("Restart tapped") },
        onExit: { print("Exit tapped") }
    )
}

#Preview("Game Over") {
    GameResultOverlay(
        isWon: false,
        errorCount: 3,
        onRestart: { print("Restart tapped") },
        onExit: { print("Exit tapped") }
    )
}
