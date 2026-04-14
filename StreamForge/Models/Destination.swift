import Foundation

enum DestinationType: String, Codable, CaseIterable, Identifiable {
    case twitch
    case youtube
    case customRTMP = "custom_rtmp"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twitch: return "Twitch"
        case .youtube: return "YouTube"
        case .customRTMP: return "Custom RTMP"
        }
    }

    var usesOAuth: Bool {
        switch self {
        case .twitch, .youtube: return true
        case .customRTMP: return false
        }
    }

    var rtmpUrlEditable: Bool {
        self == .customRTMP
    }

    var streamKeyEditable: Bool {
        true
    }

    var defaultIngestUrl: String {
        switch self {
        case .twitch: return "rtmp://live.twitch.tv/app"
        case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
        case .customRTMP: return ""
        }
    }

    var defaultTestStreamKey: String {
        switch self {
        case .youtube: return "m85w-bpuv-hdm1-1k72-dxz2"
        default: return ""
        }
    }

    var iconName: String {
        switch self {
        case .twitch: return "gamecontroller.fill"
        case .youtube: return "play.rectangle.fill"
        case .customRTMP: return "server.rack"
        }
    }
}

enum StreamProtocol: String, Codable, CaseIterable {
    case rtmp
    case rtmps
    case srt

    var isSupported: Bool {
        self != .srt
    }

    var displayName: String {
        switch self {
        case .rtmp: return "RTMP"
        case .rtmps: return "RTMPS"
        case .srt: return "SRT (coming soon)"
        }
    }
}

struct Destination: Identifiable, Codable {
    let id: UUID
    var userId: UUID?
    var type: DestinationType
    var name: String
    var rtmpUrl: String
    var streamKeyRef: String
    var streamProtocol: StreamProtocol
    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        type: DestinationType,
        name: String,
        rtmpUrl: String = "",
        streamKeyRef: String = "",
        streamProtocol: StreamProtocol = .rtmp,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.name = name
        self.rtmpUrl = rtmpUrl
        self.streamKeyRef = streamKeyRef
        self.streamProtocol = streamProtocol
        self.createdAt = createdAt
    }
}
