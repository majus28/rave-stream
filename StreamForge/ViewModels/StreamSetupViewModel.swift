import Foundation

final class StreamSetupViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var selectedDestinationIds: Set<UUID> = []
    @Published var captureMode: CaptureMode = .screen
    @Published var resolution: StreamResolution = .hd720p
    @Published var fps: StreamFPS = .fps30
    @Published var bitrate: Int = 2500
    @Published var orientation: StreamOrientation = .portrait
    @Published var selectedPreset: StreamPreset = .balanced

    let destinationService: DestinationService
    let streamingService: StreamingService

    static let maxDestinations = 3

    init(destinationService: DestinationService, streamingService: StreamingService) {
        self.destinationService = destinationService
        self.streamingService = streamingService
    }

    var availableDestinations: [Destination] {
        destinationService.destinations
    }

    var canStartStream: Bool {
        !selectedDestinationIds.isEmpty
    }

    var isMultistream: Bool {
        selectedDestinationIds.count > 1
    }

    func toggleDestination(_ id: UUID) {
        if selectedDestinationIds.contains(id) {
            selectedDestinationIds.remove(id)
        } else {
            // Single destination only — multistream requires backend relay
            selectedDestinationIds = [id]
        }
    }

    func applyPreset(_ preset: StreamPreset) {
        selectedPreset = preset
        resolution = preset.resolution
        fps = preset.fps
        bitrate = preset.bitrateKbps
    }

    func createAndStartStream() async {
        let destIds = Array(selectedDestinationIds)
        _ = streamingService.createSession(
            title: title,
            description: description,
            destinationIds: destIds,
            captureMode: captureMode,
            resolution: resolution,
            fps: fps,
            bitrate: bitrate,
            orientation: orientation
        )

        await streamingService.startStream()
    }
}
