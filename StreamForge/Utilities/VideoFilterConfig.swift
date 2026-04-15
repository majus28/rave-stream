import Foundation

/// Video color filter presets — shared between app and broadcast extension via App Group.
enum VideoFilter: String, Codable, CaseIterable, Identifiable {
    case none
    case vivid
    case warm
    case cool
    case noir
    case vintage
    case cyberpunk
    case dramatic
    case pastel
    case highContrast
    case sepia
    case neon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .vivid: return "Vivid"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .noir: return "Noir"
        case .vintage: return "Vintage"
        case .cyberpunk: return "Cyberpunk"
        case .dramatic: return "Dramatic"
        case .pastel: return "Pastel"
        case .highContrast: return "High Contrast"
        case .sepia: return "Sepia"
        case .neon: return "Neon"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .vivid: return "sun.max.fill"
        case .warm: return "flame.fill"
        case .cool: return "snowflake"
        case .noir: return "moon.fill"
        case .vintage: return "camera.filters"
        case .cyberpunk: return "bolt.fill"
        case .dramatic: return "theatermasks.fill"
        case .pastel: return "paintpalette.fill"
        case .highContrast: return "circle.lefthalf.filled"
        case .sepia: return "photo.artframe"
        case .neon: return "lightbulb.fill"
        }
    }

    /// CIFilter parameters for this preset
    var filterParams: FilterParams {
        switch self {
        case .none:
            return FilterParams()
        case .vivid:
            return FilterParams(saturation: 1.5, contrast: 1.1, brightness: 0.02)
        case .warm:
            return FilterParams(saturation: 1.1, temperature: 7000, tint: 10)
        case .cool:
            return FilterParams(saturation: 1.05, temperature: 4500, tint: -10)
        case .noir:
            return FilterParams(saturation: 0, contrast: 1.4, brightness: -0.05)
        case .vintage:
            return FilterParams(saturation: 0.7, contrast: 0.9, sepia: 0.3)
        case .cyberpunk:
            return FilterParams(saturation: 1.6, contrast: 1.3, brightness: -0.03, temperature: 5500, tint: 30)
        case .dramatic:
            return FilterParams(saturation: 0.8, contrast: 1.5, brightness: -0.05, vignette: 0.5)
        case .pastel:
            return FilterParams(saturation: 0.6, contrast: 0.8, brightness: 0.1)
        case .highContrast:
            return FilterParams(contrast: 1.6, brightness: -0.02)
        case .sepia:
            return FilterParams(sepia: 0.8)
        case .neon:
            return FilterParams(saturation: 2.0, contrast: 1.2, brightness: 0.05)
        }
    }
}

/// Individual filter parameters — all CIFilter-based
struct FilterParams: Codable {
    var saturation: Float = 1.0
    var contrast: Float = 1.0
    var brightness: Float = 0.0
    var temperature: Float = 6500 // Kelvin (neutral)
    var tint: Float = 0
    var sepia: Float = 0
    var vignette: Float = 0

    var isIdentity: Bool {
        saturation == 1.0 && contrast == 1.0 && brightness == 0.0 &&
        temperature == 6500 && tint == 0 && sepia == 0 && vignette == 0
    }
}

/// Persistence via App Group
enum VideoFilterStore {
    static let appGroupId = "group.com.majuz.streamforge"

    static func save(_ filter: VideoFilter) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(filter.rawValue, forKey: "video_filter")
        if let data = try? JSONEncoder().encode(filter.filterParams) {
            defaults.set(data, forKey: "video_filter_params")
        }
        defaults.synchronize()
    }

    static func saveCustomParams(_ params: FilterParams) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(params) else { return }
        defaults.set("custom", forKey: "video_filter")
        defaults.set(data, forKey: "video_filter_params")
        defaults.synchronize()
    }

    static func load() -> (filter: VideoFilter, params: FilterParams) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return (.none, FilterParams()) }
        let name = defaults.string(forKey: "video_filter") ?? "none"
        let filter = VideoFilter(rawValue: name) ?? .none

        if let data = defaults.data(forKey: "video_filter_params"),
           let params = try? JSONDecoder().decode(FilterParams.self, from: data) {
            return (filter, params)
        }
        return (filter, filter.filterParams)
    }
}
