//
//  ManualView.swift
//  FinalProject
//
//  FIXED: Back button navigation to return to MainMenuView
//

import SwiftUI

struct ManualView: View {
    @State private var currentPage: Int = 0
    @State private var selectedGame: Int = 1
    @State private var showWorkInProgressAlert = false
    
    // ✅ FIXED: Use @Environment presentationMode for iOS compatibility
    @Environment(\.presentationMode) var presentationMode
    
    private let sectionTitles = [NSLocalizedString("HOW TO PLAY", comment: ""),NSLocalizedString("INTRODUCTION", comment: "") ,NSLocalizedString("SCORING", comment: "") ,NSLocalizedString("OBJECTIVE", comment: "") ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // ✅ FIXED: Back button with explicit dismiss
                    HStack {
                        Button(action: {
                            // Multiple dismiss methods to ensure it works
                            presentationMode.wrappedValue.dismiss()
                            
                            // Backup method
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    window.rootViewController?.dismiss(animated: true)
                                }
                            }
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
                        .padding(.top, 20)
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    
                    // Game Selection - Compact horizontal bar
                    /*
                    HStack(spacing: 16) {
                        Text("SELECT THE GAME:")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            // Game 1 - Available
                            Button(action: {
                                selectedGame = 1
                            }) {
                                CompactGameButton(
                                    gameNumber: 1,
                                    title: "FUSE",
                                    isSelected: selectedGame == 1,
                                    isLocked: false
                                )
                            }
                            
                            // Game 2 - Locked
                            Button(action: {
                                showWorkInProgressAlert = true
                            }) {
                                CompactGameButton(
                                    gameNumber: 2,
                                    title: "CIPHER",
                                    isSelected: false,
                                    isLocked: true
                                )
                            }
                            
                            // Game 3 - Locked
                            Button(action: {
                                showWorkInProgressAlert = true
                            }) {
                                CompactGameButton(
                                    gameNumber: 3,
                                    title: "QUANTUM",
                                    isSelected: false,
                                    isLocked: true
                                )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    */
                    // Manual Content
                    HStack {
                        // Content Area
                        TabView(selection: $currentPage) {
                            BrutalistModule(
                                icon: "▿",
                                title: NSLocalizedString("HOW TO PLAY", comment: ""),
                                subtitle: NSLocalizedString("STEP-BY-STEP GUIDE", comment: ""),
                                description: NSLocalizedString("Follow these simple steps to complete your mission and escape the room.", comment: ""),
                                rules: [
                                    NSLocalizedString("STEP 1: TEAM COORDINATION", comment: ""),
                                    NSLocalizedString("• VIBE player opens the manual", comment: ""),
                                    NSLocalizedString("• LUMO player listens for audio cues", comment: ""),
                                    NSLocalizedString("• ECHO player prepares for fuse insertion", comment: ""),
                                    "",
                                    NSLocalizedString("STEP 2: DECODE THE SEQUENCE", comment: ""),
                                    NSLocalizedString("• VIBE finds symbol combinations in manual", comment: ""),
                                    NSLocalizedString("• LUMO decodes Morse code from sounds", comment: ""),
                                    NSLocalizedString("• Communicate to determine correct order", comment: ""),
                                    "",
                                    NSLocalizedString("STEP 3: EXECUTE THE MISSION", comment: ""),
                                    NSLocalizedString("• ECHO drags colored fuses to matching symbols", comment: ""),
                                    NSLocalizedString("• Follow the sequence determined by team", comment: ""),
                                    NSLocalizedString("• Complete all 4 fuse placements", comment: ""),
                                    "",
                                    NSLocalizedString("STEP 4: SUCCESS!", comment: ""),
                                    NSLocalizedString("• Door opens when sequence is correct", comment: ""),
                                    NSLocalizedString("• Celebrate your escape from the alien room!", comment: "")
                                ]
                            )
                            .tag(0)

                            BrutalistModule(
                                icon: "⟆",
                                title: NSLocalizedString("INTRODUCTION", comment: ""),
                                subtitle: NSLocalizedString("ZORBONIAN OPERATIONAL MANUAL", comment: ""),
                                description: NSLocalizedString("GREETINGS, BIPEDAL CREATURE!\nCongratulations on finding this precious document! Your tiny grasping appendages should be sufficient to complete this operation... maybe.\n\nWARNING: If you're reading this, it means our security system has failed miserably. We also hope you have friends, because you'll need them.", comment: ""),
                                rules: [
                                    NSLocalizedString("CLASSIFICATION: ⟆⟟⋉⧫⟟⋏⏃⍀⋔ ⟒⧫⍜⋏⁅⋔⟟⋏⟒⍀", comment: ""),
                                    NSLocalizedString("Guide for Primitive Terrestrial Life Forms", comment: "")
                                ]
                            )
                            .tag(1)

                            BrutalistModule(
                                icon: "◼",
                                title: NSLocalizedString("SCORING", comment: ""),
                                subtitle: NSLocalizedString("PERFORMANCE METRICS", comment: ""),
                                description: NSLocalizedString("TIME LIMIT: 10 Earth minutes\nERROR TOLERANCE: Maximum 2 mistakes allowed", comment: ""),
                                rules: [
                                    NSLocalizedString("SUCCESS CONDITIONS:", comment: ""),
                                    NSLocalizedString("• All fuses placed in correct sequence", comment: ""),
                                    NSLocalizedString("• Proper symbol matches", comment: ""),
                                    NSLocalizedString("• Device activation (probably)", comment: ""),
                                    NSLocalizedString("• Prove Earth creatures aren't hopeless", comment: ""),
                                    "",
                                    NSLocalizedString("FEEDBACK SYSTEM:", comment: ""),
                                    NSLocalizedString("• When VIBE places battery correctly:", comment: ""),
                                    NSLocalizedString("  - LUMO receives visual  notification", comment: ""),
                                    NSLocalizedString("  - ECHO receives audio confirmation sound", comment: ""),
                                    NSLocalizedString("  - Progress tracking for all team members", comment: ""),
                                    "",
                                    NSLocalizedString("FAILURE CONDITIONS:", comment: ""),
                                    NSLocalizedString("• Wrong sequence or pairings", comment: ""),
                                    NSLocalizedString("• Timeout", comment: ""),
                                    NSLocalizedString("• Cosmic disappointment", comment: ""),
                                    NSLocalizedString("• Alien disdain", comment: "")
                                ]
                            )
                            .tag(2)

                            BrutalistModule(
                                icon: "◍",
                                title: NSLocalizedString("OBJECTIVE", comment: ""),
                                subtitle: NSLocalizedString("MISSION PARAMETERS", comment: ""),
                                description: NSLocalizedString("Open the door of the room you are trapped in by inserting four fuses into the corresponding slots following a precise order.", comment: ""),
                                rules: [
                                    NSLocalizedString("VIBE DIRECTIVES:", comment: ""),
                                    NSLocalizedString("• Access fuse configuration", comment: ""),
                                    NSLocalizedString("• Find combinations on last page", comment: ""),
                                    NSLocalizedString("• Each contains:", comment: ""),
                                    NSLocalizedString("  - Alien symbol", comment: ""),
                                    NSLocalizedString("  - Color", comment: ""),
                                    NSLocalizedString("  - Morse code letter", comment: ""),
                                    "",
                                    NSLocalizedString("LUMO ROLE:", comment: ""),
                                    NSLocalizedString("• Decodes correct order from sound", comment: ""),
                                    NSLocalizedString("• Matches Morse codes with descriptions", comment: ""),
                                    "",
                                    NSLocalizedString("ECHO ROLE:", comment: ""),
                                    NSLocalizedString("• Physically inserts fuses", comment: ""),
                                    NSLocalizedString("• Drags colored fuse to symbol", comment: ""),
                                    NSLocalizedString("• Releases to attempt pairing", comment: "")
                                ]
                            )
                            .tag(3)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(width: geometry.size.width * 0.6)
                        .padding(.leading, 10)
                        .padding(.top, 10)
                        
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
                            .padding(.top, 5)
                            .padding(.trailing, 35)

                            VStack(spacing: 16) {
                                Text("SECTIONS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .tracking(1)
                                    .padding(.trailing, 50)
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
                            .padding(.trailing, 46)
                        }
                        .frame(width: geometry.size.width * 0.35)
                        .padding(.top, -30)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("WORK IN PROGRESS", isPresented: $showWorkInProgressAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This game is still under development.\nStay tuned for future updates!")
        }
        .onAppear {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
            }
        }
        // ✅ ADDED: Swipe down gesture to dismiss (iOS standard)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 && abs(value.translation.width) < 100 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
    }
}

// MARK: - Compact Game Button (unchanged)
struct CompactGameButton: View {
    let gameNumber: Int
    let title: String
    let isSelected: Bool
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            // Number/Lock icon
            ZStack {
                Rectangle()
                    .fill(isSelected ? Color.white : (isLocked ? Color.gray.opacity(0.3) : Color.white.opacity(0.2)))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: isSelected ? 2 : 1)
                    )
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(gameNumber)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(isSelected ? .black : .white)
                }
            }
            
            // Title
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .white : (isLocked ? .gray : .white.opacity(0.7)))
                .tracking(0.3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.clear)
        .opacity(isLocked ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    ManualView()
}
