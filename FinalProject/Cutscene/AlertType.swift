import SwiftUI

enum AlertType {
    case deaf   // VIBE
    case mute   // ECHO
    case blind  // LUMO
    
    var title: String {
        switch self {
        case .deaf:   // VIBE
            return NSLocalizedString("READ THE MANUAL", comment: "")
        case .mute:   // ECHO
            return NSLocalizedString("WAIT FOR VIBE", comment: "")  // Era "WAIT FOR LUMO" - ora corretto
        case .blind:  // LUMO
            return NSLocalizedString("LISTEN CAREFULLY", comment: "")
        }
    }
    
    var message: String {
        switch self {
        case .deaf:   // VIBE
            return NSLocalizedString("UNDERSTAND THE RULES AND COMMUNICATE THEM TO YOUR PARTNERS", comment: "")
        case .mute:   // ECHO
            return NSLocalizedString("TO GET THE CORRECT ORDER OF THE FUSES", comment: "")
        case .blind:  // LUMO
            return NSLocalizedString("ANALYSE THE SOUNDS AND TELL ECHO THE CORRECT ORDER", comment: "")
        }
    }
}

struct BrutalistAlert: View {
    let alertType: AlertType
    let onClose: () -> Void
    
    @State private var backgroundOpacity: Double = 0
    @State private var alertScale: CGFloat = 0.8
    @State private var alertOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var underlineWidth: CGFloat = 0
    @State private var noiseOffset: CGFloat = 0
    // ✅ REMOVED: closeButtonOpacity since no X button
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background overlay
                Rectangle()
                    .fill(Color.black)
                    .opacity(backgroundOpacity * 0.8)
                    .ignoresSafeArea()
                    // ✅ REMOVED: Tap outside doesn't close alert anymore
                
                // Alert container
                ZStack {
                    // Animated noise background effect (similar to original)
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black,
                                    Color(red: 0.05, green: 0.05, blue: 0.05),
                                    Color.black
                                ],
                                center: UnitPoint(x: 0.3 + sin(noiseOffset) * 0.15, y: 0.7 + cos(noiseOffset * 0.8) * 0.15),
                                startRadius: 20,
                                endRadius: 200
                            )
                        )
                        .onAppear {
                            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                                noiseOffset = .pi * 3
                            }
                        }
                    
                    // Subtle scanline effect
                    VStack(spacing: 4) {
                        ForEach(0..<70, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white)
                                .frame(height: 0.1)
                                .opacity(0.012)
                        }
                    }
                    
                    // Alert content
                    VStack(spacing: 8) {
                        // ✅ REMOVED: X button completely
                        
                        Spacer()
                        
                        // Main alert content
                        VStack(spacing: 32) {
                            // Title
                            VStack(spacing: 16) {
                                Text(alertType.title)
                                    .font(.system(size: 36, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(6)
                                    .textCase(.uppercase)
                                    .multilineTextAlignment(.center)
                                    .offset(y: textOffset)
                                    .opacity(alertOpacity)
                                
                                // Animated underline
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: underlineWidth, height: 5)
                                    .animation(.easeOut(duration: 0.6).delay(0.4), value: underlineWidth)
                            }
                            
                            // Message
                            Text(alertType.message)
                                .font(.system(size: 20, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .tracking(3)
                                .textCase(.uppercase)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .offset(y: textOffset + 10)
                                .opacity(alertOpacity * 0.85)
                        }
                        
                        Spacer()
                        
                        // ✅ FIXED: Only "Got it" button closes the alert
                        Button(action: {
                            onClose() // Call onClose which should only hide the alert
                        }) {
                            Text("GOT IT")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .tracking(2)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        }
                        .opacity(alertOpacity)
                        .padding(.bottom, 20)
                    }
                }
                .frame(width: 550, height: 350)
                .background(Color.black)
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 3)
                        .opacity(alertOpacity * 0.8)
                )
                .scaleEffect(alertScale)
                .opacity(alertOpacity)
                .padding(.top, 20)
            }
        }
        .onAppear {
            showAlert()
        }
    }
    
    private func showAlert() {
        // Background fade in
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }
        
        // Alert scale and fade in
        withAnimation(.easeOut(duration: 0.5)) {
            alertScale = 1.0
            alertOpacity = 1.0
        }
        
        // Text slide in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                textOffset = 0
            }
        }
        
        // Underline animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            underlineWidth = 200
        }
        // ✅ REMOVED: Close button animation since no X button
    }
    
    // ✅ REMOVED: dismissAlertOnly() function since only "Got it" button remains
}

#Preview ("LUMO"){
    BrutalistAlert(alertType: .blind) {
        // ✅ FIXED: In preview, this should only print, not exit
        print("Alert dismissed")
    }
    .environment(\.locale, .init(identifier: "es"))
}
#Preview ("ECHO"){
    BrutalistAlert(alertType: .mute) {
        // ✅ FIXED: In preview, this should only print, not exit
        print("Alert dismissed")
    }
    .environment(\.locale, .init(identifier: "es"))
}
#Preview ("VIBE"){
    BrutalistAlert(alertType: .deaf) {
        // ✅ FIXED: In preview, this should only print, not exit
        print("Alert dismissed")
    }
    .environment(\.locale, .init(identifier: "es"))
}
