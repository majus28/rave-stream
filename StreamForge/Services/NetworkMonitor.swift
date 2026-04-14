import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .wifi
    @Published var isDisconnectProtectionActive: Bool = false
    @Published var disconnectHoldRemaining: TimeInterval = 0

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.streamforge.networkmonitor")
    private var disconnectTimer: Timer?
    private var holdStartTime: Date?

    static let maxHoldSeconds: TimeInterval = 120

    enum ConnectionType: String {
        case wifi, cellular, wired, unknown

        var displayName: String { rawValue.capitalized }

        var iconName: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    var onDisconnect: (() -> Void)?
    var onReconnect: (() -> Void)?
    var onProtectionExpired: (() -> Void)?

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }

                // Detect transitions
                if wasConnected && path.status != .satisfied {
                    self?.handleDisconnect()
                } else if !wasConnected && path.status == .satisfied {
                    self?.handleReconnect()
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
        cancelDisconnectProtection()
    }

    // MARK: - Disconnect Protection

    func activateDisconnectProtection() {
        guard !isDisconnectProtectionActive else { return }

        isDisconnectProtectionActive = true
        holdStartTime = Date()
        disconnectHoldRemaining = Self.maxHoldSeconds

        disconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.holdStartTime else { return }

            let elapsed = Date().timeIntervalSince(start)
            self.disconnectHoldRemaining = max(0, Self.maxHoldSeconds - elapsed)

            if elapsed >= Self.maxHoldSeconds {
                self.cancelDisconnectProtection()
                self.onProtectionExpired?()
            }
        }
    }

    func cancelDisconnectProtection() {
        disconnectTimer?.invalidate()
        disconnectTimer = nil
        isDisconnectProtectionActive = false
        disconnectHoldRemaining = 0
        holdStartTime = nil
    }

    // MARK: - Private

    private func handleDisconnect() {
        onDisconnect?()
        activateDisconnectProtection()
    }

    private func handleReconnect() {
        cancelDisconnectProtection()
        onReconnect?()
    }

    deinit {
        monitor.cancel()
        disconnectTimer?.invalidate()
    }
}
