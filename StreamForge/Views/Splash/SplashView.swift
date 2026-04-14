import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showMain = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 64))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

                Text("StreamForge")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Go Live, Anywhere")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showMain = true }
            }
        }
    }
}
