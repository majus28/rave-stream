import Foundation
import Combine

final class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var highlightedMessages: [ChatMessage] = []
    @Published var isConnected: [ChatProvider: Bool] = [:]
    @Published var viewerCount: [ChatProvider: Int] = [:]

    private var connections: [ChatProvider: ChatProviderConnection] = [:]
    private var highlightTimer: Timer?

    static let maxMessages = 200
    static let maxHighlightsOnScreen = 2

    func connect(provider: ChatProvider, channelId: String, accessToken: String) async throws {
        let connection = ChatProviderConnection(
            provider: provider,
            channelId: channelId,
            accessToken: accessToken
        )

        connection.onMessage = { [weak self] message in
            DispatchQueue.main.async {
                self?.handleMessage(message)
            }
        }

        connection.onViewerCount = { [weak self] count in
            DispatchQueue.main.async {
                self?.viewerCount[provider] = count
            }
        }

        try await connection.connect()
        connections[provider] = connection
        isConnected[provider] = true
    }

    func disconnect(provider: ChatProvider) {
        connections[provider]?.disconnect()
        connections.removeValue(forKey: provider)
        isConnected[provider] = false
    }

    func disconnectAll() {
        for (provider, _) in connections {
            disconnect(provider: provider)
        }
    }

    func startHighlightRotation() {
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.rotateHighlights()
            }
        }
    }

    func stopHighlightRotation() {
        highlightTimer?.invalidate()
        highlightTimer = nil
        highlightedMessages.removeAll()
    }

    // MARK: - Private

    private func handleMessage(_ message: ChatMessage) {
        messages.insert(message, at: 0)
        if messages.count > Self.maxMessages {
            messages.removeLast()
        }

        // Auto-highlight certain messages
        if message.isHighlighted || message.isModerator {
            addHighlight(message)
        }
    }

    private func addHighlight(_ message: ChatMessage) {
        highlightedMessages.insert(message, at: 0)
        if highlightedMessages.count > Self.maxHighlightsOnScreen {
            highlightedMessages.removeLast()
        }

        // Auto-dismiss after 8 seconds
        let messageId = message.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.highlightedMessages.removeAll { $0.id == messageId }
        }
    }

    private func rotateHighlights() {
        // Promote interesting recent messages to highlights
        guard highlightedMessages.count < Self.maxHighlightsOnScreen else { return }

        let candidates = messages.prefix(20).filter { msg in
            !highlightedMessages.contains(where: { $0.id == msg.id })
                && (msg.isSubscriber || msg.message.count > 50)
        }

        if let pick = candidates.first {
            addHighlight(pick)
        }
    }
}

// MARK: - Chat Provider Connection

final class ChatProviderConnection {
    let provider: ChatProvider
    let channelId: String
    let accessToken: String

    var onMessage: ((ChatMessage) -> Void)?
    var onViewerCount: ((Int) -> Void)?

    private var isActive = false

    init(provider: ChatProvider, channelId: String, accessToken: String) {
        self.provider = provider
        self.channelId = channelId
        self.accessToken = accessToken
    }

    func connect() async throws {
        switch provider {
        case .twitch:
            try await connectTwitch()
        case .youtube:
            try await connectYouTube()
        }
        isActive = true
    }

    func disconnect() {
        isActive = false
        // Close WebSocket/polling connections
    }

    // MARK: - Twitch IRC/WebSocket

    private func connectTwitch() async throws {
        // Twitch chat uses IRC over WebSocket at wss://irc-ws.chat.twitch.tv:443
        // Steps:
        // 1. Connect to WebSocket
        // 2. Send PASS oauth:<token>
        // 3. Send NICK <username>
        // 4. Send JOIN #<channel>
        // 5. Parse PRIVMSG for chat messages
        // Placeholder - actual implementation would use URLSessionWebSocketTask
    }

    // MARK: - YouTube Live Chat API

    private func connectYouTube() async throws {
        // YouTube Live Chat API uses polling:
        // 1. Get liveChatId from broadcast
        // 2. Poll GET /youtube/v3/liveChat/messages?liveChatId=<id>
        // 3. Parse LiveChatMessage items
        // Placeholder - actual implementation would use URLSession
    }
}
