import SwiftUI

/// StreamForge logo — broadcast icon with "SF" branding.
struct AppLogoView: View {
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.05, blue: 0.35),
                            Color(red: 0.05, green: 0.05, blue: 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Broadcast waves
            ForEach(1..<4, id: \.self) { i in
                Circle()
                    .trim(from: 0.35, to: 0.65)
                    .stroke(
                        Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.4 + Double(i) * 0.1),
                        lineWidth: size * 0.025
                    )
                    .frame(width: size * (0.25 + CGFloat(i) * 0.15))
                    .offset(x: -size * 0.1)
            }

            // Broadcast dot
            Circle()
                .fill(Color.red)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: -size * 0.1)
                .shadow(color: .red.opacity(0.6), radius: size * 0.05)

            // "SF" text
            Text("SF")
                .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .offset(x: size * 0.15, y: size * 0.02)

            // Play triangle accent
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.06))
                .foregroundColor(.cyan.opacity(0.8))
                .offset(x: size * 0.32, y: size * 0.28)
        }
    }
}

/// Inline logo for headers
struct AppLogoInline: View {
    var body: some View {
        HStack(spacing: 8) {
            AppLogoView(size: 36)
            Text("StreamForge")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
