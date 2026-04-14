import Foundation
import SwiftUI

final class AppDependencies: ObservableObject {
    let authService = AuthService()
    let destinationService = DestinationService()
    let performanceMonitor = PerformanceMonitor()
    let captureService = CaptureService()
    let audioService = AudioService()
    let alertService = AlertService()
    let chatService = ChatService()
    let networkMonitor = NetworkMonitor()
    let recordingService = RecordingService()
    let ttsService = TTSService()
    lazy var streamingService: StreamingService = {
        StreamingService(
            performanceMonitor: performanceMonitor,
            destinationService: destinationService,
            captureService: captureService
        )
    }()

    // YouTube Live API
    lazy var youtubeOAuth = YouTubeOAuth(
        clientId: "81118022282-eglkdokqs8qme2rkin5uda6laijp28kc.apps.googleusercontent.com",
        redirectUri: "com.googleusercontent.apps.81118022282-eglkdokqs8qme2rkin5uda6laijp28kc:/oauth2redirect"
    )
    lazy var youtubeGoLive = YouTubeGoLiveService(oauth: youtubeOAuth)

    init() {
        performanceMonitor.setup()
    }

    // MARK: - ViewModel Factories

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authService: authService)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            authService: authService,
            destinationService: destinationService,
            streamingService: streamingService
        )
    }

    func makeDestinationsViewModel() -> DestinationsViewModel {
        DestinationsViewModel(destinationService: destinationService)
    }

    func makeStreamSetupViewModel() -> StreamSetupViewModel {
        StreamSetupViewModel(
            destinationService: destinationService,
            streamingService: streamingService
        )
    }

    func makeLiveControlViewModel() -> LiveControlViewModel {
        LiveControlViewModel(
            streamingService: streamingService,
            captureService: captureService,
            performanceMonitor: performanceMonitor
        )
    }

    func makeOverlayEditorViewModel(sessionId: UUID) -> OverlayEditorViewModel {
        OverlayEditorViewModel(streamSessionId: sessionId)
    }

    func makeStreamSummaryViewModel(session: StreamSession) -> StreamSummaryViewModel {
        StreamSummaryViewModel(session: session, performanceMonitor: performanceMonitor)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(authService: authService)
    }
}
