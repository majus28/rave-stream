import Foundation

enum OverlayType: String, Codable, CaseIterable {
    case text
    case image
    case webcam
    case web

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .text: return "textformat"
        case .image: return "photo"
        case .webcam: return "web.camera"
        case .web: return "globe"
        }
    }
}

struct OverlayPosition: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
}

struct OverlaySize: Codable, Equatable {
    var width: CGFloat
    var height: CGFloat
}

struct Overlay: Identifiable, Codable {
    let id: UUID
    var streamSessionId: UUID
    var sceneId: UUID?
    var type: OverlayType
    var content: String
    var position: OverlayPosition
    var size: OverlaySize
    var visible: Bool

    init(
        id: UUID = UUID(),
        streamSessionId: UUID,
        sceneId: UUID? = nil,
        type: OverlayType,
        content: String = "",
        position: OverlayPosition = OverlayPosition(x: 0.5, y: 0.5),
        size: OverlaySize = OverlaySize(width: 200, height: 200),
        visible: Bool = true
    ) {
        self.id = id
        self.streamSessionId = streamSessionId
        self.sceneId = sceneId
        self.type = type
        self.content = content
        self.position = position
        self.size = size
        self.visible = visible
    }
}
