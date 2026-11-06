import SwiftUI

struct InterludeGameOne: View {
    @State private var titleOpacity: Double = 0
    @State private var underlineWidth: CGFloat = 0
    @State private var subtitleOffset: CGFloat = 50
    @State private var noiseOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated noise background effect
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.05, green: 0.05, blue: 0.05),
                                Color.black
                            ],
                            center: UnitPoint(x: 0.3 + sin(noiseOffset) * 0.2, y: 0.7 + cos(noiseOffset * 0.8) * 0.2),
                            startRadius: 50,
                            endRadius: 400
                        )
                    )
                    .ignoresSafeArea()
                    .onAppear {
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            noiseOffset = .pi * 4
                        }
                    }
                
                // Subtle scanline effect
                VStack(spacing: 2) {
                    ForEach(0..<Int(geometry.size.height/4), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white)
                            .frame(height: 1)
                            .opacity(0.02)
                    }
                }
                
                VStack(spacing: 40) {
                    // Main challenge text - brutalist typography with animations
                    VStack(spacing: 16) {
                        Text("CHALLENGE #1")
                            .font(.system(size: min(geometry.size.width * 0.12, 80), weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(8)
                            .textCase(.uppercase)
                            .opacity(titleOpacity)
                            .scaleEffect(titleOpacity)
                        
                        // Animated underline
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: underlineWidth, height: 6)
                            .animation(.easeOut(duration: 0.8).delay(0.5), value: underlineWidth)
                    }
                    
                    // Subtitle with brutalist styling and slide-in animation
                    VStack(spacing: 20) {
                        Text("THE FUSES HAVE BLOWN")
                            .font(.system(size: min(geometry.size.width * 0.04, 28), weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(4)
                            .textCase(.uppercase)
                            .offset(y: subtitleOffset)
                            .opacity(subtitleOffset == 0 ? 1 : 0)
                        
                        Text("REPAIR THE ELECTRICAL SYSTEM TO ESCAPE")
                            .font(.system(size: min(geometry.size.width * 0.025, 18), weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(2)
                            .multilineTextAlignment(.center)
                            .opacity(subtitleOffset == 0 ? 0.9 : 0)
                            .offset(y: subtitleOffset + 20)
                    }
                }
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            // Staggered text animations
            withAnimation(.easeOut(duration: 1.0)) {
                titleOpacity = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                underlineWidth = min(UIScreen.main.bounds.width * 0.6, 600)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.8)) {
                    subtitleOffset = 0
                }
            }
        }
    }
}

#Preview {
    InterludeGameOne()
}
