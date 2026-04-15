import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showText = false

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.03, blue: 0.18),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated logo
                AppLogoView(size: 120)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)

                // App name
                if showText {
                    VStack(spacing: 6) {
                        Text("StreamForge")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Go Live, Anywhere")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            withAnimation { isAnimating = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.5)) { showText = true }
            }
        }
    }
}
