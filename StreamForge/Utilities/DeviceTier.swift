import Foundation
import UIKit

enum DeviceTier: String {
    case low
    case mid
    case high

    var maxResolution: StreamResolution {
        switch self {
        case .low: return .hd720p
        case .mid: return .hd1080p
        case .high: return .qhd1440p
        }
    }

    var maxFps: StreamFPS {
        switch self {
        case .low: return .fps30
        case .mid: return .fps30
        case .high: return .fps60
        }
    }

    var bitrateFloorKbps: Int {
        switch self {
        case .low: return 1200
        case .mid: return 1500
        case .high: return 2000
        }
    }

    var maxBitrateKbps: Int {
        switch self {
        case .low: return 2500
        case .mid: return 4000
        case .high: return 9000  // 1440p needs higher bitrate
        }
    }

    static func detect() -> DeviceTier {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let ram = ProcessInfo.processInfo.physicalMemory

        // High tier: 6+ cores and 6+ GB RAM (iPhone 13 Pro+, A15+)
        if cores >= 6 && ram >= 6 * 1024 * 1024 * 1024 {
            return .high
        }

        // Mid tier: 4+ cores and 4+ GB RAM (iPhone 11+, A13+)
        if cores >= 4 && ram >= 4 * 1024 * 1024 * 1024 {
            return .mid
        }

        return .low
    }

    func clampResolution(_ resolution: StreamResolution) -> StreamResolution {
        switch (self, resolution) {
        case (.low, .hd1080p), (.low, .qhd1440p): return .hd720p
        case (.mid, .qhd1440p): return .hd1080p
        default: return resolution
        }
    }

    func clampFps(_ fps: StreamFPS) -> StreamFPS {
        switch (self, fps) {
        case (.low, .fps60), (.mid, .fps60): return .fps30
        default: return fps
        }
    }

    /// Available FPS options for this device
    static var availableFps: [StreamFPS] {
        let tier = DeviceTier.detect()
        switch tier {
        case .low, .mid: return [.fps30]
        case .high: return [.fps30, .fps60]
        }
    }

    func clampBitrate(_ bitrate: Int) -> Int {
        return min(max(bitrate, bitrateFloorKbps), maxBitrateKbps)
    }
}
