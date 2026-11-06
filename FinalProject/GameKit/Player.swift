//
//  Player.swift
//  FinalProject
//
//  Created by Antonio Odore on 19/05/25.
//

import SwiftUI

// L'ENUM PlayerRole ORA È DEFINITO SOLO QUI!
enum PlayerRole: String, Codable, CaseIterable {
    case blind = "BLIND"
    case deaf = "DEAF"
    case mute = "MUTE"
}

struct Player: Identifiable, Codable {
    let id: UUID
    let name: String
    let gameCenterName: String
    let isCurrentUser: Bool
    let icon: String
    let characterName: String?
    let role: PlayerRole?
    
    init(id: UUID = UUID(), name: String, gameCenterName: String, isCurrentUser: Bool, icon: String, characterName: String? = nil, role: PlayerRole? = nil) {
        self.id = id
        self.name = name
        self.gameCenterName = gameCenterName
        self.isCurrentUser = isCurrentUser
        self.icon = icon
        self.characterName = characterName
        self.role = role
    }
}


