import SwiftUI

enum AppTab: String, CaseIterable {
    case home
    case destinations
    case stream
    case settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .destinations: return "Destinations"
        case .stream: return "Stream"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .destinations: return "antenna.radiowaves.left.and.right"
        case .stream: return "video.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var deps: AppDependencies
    @State private var selectedTab: AppTab = .home
    @State private var showLiveControl = false
    @State private var showStreamSummary = false

    // Create ViewModels once
    @State private var homeVM: HomeViewModel?
    @State private var destinationsVM: DestinationsViewModel?
    @State private var streamSetupVM: StreamSetupViewModel?
    @State private var settingsVM: SettingsViewModel?

    var body: some View {
        MainTabContent(
            deps: deps,
            selectedTab: $selectedTab,
            showLiveControl: $showLiveControl,
            showStreamSummary: $showStreamSummary,
            homeVM: homeVM ?? deps.makeHomeViewModel(),
            destinationsVM: destinationsVM ?? deps.makeDestinationsViewModel(),
            streamSetupVM: streamSetupVM ?? deps.makeStreamSetupViewModel(),
            settingsVM: settingsVM ?? deps.makeSettingsViewModel()
        )
        .onAppear {
            if homeVM == nil {
                homeVM = deps.makeHomeViewModel()
                destinationsVM = deps.makeDestinationsViewModel()
                streamSetupVM = deps.makeStreamSetupViewModel()
                settingsVM = deps.makeSettingsViewModel()
            }
        }
    }
}

private struct MainTabContent: View {
    @ObservedObject var deps: AppDependencies
    @ObservedObject var streamingService: StreamingService
    @Binding var selectedTab: AppTab
    @Binding var showLiveControl: Bool
    @Binding var showStreamSummary: Bool

    let homeVM: HomeViewModel
    let destinationsVM: DestinationsViewModel
    let streamSetupVM: StreamSetupViewModel
    let settingsVM: SettingsViewModel

    init(
        deps: AppDependencies,
        selectedTab: Binding<AppTab>,
        showLiveControl: Binding<Bool>,
        showStreamSummary: Binding<Bool>,
        homeVM: HomeViewModel,
        destinationsVM: DestinationsViewModel,
        streamSetupVM: StreamSetupViewModel,
        settingsVM: SettingsViewModel
    ) {
        self.deps = deps
        self.streamingService = deps.streamingService
        self._selectedTab = selectedTab
        self._showLiveControl = showLiveControl
        self._showStreamSummary = showStreamSummary
        self.homeVM = homeVM
        self.destinationsVM = destinationsVM
        self.streamSetupVM = streamSetupVM
        self.settingsVM = settingsVM
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeVM, selectedTab: $selectedTab)
                .tabItem {
                    Label(AppTab.home.title, systemImage: AppTab.home.icon)
                }
                .tag(AppTab.home)

            DestinationsView(viewModel: destinationsVM)
                .tabItem {
                    Label(AppTab.destinations.title, systemImage: AppTab.destinations.icon)
                }
                .tag(AppTab.destinations)

            StreamSetupView(viewModel: streamSetupVM)
                .tabItem {
                    Label(AppTab.stream.title, systemImage: AppTab.stream.icon)
                }
                .tag(AppTab.stream)

            SettingsView(viewModel: settingsVM)
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.blue)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showLiveControl) {
            LiveControlRoomView(viewModel: deps.makeLiveControlViewModel())
        }
        .onChange(of: streamingService.isStreaming) { _, isStreaming in
            showLiveControl = isStreaming
        }
        .onChange(of: showLiveControl) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                if let session = streamingService.currentSession, session.status == .ended {
                    showStreamSummary = true
                }
            }
        }
        .sheet(isPresented: $showStreamSummary) {
            if let session = streamingService.currentSession {
                StreamSummaryView(viewModel: deps.makeStreamSummaryViewModel(session: session))
            }
        }
    }
}
