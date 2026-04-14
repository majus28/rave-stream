import Foundation
import AVFoundation
import CoreMedia
import Combine

/// Stream lifecycle manager.
/// Delegates actual streaming to HKStreamManager (HaishinKit) or Broadcast Extension.
final class StreamingService: ObservableObject {
    @Published var currentSession: StreamSession?
    @Published var isStreaming: Bool = false
    @Published var error: String?
    @Published var connectionStatus: String = ""
    @Published var droppedFrameCount: Int = 0
    @Published var currentBitrateKbps: Int = 0

    private let performanceMonitor: PerformanceMonitor
    private let destinationService: DestinationService

    /// HaishinKit-powered stream manager (in-app streaming)
    private(set) var hkManager: HKStreamManager?
    private var metricsTimer: Timer?

    init(performanceMonitor: PerformanceMonitor, destinationService: DestinationService, captureService: CaptureService) {
        self.performanceMonitor = performanceMonitor
        self.destinationService = destinationService

        // Wire adaptive bitrate — when coach recommends reduction, apply it
        performanceMonitor.onAdaptiveBitrateChange = { [weak self] newBitrate in
            guard let self else { return }
            Task { @MainActor in
                self.hkManager?.updateBitrate(newBitrate)
                if var session = self.currentSession {
                    session.bitrate = newBitrate
                    self.currentSession = session
                }
                self.currentBitrateKbps = newBitrate
                StreamLogger.log(.perf, "StreamingService: bitrate adapted to \(newBitrate) kbps")
            }
        }
    }

    func createSession(
        title: String,
        description: String,
        destinationIds: [UUID],
        captureMode: CaptureMode,
        resolution: StreamResolution,
        fps: StreamFPS,
        bitrate: Int,
        orientation: StreamOrientation
    ) -> StreamSession {
        let tier = performanceMonitor.deviceTier
        let clampedRes = tier.clampResolution(resolution)
        let clampedFps = tier.clampFps(fps)
        let clampedBitrate = tier.clampBitrate(bitrate)

        let streamTitle = title.isEmpty ? "Live Stream" : title
        let primaryId = destinationIds.first ?? UUID()
        let session = StreamSession(
            id: UUID(),
            destinationIds: destinationIds,
            primaryDestinationId: primaryId,
            title: streamTitle,
            description: description,
            captureMode: captureMode,
            resolution: clampedRes,
            fps: clampedFps,
            bitrate: clampedBitrate,
            orientation: orientation,
            status: .idle
        )
        currentSession = session
        return session
    }

    @MainActor func startStream() async {
        guard var session = currentSession else {
            error = "No session configured"
            return
        }

        session.status = .preparing
        currentSession = session
        connectionStatus = "Preparing..."
        droppedFrameCount = 0

        // Find destination
        guard let destId = session.destinationIds.first,
              let dest = destinationService.destinations.first(where: { $0.id == destId }),
              !dest.rtmpUrl.isEmpty else {
            connectionStatus = "No destination"
            session.status = .failed
            currentSession = session
            error = "No valid RTMP destination"
            return
        }

        let streamKey = destinationService.loadStreamKey(for: destId) ?? ""
        guard !streamKey.isEmpty else {
            connectionStatus = "No stream key"
            session.status = .failed
            currentSession = session
            error = "No stream key"
            return
        }

        // Start HaishinKit
        let manager = HKStreamManager()
        hkManager = manager

        connectionStatus = "Connecting..."
        await manager.startPublishing(
            url: dest.rtmpUrl,
            streamKey: streamKey,
            resolution: session.resolution,
            fps: session.fps,
            bitrate: session.bitrate,
            captureMode: session.captureMode,
            orientation: session.orientation
        )

        if manager.isPublishing {
            session.status = .live
            session.startedAt = Date()
            currentSession = session
            isStreaming = true
            connectionStatus = "Live"

            performanceMonitor.currentFps = session.fps
            performanceMonitor.startMonitoring(sessionId: session.id)
            startMetricsSync(manager)
        } else {
            session.status = .failed
            currentSession = session
            error = manager.error ?? "Failed to connect"
            connectionStatus = "Failed"
        }
    }

    @MainActor func stopStream() async {
        guard var session = currentSession else { return }

        await hkManager?.stopPublishing()
        hkManager = nil
        metricsTimer?.invalidate()
        metricsTimer = nil

        session.status = .ended
        session.endedAt = Date()
        currentSession = session
        isStreaming = false
        connectionStatus = ""

        performanceMonitor.stopMonitoring()
    }

    @MainActor func setMicMuted(_ muted: Bool) {
        hkManager?.setMicMuted(muted)
    }

    @MainActor func applyPreset(_ preset: StreamPreset) {
        guard var session = currentSession else { return }
        let tier = performanceMonitor.deviceTier
        session.resolution = tier.clampResolution(preset.resolution)
        session.fps = tier.clampFps(preset.fps)
        session.bitrate = tier.clampBitrate(preset.bitrateKbps)
        currentSession = session
        hkManager?.updateBitrate(session.bitrate)
    }

    // Legacy stubs — kept for CaptureService callback compatibility
    func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {}
    func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {}

    private func startMetricsSync(_ manager: HKStreamManager) {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self, weak manager] _ in
            guard let self = self, let manager = manager else { return }
            DispatchQueue.main.async {
                self.currentBitrateKbps = manager.currentBitrate
                self.performanceMonitor.currentBitrate = manager.currentBitrate
            }
        }
    }
}
