import Foundation

enum WidgetType: String, Codable, CaseIterable, Identifiable {
    case alertBox = "alert_box"
    case chatBox = "chat_box"
    case eventList = "event_list"
    case goal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alertBox: return "Alert Box"
        case .chatBox: return "Chat Box"
        case .eventList: return "Event List"
        case .goal: return "Goal"
        }
    }

    var iconName: String {
        switch self {
        case .alertBox: return "bell.badge.fill"
        case .chatBox: return "bubble.left.and.bubble.right.fill"
        case .eventList: return "list.bullet.rectangle"
        case .goal: return "target"
        }
    }
}

enum AlertType: String, Codable, CaseIterable, Identifiable {
    case follow
    case subscribe
    case bits
    case donation
    case superchat
    case membership

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .follow: return "Follow"
        case .subscribe: return "Subscribe"
        case .bits: return "Bits/Cheer"
        case .donation: return "Donation"
        case .superchat: return "Super Chat"
        case .membership: return "Membership"
        }
    }

    var iconName: String {
        switch self {
        case .follow: return "person.badge.plus"
        case .subscribe: return "star.fill"
        case .bits: return "diamond.fill"
        case .donation: return "dollarsign.circle.fill"
        case .superchat: return "message.badge.fill"
        case .membership: return "person.crop.circle.badge.checkmark"
        }
    }

    var defaultColor: String {
        switch self {
        case .follow: return "blue"
        case .subscribe: return "purple"
        case .bits: return "orange"
        case .donation: return "green"
        case .superchat: return "yellow"
        case .membership: return "cyan"
        }
    }
}

struct StreamWidget: Identifiable, Codable {
    let id: UUID
    var type: WidgetType
    var url: String?
    var isEnabled: Bool
    var position: OverlayPosition
    var size: OverlaySize

    init(
        id: UUID = UUID(),
        type: WidgetType,
        url: String? = nil,
        isEnabled: Bool = true,
        position: OverlayPosition = OverlayPosition(x: 0.5, y: 0.5),
        size: OverlaySize = OverlaySize(width: 300, height: 200)
    ) {
        self.id = id
        self.type = type
        self.url = url
        self.isEnabled = isEnabled
        self.position = position
        self.size = size
    }
}

struct AlertEvent: Identifiable {
    let id = UUID()
    let type: AlertType
    let username: String
    let message: String?
    let amount: String?
    let timestamp: Date

    init(
        type: AlertType,
        username: String,
        message: String? = nil,
        amount: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.username = username
        self.message = message
        self.amount = amount
        self.timestamp = timestamp
    }
}

struct AlertConfiguration: Codable {
    var enabledTypes: Set<String>
    var alertDurationSeconds: Double
    var soundEnabled: Bool
    var customWidgetUrl: String?

    init(
        enabledTypes: Set<String> = Set(AlertType.allCases.map(\.rawValue)),
        alertDurationSeconds: Double = 5.0,
        soundEnabled: Bool = true,
        customWidgetUrl: String? = nil
    ) {
        self.enabledTypes = enabledTypes
        self.alertDurationSeconds = alertDurationSeconds
        self.soundEnabled = soundEnabled
        self.customWidgetUrl = customWidgetUrl
    }

    func isEnabled(_ type: AlertType) -> Bool {
        enabledTypes.contains(type.rawValue)
    }
}
