import Foundation

enum ChatProvider: String, Codable, CaseIterable, Identifiable {
    case twitch
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twitch: return "Twitch"
        case .youtube: return "YouTube"
        }
    }

    var iconName: String {
        switch self {
        case .twitch: return "gamecontroller.fill"
        case .youtube: return "play.rectangle.fill"
        }
    }

    var color: String {
        switch self {
        case .twitch: return "purple"
        case .youtube: return "red"
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let provider: ChatProvider
    let username: String
    let displayName: String
    let message: String
    let timestamp: Date
    let isModerator: Bool
    let isSubscriber: Bool
    let isHighlighted: Bool
    let emotes: [String]

    init(
        provider: ChatProvider,
        username: String,
        displayName: String? = nil,
        message: String,
        timestamp: Date = Date(),
        isModerator: Bool = false,
        isSubscriber: Bool = false,
        isHighlighted: Bool = false,
        emotes: [String] = []
    ) {
        self.provider = provider
        self.username = username
        self.displayName = displayName ?? username
        self.message = message
        self.timestamp = timestamp
        self.isModerator = isModerator
        self.isSubscriber = isSubscriber
        self.isHighlighted = isHighlighted
        self.emotes = emotes
    }
}
