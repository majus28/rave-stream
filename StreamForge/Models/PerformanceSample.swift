import Foundation

enum ThermalState: String, Codable {
    case nominal
    case fair
    case serious
    case critical

    var displayName: String { rawValue.capitalized }

    var isAcceptable: Bool {
        self == .nominal || self == .fair
    }

    var iconName: String {
        switch self {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "exclamationmark.thermometer"
        }
    }
}

struct PerformanceSample: Identifiable, Codable {
    let id: UUID
    var streamSessionId: UUID
    var bitrate: Int
    var droppedFrames: Int
    var reconnectCount: Int
    var thermalState: ThermalState
    var timestamp: Date

    init(
        id: UUID = UUID(),
        streamSessionId: UUID,
        bitrate: Int,
        droppedFrames: Int = 0,
        reconnectCount: Int = 0,
        thermalState: ThermalState = .nominal,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.streamSessionId = streamSessionId
        self.bitrate = bitrate
        self.droppedFrames = droppedFrames
        self.reconnectCount = reconnectCount
        self.thermalState = thermalState
        self.timestamp = timestamp
    }
}

struct PerformanceSummary {
    var averageBitrate: Int
    var totalDroppedFrames: Int
    var droppedFramePercentage: Double
    var reconnectCount: Int
    var peakThermalState: ThermalState
    var qualityScore: Int
    var topIssues: [String]
    var suggestions: [String]
}
