import SwiftUI
import AVFoundation

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var statisticsManager = GameStatisticsManager.shared
    @StateObject private var musicManager = BackgroundMusicManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // ✅ NUOVO: Timer per aggiornamenti in tempo reale
    @State private var updateTimer: Timer?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    headerSection
                    
                    ScrollView {
                        
                        VStack(spacing: 30) {
                            
                            // ✅ ENHANCED: Background Music Section (più prominente)
                            enhancedBackgroundMusicSection
                            
                            // Audio Settings Section (senza test audio)
                            audioSettingsSection
                            

                            // Game Statistics Section
                            statisticsSection
                            
                            // Reset Section
                            resetSection
                            
                            Spacer(minLength: 50)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("📊 Settings appeared - syncing statistics with game state")
            statisticsManager.syncWithGameState()
            startRealTimeUpdates()
        }
        .onDisappear {
            stopRealTimeUpdates()
        }
    }
    
    // MARK: - Real-time Updates
    private func startRealTimeUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if SharedGameStateManager.shared.isTimerRunning {
                statisticsManager.syncWithGameState()
            }
        }
    }
    
    private func stopRealTimeUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .bold))
                        Text("BACK")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                }
                .padding(.leading, 20)
                .padding(.top, 20)
                
                Spacer()
            }
            
            Text("SETTINGS")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
                .padding(.bottom, -1)
                .padding(.top, -10)
        }
    }
    
    // MARK: - ✅ ENHANCED: Background Music Section (più prominente)
    private var enhancedBackgroundMusicSection: some View {
        VStack(spacing: 25) {
            HStack {
                sectionHeader(NSLocalizedString("BACKGROUND MUSIC", comment: "") )
                
                // ✅ NEW: Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(musicManager.isMusicEnabled ? .green : .red)
                        .frame(width: 12, height: 12)
                    Text(musicManager.isMusicEnabled ? "ON" : "OFF")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(musicManager.isMusicEnabled ? .green : .red)
                }
            }
            
            VStack(spacing: 30) {
                // ✅ ENHANCED: Larger, more prominent music toggle
                VStack(spacing: 15) {
                    Button(action: {
                        musicManager.toggleMusic()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: musicManager.isMusicEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(musicManager.isMusicEnabled ? .black : .white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(musicManager.isMusicEnabled ? "MUSIC ENABLED" : "MUSIC DISABLED")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundColor(musicManager.isMusicEnabled ? .black : .white)
                                
                                Text(musicManager.isMusicEnabled ? "TAP TO DISABLE" : "TAP TO ENABLE")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(musicManager.isMusicEnabled ? .black.opacity(0.7) : .white.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 25)
                        .padding(.vertical, 20)
                        .background(
                            Rectangle()
                                .fill(musicManager.isMusicEnabled ? Color.white : Color.black)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                        )
                    }
                    
                    Text(musicManager.isMusicEnabled ?
                         "Background music plays in main menu only" :
                         "No background music will play")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Music Volume Slider (only if enabled)
                if musicManager.isMusicEnabled {
                    settingSlider(
                        title: NSLocalizedString("MUSIC VOLUME", comment: ""),
                        value: Binding(
                            get: { Double(musicManager.musicVolume) },
                            set: { musicManager.setVolume(Float($0)) }
                        ),
                        range: 0...1,
                        formatValue: { "\(Int($0 * 100))%" }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(25)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 5)
                    )
            )
        }
        .animation(.easeInOut(duration: 0.3), value: musicManager.isMusicEnabled)
    }
    
    // MARK: - ✅ CLEANED: Audio Settings Section (senza test audio)
    private var audioSettingsSection: some View {
        VStack(spacing: 25) {
            sectionHeader(NSLocalizedString("AUDIO", comment: ""))
            
            VStack(spacing: 30) {
                // Master Volume
                settingSlider(
                    title: NSLocalizedString("MASTER VOLUME", comment: "") ,
                    value: $settingsManager.masterVolume,
                    range: 0...1,
                    formatValue: { "\(Int($0 * 100))%" }
                )
                
                // Sound Effects Volume
                settingSlider(
                    title: NSLocalizedString("SOUND EFFECTS", comment: "") ,
                    value: $settingsManager.soundEffectsVolume,
                    range: 0...1,
                    formatValue: { "\(Int($0 * 100))%" }
                )
                
                // Voice Chat Volume
                settingSlider(
                    title: NSLocalizedString("VOICE CHAT", comment: ""),
                    value: $settingsManager.voiceChatVolume,
                    range: 0...1,
                    formatValue: { "\(Int($0 * 100))%" }
                )
                
                // Vibration Toggle
                settingToggle(
                    title: NSLocalizedString("VIBRATION", comment: ""),
                    isOn: $settingsManager.vibrationEnabled,
                    description: NSLocalizedString("HAPTIC FEEDBACK", comment: "")
                )
            }
            .padding(25)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 5)
                    )
            )
        }
    }
    
    // MARK: - ✅ UPDATED: Language Settings Section (francese bloccato + restart)
    /*
    private var languageSettingsSection: some View {
        VStack(spacing: 25) {
            sectionHeader("LANGUAGE")
            
            VStack(spacing: 30) {
                // Current Language Display
                HStack {
                    Text("CURRENT LANGUAGE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1)
                    Spacer()
                    Text(settingsManager.currentLanguageName)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Rectangle()
                                .fill(Color.white)
                                .overlay(
                                    Rectangle()
                                        .fill(Color.black)
                                        .padding(2)
                                )
                        )
                }
                
                // Language Selection
                VStack(spacing: 15) {
                    Text("SELECT LANGUAGE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        languageButton("ENGLISH", language: .english, isEnabled: true)
                        languageButton("ITALIANO", language: .italian, isEnabled: true)
                        languageButton("ESPAÑOL", language: .spanish, isEnabled: true)
                        languageButton("FRANÇAIS", language: .french, isEnabled: false) // ✅ BLOCCATO
                    }
                }
            }
            .padding(25)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 4)
                    )
            )
        }
    }
    */
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(spacing: 25) {
            HStack {
                sectionHeader(NSLocalizedString("STATISTICS", comment: ""))
                
                if SharedGameStateManager.shared.isTimerRunning {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            }
            
            VStack(spacing: 20) {
                // Statistics Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    statisticCard(
                        title: NSLocalizedString("GAMES", comment: ""),
                        value: "\(statisticsManager.totalGamesPlayed)",
                        icon: "■"
                    )
                    
                    statisticCard(
                        title: NSLocalizedString("WON", comment: ""),
                        value: "\(statisticsManager.totalGamesWon)",
                        icon: "▲"
                    )
                    
                    statisticCard(
                        title: NSLocalizedString("WIN RATE", comment: ""),
                        value: "\(statisticsManager.winRatePercentage)%",
                        icon: "►"
                    )
                    
                    statisticCard(
                        title: NSLocalizedString("BEST TIME", comment: ""),
                        value: statisticsManager.bestTimeString,
                        icon: "●"
                    )
                    
                    statisticCard(
                        title: NSLocalizedString("AVG TIME", comment: ""),
                        value: statisticsManager.averageTimeString,
                        icon: "◆"
                    )
                    
                    statisticCard(
                        title: NSLocalizedString("ERRORS", comment: ""),
                        value: "\(statisticsManager.totalErrors)",
                        icon: "✕"
                    )
                }
                
                if SharedGameStateManager.shared.isTimerRunning {
                    currentGameStatsSection
                }
                
                detailedStatsSection
            }
            .padding(25)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 4)
                    )
            )
        }
    }
    
    private var currentGameStatsSection: some View {
        VStack(spacing: 15) {
            Text("CURRENT GAME")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .tracking(1)
            
            HStack(spacing: 20) {
                VStack(spacing: 5) {
                    Text("TIME")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(SharedGameStateManager.shared.timeString)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 30)
                
                VStack(spacing: 5) {
                    Text("ERRORS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("\(SharedGameStateManager.shared.totalErrors)/3")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: 30)
                
                VStack(spacing: 5) {
                    Text("STATUS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(SharedGameStateManager.shared.isGameWon ? "WON" :
                         SharedGameStateManager.shared.isGameOver ? "LOST" : "PLAYING")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 15)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .fill(Color.white)
                            .padding(3)
                    )
            )
        }
    }
    
    // MARK: - ✅ SIMPLIFIED: Reset Section
    private var resetSection: some View {
        VStack(spacing: 25) {
            sectionHeader(NSLocalizedString("RESET", comment: "") )
            
            VStack(spacing: 20) {
                resetButton(
                    title: NSLocalizedString("RESET AUDIO", comment: ""),
                    description: NSLocalizedString("RESTORE DEFAULTS", comment: ""),
                    action: {
                        settingsManager.resetAudioSettings()
                        musicManager.isMusicEnabled = true
                        musicManager.setVolume(0.3)
                    }
                )
                
                resetButton(
                    title: NSLocalizedString("RESET STATISTICS", comment: ""),
                    description: NSLocalizedString("CLEAR ALL DATA", comment: ""),
                    action: {
                        statisticsManager.resetAllStatistics()
                    }
                )
            }
            .padding(25)
            .background(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 4)
                    )
            )
        }
    }
    
    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
            Spacer()
        }
    }
    
    private func settingSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        formatValue: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1)
                Spacer()
                Text(formatValue(value.wrappedValue))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Rectangle()
                            .fill(Color.white)
                            .overlay(
                                Rectangle()
                                    .fill(Color.black)
                                    .padding(2)
                            )
                    )
            }
            
            HStack {
                Text("0")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.gray)
                
                Slider(value: value, in: range)
                    .accentColor(.white)
                
                Text("100")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func settingToggle(
        title: String,
        isOn: Binding<Bool>,
        description: String? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .gray))
        }
    }
    
    // ✅ UPDATED: Language button con supporto per disable e restart
    private func languageButton(_ title: String, language: AppLanguage, isEnabled: Bool) -> some View {
        Button(action: {
            guard isEnabled else { return }
            
            // ✅ NEW: Change language con restart se necessario
            if settingsManager.currentLanguage != language {
                settingsManager.setLanguage(language)
                
                // ✅ Se c'è una partita in corso, avvisa che serve restart
                if SharedGameStateManager.shared.isTimerRunning || GameKitManager.shared.inLobby {
                    // Per ora solo cambio lingua, restart manuale
                    print("🌍 Language changed to \(language.displayName)")
                }
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(
                    !isEnabled ? .gray :
                    settingsManager.currentLanguage == language ? .black : .white
                )
                .tracking(1)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Rectangle()
                        .fill(
                            !isEnabled ? Color.black :
                            settingsManager.currentLanguage == language ? Color.white : Color.black
                        )
                        .overlay(
                            Rectangle()
                                .stroke(
                                    !isEnabled ? Color.gray : Color.white,
                                    lineWidth: 2
                                )
                        )
                )
        }
        .disabled(!isEnabled)
        .overlay(
            // ✅ "COMING SOON" per francese
            !isEnabled ?
            Text("COMING SOON")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(Color.black)
                .offset(y: 15)
            : nil
        )
    }
    
    private func statisticCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(Color.white)
                .overlay(
                    Rectangle()
                        .fill(Color.black)
                        .padding(3)
                )
        )
    }
    
    private var detailedStatsSection: some View {
        VStack(spacing: 15) {
            Text("DETAILED STATS")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(1)
            
            VStack(spacing: 10) {
                statRow(NSLocalizedString("ECHO GAMES:", comment: ""), "\(statisticsManager.gamesAsMute)")
                statRow(NSLocalizedString("LUMO GAMES:", comment: ""), "\(statisticsManager.gamesAsBlind)")
                statRow(NSLocalizedString("FASTEST WIN:", comment: ""), statisticsManager.fastestWinString)
                statRow(NSLocalizedString("ACCURACY:", comment: ""), "\(statisticsManager.communicationAccuracy)%")
                statRow(NSLocalizedString("AVG ERRORS:", comment: ""), String(format: "%.1f", statisticsManager.averageErrorsPerGame))
            }
        }
    }
    
    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    private func resetButton(
        title: String,
        description: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(destructive ? .black : .white)
                        .tracking(1)
                    
                    Text(description)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(
                Rectangle()
                    .fill(destructive ? Color.white : Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 3)
                    )
            )
        }
    }
}

