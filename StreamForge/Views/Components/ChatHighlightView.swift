import SwiftUI

struct ChatHighlightView: View {
    @ObservedObject var chatService: ChatService

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                ForEach(chatService.highlightedMessages) { message in
                    ChatToastView(message: message)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: chatService.highlightedMessages.map(\.id))
            .padding(.bottom, 100)
        }
        .allowsHitTesting(false)
    }
}

struct ChatToastView: View {
    let message: ChatMessage

    var body: some View {
        HStack(spacing: 8) {
            // Provider badge
            Image(systemName: message.provider.iconName)
                .font(.caption)
                .foregroundColor(providerColor)

            // Username
            HStack(spacing: 2) {
                if message.isModerator {
                    Image(systemName: "shield.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                if message.isSubscriber {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                Text(message.displayName)
                    .font(.caption.bold())
                    .foregroundColor(providerColor)
            }

            // Message
            Text(message.message)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(providerColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    private var providerColor: Color {
        switch message.provider {
        case .twitch: return .purple
        case .youtube: return .red
        }
    }
}
