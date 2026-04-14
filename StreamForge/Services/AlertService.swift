import Foundation
import Combine

final class AlertService: ObservableObject {
    @Published var activeAlert: AlertEvent?
    @Published var recentAlerts: [AlertEvent] = []
    @Published var configuration = AlertConfiguration()
    @Published var widgets: [StreamWidget] = []

    private var alertQueue: [AlertEvent] = []
    private var displayTimer: Timer?
    private var isDisplaying: Bool = false

    static let maxWidgets = 2

    func enqueueAlert(_ event: AlertEvent) {
        guard configuration.isEnabled(event.type) else { return }

        recentAlerts.insert(event, at: 0)
        if recentAlerts.count > 50 {
            recentAlerts.removeLast()
        }

        alertQueue.append(event)
        processQueue()
    }

    func addWidget(type: WidgetType, url: String? = nil) {
        guard widgets.count < Self.maxWidgets else { return }
        let widget = StreamWidget(type: type, url: url)
        widgets.append(widget)
    }

    func removeWidget(id: UUID) {
        widgets.removeAll { $0.id == id }
    }

    func toggleWidget(id: UUID) {
        if let index = widgets.firstIndex(where: { $0.id == id }) {
            widgets[index].isEnabled.toggle()
        }
    }

    func updateConfiguration(_ config: AlertConfiguration) {
        configuration = config
    }

    func dismissCurrentAlert() {
        displayTimer?.invalidate()
        activeAlert = nil
        isDisplaying = false
        processQueue()
    }

    func clearAlerts() {
        alertQueue.removeAll()
        activeAlert = nil
        isDisplaying = false
        displayTimer?.invalidate()
    }

    // MARK: - Preview

    func previewAlert(type: AlertType) {
        let event = AlertEvent(
            type: type,
            username: "TestUser",
            message: "This is a preview alert!",
            amount: type == .donation ? "$5.00" : nil
        )
        enqueueAlert(event)
    }

    // MARK: - Private

    private func processQueue() {
        guard !isDisplaying, let next = alertQueue.first else { return }

        alertQueue.removeFirst()
        isDisplaying = true
        activeAlert = next

        displayTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.alertDurationSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.activeAlert = nil
            self?.isDisplaying = false
            self?.processQueue()
        }
    }
}