// MARK: - Language Support
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case italian = "it"
    case spanish = "es"
    case french = "fr"
    
    var displayName: String {
        switch self {
        case .english: return "ENGLISH"
        case .italian: return "ITALIANO"
        case .spanish: return "ESPAÑOL"
        case .french: return "FRANÇAIS"
        }
    }
}

// MARK: - ✅ UPDATED: Settings Manager (senza audio test players)
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var masterVolume: Double = 0.8
    @Published var soundEffectsVolume: Double = 0.7
    @Published var voiceChatVolume: Double = 0.9
    @Published var vibrationEnabled: Bool = true
    @Published var currentLanguage: AppLanguage = .english
    
    var currentLanguageName: String {
        currentLanguage.displayName
    }
    
    private init() {
        loadSettings()
    }
    
    // ✅ FIXED: Correct Boolean handling
    private func loadSettings() {
        if UserDefaults.standard.object(forKey: "masterVolume") != nil {
            masterVolume = UserDefaults.standard.double(forKey: "masterVolume")
        } else {
            masterVolume = 0.8
        }
        
        if UserDefaults.standard.object(forKey: "soundEffectsVolume") != nil {
            soundEffectsVolume = UserDefaults.standard.double(forKey: "soundEffectsVolume")
        } else {
            soundEffectsVolume = 0.7
        }
        
        if UserDefaults.standard.object(forKey: "voiceChatVolume") != nil {
            voiceChatVolume = UserDefaults.standard.double(forKey: "voiceChatVolume")
        } else {
            voiceChatVolume = 0.9
        }
        
        if UserDefaults.standard.object(forKey: "vibrationEnabled") != nil {
            vibrationEnabled = UserDefaults.standard.bool(forKey: "vibrationEnabled")
        } else {
            vibrationEnabled = true
        }
        
        // Load language setting
        if let languageRawValue = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: languageRawValue) {
            currentLanguage = language
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(masterVolume, forKey: "masterVolume")
        UserDefaults.standard.set(soundEffectsVolume, forKey: "soundEffectsVolume")
        UserDefaults.standard.set(voiceChatVolume, forKey: "voiceChatVolume")
        UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled")
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
    }
    
    // ✅ NEW: Language change con automatic save
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        saveSettings()
        print("🌍 Language changed to: \(language.displayName)")
        
        // ✅ Trigger app language change (if implementing localization)
        // NotificationCenter.default.post(name: .languageChanged, object: language)
    }
    
    func resetAudioSettings() {
        masterVolume = 0.8
        soundEffectsVolume = 0.7
        voiceChatVolume = 0.9
        vibrationEnabled = true
        currentLanguage = .english
        saveSettings()
    }
    
    var effectiveVolume: Float {
        return Float(masterVolume * soundEffectsVolume)
    }
}

#Preview {
    SettingsView()
}
