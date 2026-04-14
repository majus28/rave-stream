import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var defaultResolution: StreamResolution
    @Published var defaultFps: StreamFPS
    @Published var defaultOrientation: StreamOrientation
    @Published var livePriorityMode: Bool
    @Published var saveLastUsedDestination: Bool
    @Published var saveLastUsedStreamConfig: Bool
    @Published var noiseReduction: Bool

    let authService: AuthService

    private let defaults = UserDefaults.standard

    init(authService: AuthService) {
        self.authService = authService
        self.defaultResolution = StreamResolution(rawValue: defaults.string(forKey: "defaultResolution") ?? "") ?? .hd720p
        self.defaultFps = StreamFPS(rawValue: defaults.integer(forKey: "defaultFps")) ?? .fps30
        self.defaultOrientation = StreamOrientation(rawValue: defaults.string(forKey: "defaultOrientation") ?? "") ?? .portrait
        self.livePriorityMode = defaults.object(forKey: "livePriorityMode") as? Bool ?? true
        self.saveLastUsedDestination = defaults.object(forKey: "saveLastUsedDestination") as? Bool ?? true
        self.saveLastUsedStreamConfig = defaults.object(forKey: "saveLastUsedStreamConfig") as? Bool ?? true
        self.noiseReduction = defaults.object(forKey: "noiseReduction") as? Bool ?? true
    }

    func save() {
        defaults.set(defaultResolution.rawValue, forKey: "defaultResolution")
        defaults.set(defaultFps.rawValue, forKey: "defaultFps")
        defaults.set(defaultOrientation.rawValue, forKey: "defaultOrientation")
        defaults.set(livePriorityMode, forKey: "livePriorityMode")
        defaults.set(saveLastUsedDestination, forKey: "saveLastUsedDestination")
        defaults.set(saveLastUsedStreamConfig, forKey: "saveLastUsedStreamConfig")
        defaults.set(noiseReduction, forKey: "noiseReduction")
    }

    func logout() {
        authService.logout()
    }
}
