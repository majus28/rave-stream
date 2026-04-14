import Foundation

enum ScenePreset: String, Codable, CaseIterable {
    case talkingHead = "talking_head"
    case gaming
    case irl
    case minimal

    var displayName: String {
        switch self {
        case .talkingHead: return "Talking Head"
        case .gaming: return "Gaming"
        case .irl: return "IRL"
        case .minimal: return "Minimal"
        }
    }

    var iconName: String {
        switch self {
        case .talkingHead: return "person.crop.rectangle"
        case .gaming: return "gamecontroller"
        case .irl: return "video.fill"
        case .minimal: return "rectangle"
        }
    }
}

struct StreamScene: Identifiable, Codable {
    let id: UUID
    var streamSessionId: UUID
    var name: String
    var preset: ScenePreset
    var order: Int
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        streamSessionId: UUID,
        name: String,
        preset: ScenePreset = .minimal,
        order: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.streamSessionId = streamSessionId
        self.name = name
        self.preset = preset
        self.order = order
        self.isDefault = isDefault
    }
}
