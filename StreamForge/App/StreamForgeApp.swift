import SwiftUI

@main
struct StreamForgeApp: App {
    @StateObject private var deps = AppDependencies()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ContentRootView(deps: deps, showSplash: $showSplash)
                .onAppear {
                    deps.authService.loadIfNeeded()
                    deps.destinationService.loadIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showSplash = false
                    }
                }
        }
    }
}

struct ContentRootView: View {
    @ObservedObject var deps: AppDependencies
    @ObservedObject var authService: AuthService
    @Binding var showSplash: Bool

    init(deps: AppDependencies, showSplash: Binding<Bool>) {
        self.deps = deps
        self.authService = deps.authService
        self._showSplash = showSplash
    }

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if !authService.isAuthenticated {
                LoginView(viewModel: deps.makeAuthViewModel())
                    .transition(.opacity)
            } else {
                MainTabView()
                    .environmentObject(deps)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
    }
}
