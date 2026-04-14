import Foundation
import UIKit

// MARK: - Scene (like OBS/StreamChamp scenes: Default, Away, BRB, Starting Soon)

struct BroadcastScene: Codable, Identifiable {
    let id: UUID
    var name: String
    var layout: SceneLayout

    init(name: String, layout: SceneLayout = .default) {
        self.id = UUID()
        self.name = name
        self.layout = layout
    }
}

struct SceneCollection: Codable {
    var scenes: [BroadcastScene]
    var activeSceneId: UUID?

    var activeScene: BroadcastScene? {
        scenes.first { $0.id == activeSceneId } ?? scenes.first
    }

    static let `default` = SceneCollection(scenes: [
        BroadcastScene(name: "Default", layout: .default),
        BroadcastScene(name: "Away", layout: SceneLayout(gameScreen: .fullScreen, overlays: [
            SceneLayout.OverlayLayer(type: .text, name: "Away", rect: .init(x: 0.2, y: 0.4, width: 0.6, height: 0.1), content: "Be right back...")
        ], canvasWidth: 1280, canvasHeight: 720)),
        BroadcastScene(name: "BRB", layout: SceneLayout(gameScreen: .init(x: 0, y: 0, width: 0, height: 0), overlays: [
            SceneLayout.OverlayLayer(type: .text, name: "BRB Text", rect: .init(x: 0.15, y: 0.35, width: 0.7, height: 0.15), content: "Be Right Back")
        ], canvasWidth: 1280, canvasHeight: 720)),
        BroadcastScene(name: "Starting Soon", layout: SceneLayout(gameScreen: .init(x: 0, y: 0, width: 0, height: 0), overlays: [
            SceneLayout.OverlayLayer(type: .text, name: "Starting Text", rect: .init(x: 0.15, y: 0.35, width: 0.7, height: 0.15), content: "Starting Soon...")
        ], canvasWidth: 1280, canvasHeight: 720)),
    ], activeSceneId: nil)
}

// MARK: - Scene Layout

struct SceneLayout: Codable {
    var gameScreen: ScreenRect
    var overlays: [OverlayLayer]
    var canvasWidth: Int
    var canvasHeight: Int

    struct ScreenRect: Codable {
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat

        static let fullScreen = ScreenRect(x: 0, y: 0, width: 1, height: 1)
    }

    enum LayerType: String, Codable, CaseIterable, Identifiable {
        case image
        case gif
        case video
        case text
        case webURL

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .image: return "Image"
            case .gif: return "GIF Animation"
            case .video: return "Video"
            case .text: return "Text"
            case .webURL: return "HTML Overlay"
            }
        }

        var icon: String {
            switch self {
            case .image: return "photo"
            case .gif: return "livephoto.play"
            case .video: return "film"
            case .text: return "textformat"
            case .webURL: return "globe"
            }
        }
    }

    enum AspectMode: String, Codable, CaseIterable {
        case fit
        case fill
        case stretch

        var displayName: String {
            switch self {
            case .fit: return "Fit"
            case .fill: return "Fill"
            case .stretch: return "Stretch"
            }
        }
    }

    struct OverlayLayer: Codable, Identifiable {
        let id: UUID
        var type: LayerType
        var name: String
        var rect: ScreenRect
        var visible: Bool
        var content: String
        var opacity: CGFloat
        var order: Int
        var aspectMode: AspectMode
        var locked: Bool
        var rotation: Double  // degrees

        init(type: LayerType, name: String, rect: ScreenRect, content: String = "",
             opacity: CGFloat = 1.0, order: Int = 0, aspectMode: AspectMode = .fill,
             locked: Bool = false, rotation: Double = 0) {
            self.id = UUID()
            self.type = type
            self.name = name
            self.rect = rect
            self.visible = true
            self.content = content
            self.opacity = opacity
            self.order = order
            self.aspectMode = aspectMode
            self.locked = locked
            self.rotation = rotation
        }
    }

    static let `default` = SceneLayout(
        gameScreen: .fullScreen,
        overlays: [],
        canvasWidth: 1280,
        canvasHeight: 720
    )

    static let gamingWithOverlays = SceneLayout(
        gameScreen: ScreenRect(x: 0, y: 0, width: 0.85, height: 0.85),
        overlays: [
            OverlayLayer(type: .text, name: "Title", rect: ScreenRect(x: 0.02, y: 0.88, width: 0.6, height: 0.1), content: "Live Stream"),
            OverlayLayer(type: .image, name: "Logo", rect: ScreenRect(x: 0.88, y: 0.02, width: 0.1, height: 0.12), order: 1),
        ],
        canvasWidth: 1280,
        canvasHeight: 720
    )
}

// MARK: - Persistence

enum SceneLayoutStore {
    static let appGroupId = "group.com.majuz.streamforge"

    // Active scene layout
    static func save(_ layout: SceneLayout) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(layout) else { return }
        defaults.set(data, forKey: "scene_layout")
        defaults.synchronize()
    }

    static func load() -> SceneLayout {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "scene_layout"),
              let layout = try? JSONDecoder().decode(SceneLayout.self, from: data) else {
            return .default
        }
        return layout
    }

    // Scene collection
    static func saveScenes(_ collection: SceneCollection) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(collection) else { return }
        defaults.set(data, forKey: "scene_collection")
        defaults.synchronize()

        // Also save the active scene's layout as the current layout
        if let active = collection.activeScene {
            save(active.layout)
        }
    }

    static func loadScenes() -> SceneCollection {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "scene_collection"),
              let collection = try? JSONDecoder().decode(SceneCollection.self, from: data) else {
            return .default
        }
        return collection
    }

    // Overlay images
    static func saveOverlayImage(_ image: UIImage, id: UUID) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        if let data = image.pngData() {
            try? data.write(to: containerURL.appendingPathComponent("overlay_\(id.uuidString).png"))
        }
    }

    static func loadOverlayImage(id: UUID) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
        guard let data = try? Data(contentsOf: containerURL.appendingPathComponent("overlay_\(id.uuidString).png")) else { return nil }
        return UIImage(data: data)
    }

    static func saveGIF(_ data: Data, id: UUID) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        try? data.write(to: containerURL.appendingPathComponent("overlay_\(id.uuidString).gif"))
    }

    static func loadGIFData(id: UUID) -> Data? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
        return try? Data(contentsOf: containerURL.appendingPathComponent("overlay_\(id.uuidString).gif"))
    }

    static func saveVideo(from sourceURL: URL, id: UUID) -> Bool {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return false }
        let destURL = containerURL.appendingPathComponent("overlay_\(id.uuidString).mp4")
        try? FileManager.default.removeItem(at: destURL)
        return (try? FileManager.default.copyItem(at: sourceURL, to: destURL)) != nil
    }

    static func videoURL(id: UUID) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
        let fileURL = containerURL.appendingPathComponent("overlay_\(id.uuidString).mp4")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}
