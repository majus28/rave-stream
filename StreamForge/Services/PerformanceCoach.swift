import Foundation

enum PerformanceAction: String, CaseIterable {
    case lowerFps = "lower_fps"
    case reduceBitrate = "reduce_bitrate"
    case disableOverlays = "disable_overlays"
    case switchCaptureMode = "switch_capture_mode"
    case capPreviewFps = "cap_preview_fps"
    case disableUiEffects = "disable_ui_effects"

    var displayMessage: String {
        switch self {
        case .lowerFps: return "Lowering frame rate to reduce heat"
        case .reduceBitrate: return "Reducing bitrate to improve stability"
        case .disableOverlays: return "Disabling overlays to free resources"
        case .switchCaptureMode: return "Consider switching capture mode"
        case .capPreviewFps: return "Preview frame rate capped at 15 FPS"
        case .disableUiEffects: return "Non-essential UI effects disabled"
        }
    }
}

struct PerformanceWarning: Identifiable {
    let id = UUID()
    let action: PerformanceAction
    let severity: WarningSeverity
    let timestamp: Date

    enum WarningSeverity {
        case info, warning, critical
    }
}

final class PerformanceCoach: ObservableObject {
    @Published var activeWarnings: [PerformanceWarning] = []
    @Published var actionsTaken: [PerformanceAction] = []
    @Published var isAdaptiveActive: Bool = false

    let deviceTier: DeviceTier

    private var lastThermalState: ThermalState = .nominal
    private var consecutiveHighDropFrames: Int = 0

    init() {
        self.deviceTier = DeviceTier.detect()
    }

    func evaluate(
        thermalState: ThermalState,
        droppedFrames: Int,
        currentBitrate: Int,
        currentFps: StreamFPS,
        overlayCount: Int
    ) -> [PerformanceAction] {
        var actions: [PerformanceAction] = []

        // Thermal-based adaptations
        switch thermalState {
        case .serious:
            if currentFps == .fps60 {
                actions.append(.lowerFps)
            }
            actions.append(.capPreviewFps)
            actions.append(.disableUiEffects)
            addWarning(.capPreviewFps, severity: .warning)

        case .critical:
            if currentFps == .fps60 {
                actions.append(.lowerFps)
            }
            actions.append(.reduceBitrate)
            if overlayCount > 0 {
                actions.append(.disableOverlays)
            }
            actions.append(.capPreviewFps)
            actions.append(.disableUiEffects)
            addWarning(.reduceBitrate, severity: .critical)

        case .nominal, .fair:
            break
        }

        // Dropped frame adaptations (droppedFrames is now a per-interval delta)
        if droppedFrames > 5 {
            consecutiveHighDropFrames += 1
            if consecutiveHighDropFrames >= 2 {
                // 2 consecutive intervals with >5 drops — reduce bitrate
                actions.append(.reduceBitrate)
                if currentFps == .fps60 {
                    actions.append(.lowerFps)
                }
                addWarning(.reduceBitrate, severity: .warning)
            }
        } else {
            // Reset counter when drops are low
            if consecutiveHighDropFrames > 0 {
                consecutiveHighDropFrames -= 1  // Gradual cooldown
            }
        }

        // Device tier enforcement
        if currentFps == .fps60 && (deviceTier == .low || deviceTier == .mid) {
            actions.append(.lowerFps)
        }

        actionsTaken = actions
        isAdaptiveActive = !actions.isEmpty
        lastThermalState = thermalState

        return actions
    }

    func suggestedBitrate(current: Int, thermalState: ThermalState) -> Int {
        switch thermalState {
        case .nominal: return current
        case .fair: return current
        case .serious: return max(deviceTier.bitrateFloorKbps, Int(Double(current) * 0.75))
        case .critical: return max(deviceTier.bitrateFloorKbps, Int(Double(current) * 0.5))
        }
    }

    func suggestedFps(current: StreamFPS, thermalState: ThermalState) -> StreamFPS {
        if thermalState == .serious || thermalState == .critical {
            return .fps30
        }
        return deviceTier.clampFps(current)
    }

    func reset() {
        activeWarnings.removeAll()
        actionsTaken.removeAll()
        isAdaptiveActive = false
        consecutiveHighDropFrames = 0
    }

    private func addWarning(_ action: PerformanceAction, severity: PerformanceWarning.WarningSeverity) {
        let warning = PerformanceWarning(action: action, severity: severity, timestamp: Date())
        activeWarnings.append(warning)

        // Keep only last 10 warnings
        if activeWarnings.count > 10 {
            activeWarnings.removeFirst()
        }
    }
}
