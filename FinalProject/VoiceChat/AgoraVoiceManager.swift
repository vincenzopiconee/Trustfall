//
//  AgoraVoiceManager.swift
//  FinalProject
//
//  COMPLETELY FIXED: Better volume control and state management
//

import SwiftUI
import AgoraRtcKit
import GameKit
import AVFoundation

// Singleton per la gestione della voce Agora
class AgoraVoiceManager: NSObject, ObservableObject, AgoraRtcEngineDelegate {
    static let shared = AgoraVoiceManager()
    
    private var agoraKit: AgoraRtcEngineKit?
    @Published var isJoined = false
    @Published var isMuted = false
    @Published var connectionState: AgoraConnectionState = .disconnected
    @Published var remoteUsers: Set<UInt> = []
    @Published var currentPlaybackVolume: Int = 200
    @Published var currentRecordingVolume: Int = 200
    
    private var appId: String {
        AppConfig.agoraAppId
    }
    private var currentChannelId: String?
    private var currentUID: UInt = 0
    private var isEngineInitialized = false
    private var audioSessionConfigured = false
    
    private override init() {
        super.init()
        requestMicrophonePermission()
    }
    
    // MARK: - Audio Permissions
    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Microphone permission granted")
                    } else {
                        print("❌ Microphone permission denied")
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Microphone permission granted")
                    } else {
                        print("❌ Microphone permission denied")
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ IMPROVED: Engine Initialization
    func initializeAgoraEngine() {
        guard !isEngineInitialized else {
            print("🎤 Agora engine already initialized")
            return
        }
        
        guard AppConfig.isVoiceChatConfigured else {
            print("❌ [AgoraVoiceManager] Cannot initialize: Agora App ID is not configured. See Secrets.plist.example.")
            return
        }
        
        print("🎤 Initializing Agora engine...")
        
        // Configure audio session FIRST
        setupAudioSession()
        
        // Initialize Agora engine
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: appId, delegate: self)
        
        guard let agoraKit = agoraKit else {
            print("❌ Failed to initialize Agora engine")
            return
        }
        
        // Configure engine settings
        agoraKit.setChannelProfile(.communication)
        agoraKit.enableAudio()
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        agoraKit.enableAudioVolumeIndication(1000, smooth: 3, reportVad: true)
        
        // Audio quality settings
        agoraKit.setAudioProfile(.default)
        
        // Set initial volumes
        agoraKit.adjustRecordingSignalVolume(currentRecordingVolume)
        agoraKit.adjustPlaybackSignalVolume(currentPlaybackVolume)
        
        isEngineInitialized = true
        print("✅ Agora engine initialized successfully")
    }
    
    private func setupAudioSession() {
        guard !audioSessionConfigured else {
            print("🎧 Audio session already configured")
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Set category for voice chat
            try session.setCategory(.playAndRecord,
                                  mode: .voiceChat,
                                  options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            
            // Set preferred sample rate and buffer duration
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.005)
            
            // Activate the session
            try session.setActive(true)
            
            audioSessionConfigured = true
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Audio session configuration failed: \(error)")
        }
    }
    
    // MARK: - Channel Management
    func joinChannel(channelId: String, token: String? = nil, uid: UInt? = nil) {
        print("🎤 Attempting to join channel: \(channelId)")
        
        // Initialize engine if not already done
        if !isEngineInitialized {
            initializeAgoraEngine()
        }
        
        guard let agoraKit = agoraKit else {
            print("❌ Agora engine not available")
            return
        }
        
        // Leave current channel if joined to different one
        if isJoined && currentChannelId != channelId {
            print("🔄 Leaving current channel to join new one")
            leaveChannel()
            
            // Wait a bit before joining new channel
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.joinChannel(channelId: channelId, token: token, uid: uid)
            }
            return
        }
        
        if isJoined && currentChannelId == channelId {
            print("⚠️ Already joined this channel")
            return
        }
        
        // Generate UID if not provided
        let joinUID: UInt
        if let uid = uid {
            joinUID = uid
        } else {
            joinUID = generateUID()
        }
        
        currentUID = joinUID
        currentChannelId = channelId
        
        print("🎤 Joining channel '\(channelId)' with UID: \(joinUID)")
        
        // Join channel
        let result = agoraKit.joinChannel(byToken: token,
                                        channelId: channelId,
                                        info: nil,
                                        uid: joinUID) { [weak self] (channel, uid, elapsed) in
            DispatchQueue.main.async {
                self?.isJoined = true
                self?.connectionState = .connected
                print("✅ Successfully joined channel: \(channel) with UID: \(uid)")
            }
        }
        
        if result != 0 {
            print("❌ Failed to join channel with error code: \(result)")
            DispatchQueue.main.async {
                self.connectionState = .failed
            }
        }
    }
    
    func leaveChannel() {
        guard let agoraKit = agoraKit else { return }
        
        print("🚪 Leaving voice channel...")
        
        let result = agoraKit.leaveChannel { [weak self] stats in
            DispatchQueue.main.async {
                self?.isJoined = false
                self?.connectionState = .disconnected
                self?.currentChannelId = nil
                self?.currentUID = 0
                self?.remoteUsers.removeAll()
                print("✅ Left channel successfully")
            }
        }
        
        if result != 0 {
            print("❌ Failed to leave channel with error code: \(result)")
        }
    }
    
    // MARK: - ✅ IMPROVED: Audio Controls with Better Return Values
    func muteMic(_ mute: Bool) {
        guard let agoraKit = agoraKit, isJoined else {
            print("⚠️ Cannot mute: engine not available or not joined")
            return
        }
        
        let result = agoraKit.muteLocalAudioStream(mute)
        if result == 0 {
            DispatchQueue.main.async {
                self.isMuted = mute
            }
            print("🎤 Microphone \(mute ? "muted" : "unmuted") successfully")
        } else {
            print("❌ Failed to \(mute ? "mute" : "unmute") microphone with error: \(result)")
        }
    }
    
    func adjustPlaybackVolume(_ volume: Int) -> Int {
        guard let agoraKit = agoraKit else {
            print("⚠️ Cannot adjust playback volume: engine not available")
            return currentPlaybackVolume
        }
        
        let clampedVolume = max(0, min(400, volume))
        let result = agoraKit.adjustPlaybackSignalVolume(clampedVolume)
        
        if result == 0 {
            DispatchQueue.main.async {
                self.currentPlaybackVolume = clampedVolume
            }
            print("🔊 Playback volume set to: \(clampedVolume)")
            return clampedVolume
        } else {
            print("❌ Failed to adjust playback volume to \(clampedVolume), error: \(result)")
            return currentPlaybackVolume
        }
    }
    
    func adjustRecordingVolume(_ volume: Int) -> Int {
        guard let agoraKit = agoraKit else {
            print("⚠️ Cannot adjust recording volume: engine not available")
            return currentRecordingVolume
        }
        
        let clampedVolume = max(0, min(400, volume))
        let result = agoraKit.adjustRecordingSignalVolume(clampedVolume)
        
        if result == 0 {
            DispatchQueue.main.async {
                self.currentRecordingVolume = clampedVolume
            }
            print("🎤 Recording volume set to: \(clampedVolume)")
            return clampedVolume
        } else {
            print("❌ Failed to adjust recording volume to \(clampedVolume), error: \(result)")
            return currentRecordingVolume
        }
    }
    
    // MARK: - ✅ NEW: Audio State Helpers
    func getCurrentPlaybackVolume() -> Int {
        return currentPlaybackVolume
    }
    
    func getCurrentRecordingVolume() -> Int {
        return currentRecordingVolume
    }
    
    func getAudioState() -> (playback: Int, recording: Int, muted: Bool) {
        return (currentPlaybackVolume, currentRecordingVolume, isMuted)
    }
    
    // MARK: - Utility Methods
    private func generateUID() -> UInt {
        // Generate more reliable UID
        let timestamp = UInt(Date().timeIntervalSince1970)
        let random = UInt.random(in: 100...999)
        let uid = (timestamp % 100000) * 1000 + random
        print("🆔 Generated UID: \(uid)")
        return uid
    }
    
    func getCurrentUID() -> UInt {
        return currentUID
    }
    
    func getCurrentChannelId() -> String? {
        return currentChannelId
    }
    
    // MARK: - ✅ IMPROVED: Reconnection
    func reconnect() {
        guard let channelId = currentChannelId else {
            print("⚠️ No channel to reconnect to")
            return
        }
        
        print("🔄 Reconnecting to voice channel...")
        
        // Leave current channel
        leaveChannel()
        
        // Wait and rejoin
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.joinChannel(channelId: channelId)
        }
    }
    
    // MARK: - ✅ IMPROVED: Cleanup
    func destroyInstance() {
        print("🧹 Destroying Agora instance...")
        
        if isJoined {
            leaveChannel()
        }
        
        // Wait a bit for leave to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Deactivate audio session
            if self.audioSessionConfigured {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    self.audioSessionConfigured = false
                } catch {
                    print("❌ Failed to deactivate audio session: \(error)")
                }
            }
            
            // Destroy engine
            if self.isEngineInitialized {
                AgoraRtcEngineKit.destroy()
                self.agoraKit = nil
                self.isEngineInitialized = false
            }
            
            // Reset state
            DispatchQueue.main.async {
                self.isJoined = false
                self.isMuted = false
                self.connectionState = .disconnected
                self.remoteUsers.removeAll()
                self.currentChannelId = nil
                self.currentUID = 0
                self.currentPlaybackVolume = 200
                self.currentRecordingVolume = 200
            }
            
            print("✅ Agora instance destroyed")
        }
    }
    
    // MARK: - ✅ NEW: Health Check
    func performHealthCheck() -> Bool {
        let isHealthy = isEngineInitialized &&
                       audioSessionConfigured &&
                       (isJoined ? (currentChannelId != nil) : true)
        
        print("🏥 Voice health check: \(isHealthy ? "HEALTHY" : "UNHEALTHY")")
        print("   - Engine: \(isEngineInitialized)")
        print("   - Audio Session: \(audioSessionConfigured)")
        print("   - Joined: \(isJoined)")
        print("   - Channel: \(currentChannelId ?? "none")")
        
        return isHealthy
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraVoiceManager {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.isJoined = true
            self.connectionState = .connected
            print("✅ Local user joined channel: \(channel) with UID: \(uid)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.remoteUsers.insert(uid)
            print("👤 Remote user joined: \(uid) (Total remote users: \(self.remoteUsers.count))")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            self.remoteUsers.remove(uid)
            print("👋 Remote user left: \(uid), reason: \(reason.rawValue) (Remaining: \(self.remoteUsers.count))")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        DispatchQueue.main.async {
            self.connectionState = state
            print("🔗 Connection state changed to: \(state.rawValue), reason: \(reason.rawValue)")
            
            // Handle connection failures
            if state == .failed || state == .disconnected {
                self.isJoined = false
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("❌ Agora error occurred: \(errorCode.rawValue)")
        
        DispatchQueue.main.async {
            // Handle specific errors
            switch errorCode {
            case .invalidToken, .tokenExpired:
                print("🔑 Token issue - need to refresh token")
            case .timedOut:
                print("⏰ Connection timed out")
                self.connectionState = .failed
            case .invalidChannelId:
                print("📺 Invalid channel ID")
            case .noServerResources:
                print("🖥️ No server resources available")
            case .refused:
                print("🚫 Request refused by server")
            default:
                print("🔥 Other error: \(errorCode.rawValue)")
            }
            
            // Notify VoiceChannelManager about the error
            VoiceChannelManager.shared.handleVoiceError(NSError(domain: "AgoraError", code: Int(errorCode.rawValue), userInfo: [NSLocalizedDescriptionKey: "Agora error: \(errorCode.rawValue)"]))
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("⚠️ Agora warning: \(warningCode.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        // Handle volume indication for UI feedback
        for speaker in speakers {
            if speaker.uid == 0 {
                // Local user speaking
                if speaker.volume > 10 {
                    // Only print occasionally to avoid spam
                    if speaker.volume > 50 {
                        print("🎤 Local user speaking: volume \(speaker.volume)")
                    }
                }
            } else {
                // Remote user speaking
                if speaker.volume > 10 {
                    // Only print occasionally to avoid spam
                    if speaker.volume > 50 {
                        print("🔊 Remote user \(speaker.uid) speaking: volume \(speaker.volume)")
                    }
                }
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, audioRouteChanged routing: AgoraAudioOutputRouting) {
        let routeName = routingName(for: routing)
        print("🎧 Audio route changed to: \(routeName)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        print("🔇 User \(uid) \(muted ? "muted" : "unmuted") their audio")
    }
    
    func rtcEngineConnectionDidInterrupted(_ engine: AgoraRtcEngineKit) {
        print("⚠️ Connection interrupted")
        DispatchQueue.main.async {
            self.connectionState = .reconnecting
        }
    }
    
    func rtcEngineConnectionDidLost(_ engine: AgoraRtcEngineKit) {
        print("📡 Connection lost")
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.isJoined = false
        }
    }
    
    private func routingName(for routing: AgoraAudioOutputRouting) -> String {
        switch routing {
        case .default: return "Default"
        case .headset: return "Headset"
        case .earpiece: return "Earpiece"
        case .headsetNoMic: return "Headset (No Mic)"
        case .speakerphone: return "Speakerphone"
        case .loudspeaker: return "Loudspeaker"
        case .bluetoothDeviceHfp: return "Bluetooth Hfp"
        case .usb: return "Usb"
        case .hdmi: return "HDMI"
        case .displayPort: return "Display Port"
        case .airPlay: return "airPlay"
        case .bluetoothDeviceA2dp: return "Bluetooth A2dp"
        @unknown default: return "Unknown"
        }
    }
    
    func rtcEngineRequestToken(_ engine: AgoraRtcEngineKit) {
        print("🔑 Token expired - need to renew")
        // Implement token renewal logic here if using tokens
    }
}
