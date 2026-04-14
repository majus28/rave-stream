import Foundation

final class DestinationsViewModel: ObservableObject {
    @Published var showAddSheet: Bool = false
    @Published var editingDestination: Destination?

    // New destination form fields
    @Published var newName: String = ""
    @Published var newType: DestinationType = .twitch
    @Published var newRtmpUrl: String = ""
    @Published var newStreamKey: String = ""
    @Published var newProtocol: StreamProtocol = .rtmp

    let destinationService: DestinationService

    init(destinationService: DestinationService) {
        self.destinationService = destinationService
    }

    var destinations: [Destination] {
        destinationService.destinations
    }

    func addDestination() {
        // Use default ingest URL for Twitch/YouTube if not manually set
        let rtmpUrl = newRtmpUrl.isEmpty ? newType.defaultIngestUrl : newRtmpUrl

        let destId = UUID()
        let destination = Destination(
            id: destId,
            type: newType,
            name: newName.isEmpty ? newType.displayName : newName,
            rtmpUrl: rtmpUrl,
            streamKeyRef: newStreamKey.isEmpty ? "" : "streamKey_\(destId.uuidString)",
            streamProtocol: newProtocol
        )

        if !newStreamKey.isEmpty {
            destinationService.saveStreamKey(newStreamKey, for: destId)
        }

        destinationService.addDestination(destination)
        resetForm()
        showAddSheet = false
    }

    func deleteDestination(id: UUID) {
        destinationService.deleteDestination(id: id)
    }

    func resetForm() {
        newName = ""
        newType = .twitch
        newRtmpUrl = ""
        newStreamKey = ""
        newProtocol = .rtmp
    }
}
