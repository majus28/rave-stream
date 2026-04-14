import Foundation

final class HomeViewModel: ObservableObject {
    @Published var recentSessions: [StreamSession] = []
    @Published var hasDestinations: Bool = false

    let authService: AuthService
    let destinationService: DestinationService
    let streamingService: StreamingService

    init(
        authService: AuthService,
        destinationService: DestinationService,
        streamingService: StreamingService
    ) {
        self.authService = authService
        self.destinationService = destinationService
        self.streamingService = streamingService
    }

    func refresh() {
        hasDestinations = !destinationService.destinations.isEmpty
    }

    func quickGoLive() async {
        guard let destination = destinationService.destinations.first else { return }

        let preset = StreamPreset.balanced
        _ = streamingService.createSession(
            title: "Live Stream",
            description: "",
            destinationIds: [destination.id],
            captureMode: .frontCamera,
            resolution: preset.resolution,
            fps: preset.fps,
            bitrate: preset.bitrateKbps,
            orientation: .portrait
        )

        await streamingService.startStream()
    }
}
