//
//  GameRouterView.swift
//  FinalProject
//
//  Created by Vincenzo Picone on 27/05/25.
//  FIXED: Role names corrected in previews
//

import SwiftUI
import GameKit

struct GameRouterView: View {
    @ObservedObject private var gkManager = GameKitManager.shared

    let playerRole: PlayerRole

    var body: some View {
        Group {
            switch playerRole {
            case .blind:
                BlindCombinedGameView()
            case .deaf:
                DeafCombinedGameView()
            case .mute:
                MuteCombinedGameView()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: playerRole)
    }
}

// ✅ FIXED: Preview names corrected to match proper role mapping
#Preview ("LUMO"){
    GameRouterView(playerRole: .blind)   // BLIND = LUMO
}

#Preview ("VIBE"){
    GameRouterView(playerRole: .deaf)    // DEAF = VIBE
}

#Preview ("ECHO"){
    GameRouterView(playerRole: .mute)    // MUTE = ECHO
}
