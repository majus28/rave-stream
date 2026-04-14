import Foundation
import Combine

final class LiveControlViewModel: ObservableObject {
    @Published var isMicMuted: Bool = false
    @Published var isPaused: Bool = false
    @Published var showStopConfirmation: Bool = false

    let streamingService: StreamingService
    let captureService: CaptureService
    let performanceMonitor: PerformanceMonitor

    init(
        streamingService: StreamingService,
        captureService: CaptureService,
        performanceMonitor: PerformanceMonitor
    ) {
        self.streamingService = streamingService
        self.captureService = captureService
        self.performanceMonitor = performanceMonitor
    }

    var currentSession: StreamSession? {
        streamingService.currentSession
    }

    var formattedDuration: String {
        let total = Int(performanceMonitor.streamDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func toggleMic() {
        isMicMuted.toggle()
        let muted = isMicMuted
        Task { @MainActor in
            streamingService.setMicMuted(muted)
        }
    }

    func togglePause() {
        isPaused.toggle()
        // Pause not supported in broadcast extension mode — BRB screen is the alternative
    }

    func stopStream() async {
        await streamingService.stopStream()
    }
}
