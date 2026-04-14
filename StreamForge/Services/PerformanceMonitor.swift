import Foundation
import Combine

final class PerformanceMonitor: ObservableObject {
    @Published var currentBitrate: Int = 0
    @Published var droppedFrames: Int = 0
    @Published var connectionHealth: ConnectionHealth = .excellent
    @Published var thermalState: ThermalState = .nominal
    @Published var reconnectAttempts: Int = 0
    @Published var streamDuration: TimeInterval = 0
    @Published var isLivePriorityMode: Bool = true
    @Published var performanceCoach = PerformanceCoach()
    @Published var currentFps: StreamFPS = .fps30

    let deviceTier: DeviceTier = DeviceTier.detect()

    private var samples: [PerformanceSample] = []
    private var timer: Timer?
    private var streamSessionId: UUID?
    private var thermalObserver: NSObjectProtocol?
    private var previousDroppedFrames: Int = 0  // For delta calculation

    enum ConnectionHealth: String {
        case excellent, good, fair, poor

        var displayName: String { rawValue.capitalized }
    }

    init() {}

    func setup() {
        observeThermalState()
    }

    func startMonitoring(sessionId: UUID) {
        streamSessionId = sessionId
        samples = []
        droppedFrames = 0
        previousDroppedFrames = 0
        reconnectAttempts = 0
        streamDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectSample()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func generateSummary() -> PerformanceSummary {
        let avgBitrate = samples.isEmpty ? 0 :
            samples.reduce(0) { $0 + $1.bitrate } / samples.count
        let totalDropped = samples.reduce(0) { $0 + $1.droppedFrames }
        let totalFrames = max(1, samples.count * 60)
        let dropPercentage = Double(totalDropped) / Double(totalFrames) * 100
        let peakThermal = samples.map(\.thermalState).max(by: { thermalOrder($0) < thermalOrder($1) }) ?? .nominal

        var issues: [String] = []
        var suggestions: [String] = []

        if dropPercentage > 2.0 {
            issues.append("Dropped frame rate above target (\(String(format: "%.1f", dropPercentage))%)")
            suggestions.append("Try lowering resolution or FPS")
        }
        if !peakThermal.isAcceptable {
            issues.append("Device reached \(peakThermal.displayName) thermal state")
            suggestions.append("Use Performance preset to reduce heat")
        }
        if reconnectAttempts > 0 {
            issues.append("\(reconnectAttempts) reconnection(s) during stream")
            suggestions.append("Check network stability before next stream")
        }

        let score = calculateQualityScore(dropPercentage: dropPercentage, peakThermal: peakThermal)

        return PerformanceSummary(
            averageBitrate: avgBitrate,
            totalDroppedFrames: totalDropped,
            droppedFramePercentage: dropPercentage,
            reconnectCount: reconnectAttempts,
            peakThermalState: peakThermal,
            qualityScore: score,
            topIssues: issues,
            suggestions: suggestions
        )
    }

    private func collectSample() {
        guard let sessionId = streamSessionId else { return }
        streamDuration += 2.0

        // Use delta (frames dropped since last sample), not cumulative total
        let dropDelta = droppedFrames - previousDroppedFrames
        previousDroppedFrames = droppedFrames

        let sample = PerformanceSample(
            streamSessionId: sessionId,
            bitrate: currentBitrate,
            droppedFrames: dropDelta,
            reconnectCount: reconnectAttempts,
            thermalState: thermalState
        )
        samples.append(sample)

        updateConnectionHealth(recentDrops: dropDelta)
        evaluatePerformance()
    }

    /// Called by StreamingService to apply adaptive bitrate changes
    var onAdaptiveBitrateChange: ((Int) -> Void)?

    private func evaluatePerformance() {
        guard isLivePriorityMode else { return }

        // Use recent delta, not cumulative
        let recentDrops = droppedFrames - previousDroppedFrames

        let actions = performanceCoach.evaluate(
            thermalState: thermalState,
            droppedFrames: recentDrops,
            currentBitrate: currentBitrate,
            currentFps: currentFps,
            overlayCount: 0
        )

        // Apply adaptive bitrate reduction
        if actions.contains(.reduceBitrate) && currentBitrate > 0 {
            let newBitrate = performanceCoach.suggestedBitrate(current: currentBitrate, thermalState: thermalState)
            if newBitrate < currentBitrate {
                StreamLogger.log(.perf, "Adaptive: reducing bitrate \(currentBitrate) → \(newBitrate) kbps")
                onAdaptiveBitrateChange?(newBitrate)
            }
        }
    }

    private func updateConnectionHealth(recentDrops: Int) {
        // Use recent interval drops, not cumulative total
        if recentDrops == 0 && currentBitrate > 2000 {
            connectionHealth = .excellent
        } else if recentDrops < 3 {
            connectionHealth = .good
        } else if recentDrops < 10 {
            connectionHealth = .fair
        } else {
            connectionHealth = .poor
        }
    }

    private func observeThermalState() {
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateThermalState()
            }
        }
        updateThermalState()
    }

    private func updateThermalState() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = .nominal
        case .fair: thermalState = .fair
        case .serious: thermalState = .serious
        case .critical: thermalState = .critical
        @unknown default: thermalState = .nominal
        }
    }

    private func thermalOrder(_ state: ThermalState) -> Int {
        switch state {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }

    private func calculateQualityScore(dropPercentage: Double, peakThermal: ThermalState) -> Int {
        var score = 100
        score -= Int(dropPercentage * 10)
        score -= reconnectAttempts * 5

        switch peakThermal {
        case .nominal: break
        case .fair: score -= 5
        case .serious: score -= 15
        case .critical: score -= 30
        }

        return max(0, min(100, score))
    }

    deinit {
        if let observer = thermalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
