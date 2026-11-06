//
//  AppConfig.swift
//  FinalProject
//
//  Created for Trustfall.
//

import Foundation

enum AppConfig {
    /// Loads the Agora App ID securely from Secrets.plist or environment variables.
    static var agoraAppId: String {
        // 1. Try reading from Secrets.plist bundled with the app
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let appId = plist["AgoraAppID"] as? String,
           !appId.isEmpty,
           appId != "YOUR_AGORA_APP_ID_HERE" {
            return appId
        }
        
        // 2. Fallback to environment variable (useful for CI/CD or Xcode Scheme environment variables)
        if let envAppId = ProcessInfo.processInfo.environment["AGORA_APP_ID"],
           !envAppId.isEmpty,
           envAppId != "YOUR_AGORA_APP_ID_HERE" {
            return envAppId
        }
        
        #if DEBUG
        print("⚠️ [AppConfig] No valid Agora App ID found in Secrets.plist or environment.")
        print("💡 Copy Secrets.plist.example to Secrets.plist and add your App ID.")
        #endif
        return ""
    }
    
    /// Indicates whether voice chat has a valid configuration available.
    static var isVoiceChatConfigured: Bool {
        !agoraAppId.isEmpty
    }
}
