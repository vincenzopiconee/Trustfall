//
//  ExitAlertType.swift
//  FinalProject
//
//  Created by Antonio Odore on 07/06/25.
//


//
//  UnifiedExitAlert.swift  
//  FinalProject
//
//  Unified alert using the simpler ExitGameAlert design for both local and remote exits
//

import SwiftUI

enum ExitAlertType {
    case localExit          // Player wants to exit (shows confirmation)
    case remotePlayerExit(String)  // Another player has left (shows notification)
}

struct UnifiedExitAlert: View {
    let alertType: ExitAlertType
    @Binding var isPresented: Bool
    let onConfirmExit: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    // Computed properties based on alert type
    private var titleText: String {
        switch alertType {
        case .localExit:
            return NSLocalizedString("Exit Game", comment: "")
        case .remotePlayerExit(_):
            return NSLocalizedString("Player Left Game", comment: "")
        }
    }
    
    private var messageText: String {
        switch alertType {
        case .localExit:
            return NSLocalizedString("Are you sure you want to exit the game?\nThis will end the game for all players.", comment: "")
        case .remotePlayerExit(let playerName):
            return NSLocalizedString("\"\(playerName)\" has left the game.\nReturning to main menu...", comment: "")
        }
    }
    
    private var hasButtons: Bool {
        switch alertType {
        case .localExit:
            return true
        case .remotePlayerExit(_):
            return false
        }
    }
    
    private var shouldAutoDismiss: Bool {
        switch alertType {
        case .localExit:
            return false
        case .remotePlayerExit(_):
            return true
        }
    }

    var body: some View {
        if isPresented {
            ZStack {
                // Semi-transparent background overlay
                Color.black.opacity(0.5).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text(titleText)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 12)

                    Text(messageText)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Buttons (only for local exit)
                    if hasButtons {
                        VStack(spacing: 15) {
                            Button(action: {
                                isPresented = false
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                            }

                            Button(action: {
                                isPresented = false
                                onConfirmExit?()
                            }) {
                                Text("Exit")
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 16)
                    } else {
                        // For remote exit, just show some spacing
                        Spacer()
                            .frame(height: 16)
                    }
                }
                .background(Color.black)
                .cornerRadius(8)
                .frame(maxWidth: 400) // Slightly wider for better text display
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 5)
                )
                .shadow(radius: 10)
            }
            .transition(.opacity)
            .animation(.easeInOut, value: isPresented)
            .onAppear {
                // Auto-dismiss for remote exit
                if shouldAutoDismiss {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        onDismiss?()
                    }
                }
            }
        }
    }
    
    // Convenience init for local exit
    init(isPresented: Binding<Bool>, onConfirmExit: @escaping () -> Void) {
        self.alertType = .localExit
        self._isPresented = isPresented
        self.onConfirmExit = onConfirmExit
        self.onDismiss = nil
    }
    
    // Convenience init for remote player exit
    init(playerName: String, isPresented: Binding<Bool>, onDismiss: @escaping () -> Void) {
        self.alertType = .remotePlayerExit(playerName)
        self._isPresented = isPresented
        self.onConfirmExit = nil
        self.onDismiss = onDismiss
    }
    
    // Full init
    init(alertType: ExitAlertType, isPresented: Binding<Bool>, onConfirmExit: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self.alertType = alertType
        self._isPresented = isPresented
        self.onConfirmExit = onConfirmExit
        self.onDismiss = onDismiss
    }
}

// MARK: - Helper Extension
extension ExitAlertType {
    var isRemoteExit: Bool {
        switch self {
        case .localExit:
            return false
        case .remotePlayerExit(_):
            return true
        }
    }
}

// MARK: - Preview
struct UnifiedExitAlert_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var showLocal = true
        @State var showRemote = false

        var body: some View {
            ZStack {
                Color.gray.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Button("Show Local Exit") {
                        showLocal = true
                    }
                    
                    Button("Show Remote Exit") {
                        showRemote = true
                    }
                }
                
                // Local exit alert
                UnifiedExitAlert(isPresented: $showLocal) {
                    print("Exit confirmed")
                }
                
                // Remote exit alert
                UnifiedExitAlert(playerName: "TestPlayer123", isPresented: $showRemote) {
                    print("Remote exit dismissed")
                }
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
