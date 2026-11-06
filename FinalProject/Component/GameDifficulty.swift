//
//  GameDifficulty.swift
//  FinalProject
//
//  Game difficulty levels with time limits and descriptions
//

import SwiftUI

enum GameDifficulty: String, CaseIterable, Codable {
    case easy = "EASY"
    case normal = "NORMAL"
    case hard = "HARD"
    
    var localized: String {
        switch self {
        case .easy: return NSLocalizedString("EASY", comment: "")    // 15 minutes
        case .normal: return NSLocalizedString("NORMAL", comment: "")  // 10 minutes
        case .hard: return NSLocalizedString("HARD", comment: "")    // 7 minutes
        }
        
    }
    
    var timeInSeconds: Int {
        switch self {
        case .easy: return 900    // 15 minutes
        case .normal: return 600  // 10 minutes
        case .hard: return 420    // 7 minutes
        }
    }
    
    var timeString: String {
        let minutes = timeInSeconds / 60
        return "\(minutes) MIN"
    }
    
    var description: String {
        switch self {
        case .easy:
            return NSLocalizedString("Plenty of time to coordinate and plan", comment: "")
        case .normal:
            return NSLocalizedString("Standard challenge for experienced teams", comment: "")
        case .hard:
            return NSLocalizedString("Time pressure increases the challenge", comment: "")
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .white
        case .normal: return .white
        case .hard: return .white
        }
    }
}
