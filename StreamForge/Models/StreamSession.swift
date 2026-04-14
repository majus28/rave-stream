import Foundation

enum CaptureMode: String, Codable, CaseIterable {
    case screen
    case frontCamera = "front_camera"
    case rearCamera = "rear_camera"

    var displayName: String {
        switch self {
        case .screen: return "Screen"
        case .frontCamera: return "Front Camera"
        case .rearCamera: return "Rear Camera"
        }
    }

    var iconName: String {
        switch self {
        case .screen: return "rectangle.on.rectangle"
        case .frontCamera: return "camera.fill"
        case .rearCamera: return "camera.fill"
        }
    }

    var supportsWebcamOverlay: Bool {
        self != .screen
    }
}

enum StreamResolution: String, Codable, CaseIterable {
    case hd720p = "720p"
    case hd1080p = "1080p"
    case qhd1440p = "1440p"

    var displayName: String { rawValue }

    var width: Int {
        switch self {
        case .hd720p: return 1280
        case .hd1080p: return 1920
        case .qhd1440p: return 2560
        }
    }

    var height: Int {
        switch self {
        case .hd720p: return 720
        case .hd1080p: return 1080
        case .qhd1440p: return 1440
        }
    }

    /// Available resolutions for this device
    static var available: [StreamResolution] {
        let tier = DeviceTier.detect()
        switch tier {
        case .low: return [.hd720p]
        case .mid: return [.hd720p, .hd1080p]
        case .high: return [.hd720p, .hd1080p, .qhd1440p]
        }
    }
}

enum StreamFPS: Int, Codable, CaseIterable {
    case fps30 = 30
    case fps60 = 60

    var displayName: String { "\(rawValue) FPS" }
}

enum StreamOrientation: String, Codable, CaseIterable {
    case portrait
    case landscape

    var displayName: String { rawValue.capitalized }
}

enum StreamStatus: String, Codable {
    case idle
    case preparing
    case live
    case reconnecting
    case ended
    case failed

    var isActive: Bool {
        self == .live || self == .reconnecting || self == .preparing
    }
}

enum StreamPreset: String, Codable, CaseIterable {
    case performance
    case balanced
    case quality

    var displayName: String { rawValue.capitalized }

    var resolution: StreamResolution {
        switch self {
        case .performance: return .hd720p
        case .balanced: return .hd720p
        case .quality: return .hd1080p
        }
    }

    var fps: StreamFPS {
        switch self {
        case .performance: return .fps30
        case .balanced: return .fps30
        case .quality: return .fps60
        }
    }

    var bitrateKbps: Int {
        switch self {
        case .performance: return 1500
        case .balanced: return 2500
        case .quality: return 4000
        }
    }
}

struct StreamSession: Identifiable, Codable {
    let id: UUID
    var userId: UUID?
    var destinationIds: [UUID]
    var primaryDestinationId: UUID
    var title: String
    var description: String
    var captureMode: CaptureMode
    var resolution: StreamResolution
    var fps: StreamFPS
    var bitrate: Int
    var orientation: StreamOrientation
    var status: StreamStatus
    var startedAt: Date?
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        destinationIds: [UUID] = [],
        primaryDestinationId: UUID = UUID(),
        title: String = "",
        description: String = "",
        captureMode: CaptureMode = .frontCamera,
        resolution: StreamResolution = .hd720p,
        fps: StreamFPS = .fps30,
        bitrate: Int = 2500,
        orientation: StreamOrientation = .portrait,
        status: StreamStatus = .idle,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.destinationIds = destinationIds
        self.primaryDestinationId = primaryDestinationId
        self.title = title
        self.description = description
        self.captureMode = captureMode
        self.resolution = resolution
        self.fps = fps
        self.bitrate = bitrate
        self.orientation = orientation
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = endedAt ?? Date()
        return end.timeIntervalSince(start)
    }
}
