# Trustfall

An Asymmetric Cooperative Multiplayer Game for iOS  
Engineered as a Capstone Project at the Apple Developer Academy.

---

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. Core Game Design and Mechanics](#2-core-game-design-and-mechanics)
  - [2.1 The Sensory Triad: Asymmetric Roles](#21-the-sensory-triad-asymmetric-roles)
  - [2.2 Cooperative Gameplay Loop](#22-cooperative-gameplay-loop)
- [3. System Architecture](#3-system-architecture)
  - [3.1 High-Level Architectural Diagram](#31-high-level-architectural-diagram)
  - [3.2 Peer-to-Peer Networking and Synchronization (GameKit)](#32-peer-to-peer-networking-and-synchronization-gamekit)
  - [3.3 Real-Time Voice Communication (Agora RTC Engine)](#33-real-time-voice-communication-agora-rtc-engine)
  - [3.4 Audio Engineering Pipeline (AVFoundation)](#34-audio-engineering-pipeline-avfoundation)
  - [3.5 UI Architecture and Brutalist Design System](#35-ui-architecture-and-brutalist-design-system)
  - [3.6 Localization and Asset Management](#36-localization-and-asset-management)
- [4. Repository Structure](#4-repository-structure)
- [5. Prerequisites and Technical Requirements](#5-prerequisites-and-technical-requirements)
- [6. Installation and Configuration](#6-installation-and-configuration)
  - [6.1 Clone the Repository](#61-clone-the-repository)
  - [6.2 Configure Secrets](#62-configure-secrets)
  - [6.3 Xcode Project Setup and Execution](#63-xcode-project-setup-and-execution)
- [7. Development Status and Engineering Roadmap](#7-development-status-and-engineering-roadmap)
- [8. Authors and Acknowledgments](#8-authors-and-acknowledgments)
- [9. License](#9-license)

---

## 1. Executive Summary

Trustfall is a real-time, peer-to-peer asymmetric cooperative multiplayer game developed natively for iOS using SwiftUI, Apple GameKit, and the Agora Real-Time Communication (RTC) SDK.

The game is designed around sensory deprivation and information asymmetry: three players are placed in distinct roles with deliberately restricted sensory channels. Success requires real-time verbal coordination, active listening, and precision problem-solving under strict time constraints. The project combines low-latency spatial voice processing, robust distributed state synchronization, and a custom brutalist design language.

---

## 2. Core Game Design and Mechanics

### 2.1 The Sensory Triad: Asymmetric Roles

The game session is composed of three interconnected player roles:

| Role Name | In-Game Codename | Sensory Ability | Sensory Restriction | Primary Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **The Blind** | `LUMO` | Hearing + Speech | No Manual / No Terminal | Listens to audio frequencies and sound sequences; visualizes sound wave amplitude; communicates auditory clues over the walkie-talkie. |
| **The Deaf** | `VIBE` | Sight + Manual | Muted Voice Reception | Possesses the technical manual, symbol pairings, and decoding matrices; interprets clues received via non-verbal visual signaling and walkie-talkie transcription. |
| **The Mute** | `ECHO` | Sight + Action | Restricted Speech | Controls the physical console interface (battery placement, sequence insertion, terminal levers); cannot transmit verbal audio and must rely on action execution. |

### 2.2 Cooperative Gameplay Loop

1. **Matchmaking & Role Handshake**: Players connect through Apple Game Center, enter a synchronized lobby, select characters, and receive randomized or chosen asymmetric roles.
2. **Synchronized Narrative Cutscene**: All players view a multi-scene typewriter cutscene where scene progression, dialogue pace, and skip signals are locked across all connected peers.
3. **Puzzle Deconstruction**:
   - `LUMO` triggers audio playback of cryptic extraterrestrial acoustic signals (such as alien frequencies and oscillation patterns).
   - `VIBE` maps the auditory description provided by `LUMO` against the technical decoding manual to decipher the target sequence.
   - `ECHO` receives the decoded sequence instructions and executes the physical drag-and-drop terminal sequence before the shared timer expires.
4. **Failure & Success Conditions**: Incorrect inputs trigger global error accumulation and audio-haptic feedback. Exceeding the error threshold (3 errors) or allowing the 10-minute master timer to expire results in mission failure.

---

## 3. System Architecture

### 3.1 High-Level Architectural Diagram

```
+-------------------------------------------------------------------------+
|                              SwiftUI Views                              |
|   +-------------------+  +--------------------+  +------------------+   |
|   |   MainMenuView    |  | BrutalistLobbyView |  |  GameRouterView  |   |
|   +---------+---------+  +---------+----------+  +--------+---------+   |
+-------------|----------------------|----------------------|-------------+
              |                      |                      |
+-------------v----------------------v----------------------v-------------+
|                            State & Coordination                         |
|   +-------------------------------+  +------------------------------+   |
|   |         GameKitManager        |  |    SharedGameStateManager    |   |
|   |   - Peer-to-Peer Matchmaking  |  |    - Synchronized Master     |   |
|   |   - Connection Lifecycle      |  |      Timer (10:00)           |   |
|   |   - Scene Lockstep Barrier    |  |    - Sequence & Error State  |   |
|   +---------------+---------------+  +--------------+---------------+   |
+-------------------|---------------------------------|-------------------+
                    |                                 |
+-------------------v---------------------------------v-------------------+
|                            Services Layer                               |
|   +--------------------+  +--------------------+  +-----------------+   |
|   |  AgoraVoiceManager |  | VoiceChannelManager|  | Sound Managers  |   |
|   |  - RTC Token/AppID |  | - PTT Microphone   |  | - Background    |   |
|   |  - Dynamic Volumes |  |   Routing          |  | - Error Effects |   |
|   +---------+----------+  +---------+----------+  +--------+--------+   |
+-------------|-----------------------|----------------------|------------+
              |                       |                      |
+-------------v-----------------------v----------------------v------------+
|                            Platform Layer                               |
|       Apple GameKit      |      Agora RTC Engine     |   AVFoundation   |
+-------------------------------------------------------------------------+
```

### 3.2 Peer-to-Peer Networking and Synchronization (GameKit)

Networking is handled by `GameKitManager` and `SharedGameStateManager`:
- **Matchmaking**: Built using `GKMatchmakerViewController` and `GKMatchDelegate`, supporting up to 3 peer connections without requiring a dedicated game server.
- **Data Packaging**: All communication packets are strongly typed, conforming to Swift's `Codable` protocol, and transmitted via reliable (`GKMatch.SendDataMode.reliable`) or unreliable streams depending on latency tolerance.
- **State Barriers**: Includes barrier synchronization primitives (`playersReadyForGame`, `playersReadyForRestart`, `skipRequests`) ensuring no single peer proceeds ahead of the group during narrative transitions.
- **Time Synchronization**: A designated host device manages the master countdown timer and broadcasts tick events with version markers (`gameStateVersion`) to avoid drift and race conditions.

### 3.3 Real-Time Voice Communication (Agora RTC Engine)

Voice interaction is powered by the Agora RTC SDK, encapsulated in `AgoraVoiceManager` and `VoiceChannelManager`:
- **Virtual Walkie-Talkie Interface**: Implements push-to-talk (PTT) mechanics with distinct audio channel routing.
- **Role Constraints in Hardware**: The engine automatically modifies hardware input states; for instance, the Mute role's outgoing stream is muted at the engine driver level while preserving reception capabilities.
- **Audio Routing**: Dynamically directs audio across speakerphones, headsets, and Bluetooth devices using `AVAudioSession` category overrides (`.playAndRecord` with `.defaultToSpeaker`).

### 3.4 Audio Engineering Pipeline (AVFoundation)

In addition to live communication, Trustfall features an autonomous audio sub-system:
- **`BackgroundMusicManager`**: Manages seamless looping ambient soundtracks with automated volume ducking when voice channels are active.
- **`ErrorSoundManager`**: Dispatches procedural auditory failure cues with haptic integration.
- **Acoustic Puzzle Playback**: Dynamic audio player instances playback uncompressed `.wav` frequency waveforms with real-time metering for amplitude visualization in `BlindCombinedGameView`.

### 3.5 UI Architecture and Brutalist Design System

Trustfall adopts a high-contrast brutalist design language:
- **Typography**: Heavy, monospace, and industrial typography designed for clarity under stress.
- **Monochrome Styling**: Black, white, and high-saturation primary colors (Yellow, Green, Red, Blue) designating terminal interactive zones.
- **Reactive Layouts**: Fully responsive `GeometryReader` layouts designed for multi-device iPad and iPhone aspect ratios.

### 3.6 Localization and Asset Management

- **String Catalogs**: Multi-language support driven by Xcode's modern `Localizable.xcstrings` architecture.
- **Privacy Manifest**: Includes an Apple-compliant `PrivacyInfo.xcprivacy` declaring data collection and API usage categories.

---

## 4. Repository Structure

```
Trustfall/
|-- FinalProject.xcodeproj/          # Xcode project configuration
|-- Localizable.xcstrings            # App-wide localization string catalog
|-- LICENSE                          # MIT License specification
|-- .gitignore                       # Git ignore rules for Swift and local secrets
+-- FinalProject/
    |-- FinalProjectApp.swift        # Application entry point (@main)
    |-- AppConfig.swift              # Central configuration and secret resolution
    |-- Secrets.plist.example        # Template for API credentials
    |-- FinalProject.entitlements    # Game Center entitlements
    |-- PrivacyInfo.xcprivacy        # Apple Privacy Manifest
    |-- Character.swift              # Character model and brutalist selection view
    |-- MainMenuView.swift           # Main menu navigation and entry coordinator
    |-- LobbyView.swift              # Lobby coordinator
    |-- BrutalistLobbyView.swift     # High-contrast interactive lobby
    |-- SettingsView.swift           # Volume, haptic, and language preferences
    |-- ManualView.swift             # Field manual interface for the Deaf player
    |
    |-- GameKit/                     # Distributed multiplayer infrastructure
    |   |-- GameKitManager.swift     # Matchmaking, peer delegate, and lifecycle
    |   |-- SharedGameStateManager.swift # Master timer, sequence sync, error checks
    |   |-- Player.swift             # Player model and PlayerRole enum
    |   |-- GameCentreInviteView.swift # Native Game Center invite bridge
    |   |-- GameResultOverlay.swift  # Win/Loss outcome presentation
    |   +-- GameStatisticsManager.swift # Player career and statistics tracking
    |
    |-- VoiceChat/                   # Real-time voice architecture
    |   |-- AgoraVoiceManager.swift  # Agora RTC SDK wrapper and delegate handler
    |   +-- VoiceChannelManager.swift # Channel lifecycle and push-to-talk controller
    |
    |-- Game1/                       # Level 1 cooperative module
    |   |-- GameRouterView.swift     # Dynamic role-based view dispatcher
    |   |-- BlindCombinedGameView.swift # LUMO interface (Audio recognition & wave)
    |   |-- DeafCombinedGameView.swift  # VIBE interface (Manual & pairing matrix)
    |   +-- MuteCombinedGameView.swift  # ECHO interface (Terminal & battery placement)
    |
    |-- Cutscene/                    # Narrative sequencing engine
    |   |-- CutsceneView.swift       # Lockstep multi-peer typewriter cutscene
    |   |-- InterludeGameOne.swift   # Transition screen with procedural noise
    |   +-- AlertType.swift          # Modular alert dialogue models
    |
    |-- Component/                   # Reusable UI and utility components
    |   |-- UnifiedWalkieTalkieView.swift # Push-to-talk walkie-talkie UI
    |   |-- ErrorSoundManager.swift  # Audio error dispatcher
    |   |-- ExitAlertType.swift      # Disconnect and match exit alerts
    |   +-- GameDifficulty.swift     # Difficulty tier definitions
    |
    |-- Sound/                       # Audio assets and playback management
    |   |-- BackgroundMusicManager.swift # Ambient background music coordinator
    |   |-- menu_background_music.wav# Main menu soundtrack
    |   +-- *.wav                    # Alien frequency waveforms (occhio, uovo, etc.)
    |
    +-- Assets.xcassets/             # Graphics, character cards, and iconography
```

---

## 5. Prerequisites and Technical Requirements

- **macOS**: Sonoma 14.0 or newer
- **Xcode**: 16.0 or newer
- **Language**: Swift 5.10 / Swift 6
- **Deployment Target**: iOS 17.0 or iPadOS 17.0+
- **Apple Developer Account**: Required for Game Center peer-to-peer matchmaking capabilities
- **Agora Developer Account**: Required for voice communication credentials (available free at [console.agora.io](https://console.agora.io))

---

## 6. Installation and Configuration

### 6.1 Clone the Repository

```bash
git clone https://github.com/vincenzopiconee/Trustfall.git
cd Trustfall
```

### 6.2 Configure Secrets

Trustfall decouples third-party API keys from source control. To configure voice communication:

1. Duplicate the template file:
   ```bash
   cp FinalProject/Secrets.plist.example FinalProject/Secrets.plist
   ```
2. Open `FinalProject/Secrets.plist` in an editor and insert your Agora App ID:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>AgoraAppID</key>
       <string>YOUR_AGORA_APP_ID_HERE</string>
   </dict>
   </plist>
   ```
   *Note: `Secrets.plist` is excluded by `.gitignore` and will never be pushed to version control.*

### 6.3 Xcode Project Setup and Execution

1. Open `FinalProject.xcodeproj` in Xcode:
   ```bash
   open FinalProject.xcodeproj
   ```
2. Allow Xcode to resolve the Swift Package Manager dependency (`AgoraRtcEngine_iOS`).
3. Select your development team under **Signing & Capabilities** for the `FinalProject` target.
4. Ensure the **Game Center** capability is active and configured in your developer account.
5. Build and run on physical iOS devices or Simulators.  
   *Note: Testing full multiplayer matchmaking and voice communication requires at least two instances (physical devices or distinct Simulator sessions logged into different Game Center Sandbox accounts).*

---

## 7. Development Status and Engineering Roadmap

### Current Status: Functional Prototype / Proof of Concept

The project currently serves as a functional demonstration of asymmetric multiplayer mechanics, real-time voice infrastructure, and peer-to-peer game state synchronization.

### Implemented Features
- Real-time GameKit matchmaking and reliable peer synchronization.
- Three fully implemented asymmetric interfaces (Blind, Deaf, Mute).
- Full push-to-talk walkie-talkie communication via Agora RTC.
- Synchronized multi-player narrative cutscene with lockstep state barriers.
- Integrated settings module with volume controls, haptic toggles, and localization.
- Custom brutalist design system with procedural audio and visual animations.

### Future Roadmap
- Level 2 & 3 modular puzzle expansions with rotating role mechanics.
- In-game dynamic reconnect handling for unexpected peer disconnections.
- End-to-end integration test suite for peer-to-peer message verification.
- App Store production release packaging and accessibility optimizations.

---

## 8. Authors and Acknowledgments

- **Vincenzo Picone** — Engineering Lead, Architecture, GameKit Networking, Agora Voice Infrastructure, SwiftUI UI/UX.
- **Antonio Odore** — Gameplay Mechanics, Data Modeling, Audio Synthesis & Asset Integration.

Developed within the **Apple Developer Academy** curriculum.

---

## 9. License

This project is licensed under the terms of the MIT License. See the [LICENSE](LICENSE) file for full details.
