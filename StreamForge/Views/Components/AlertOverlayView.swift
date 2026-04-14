import SwiftUI

struct AlertOverlayView: View {
    @ObservedObject var alertService: AlertService

    var body: some View {
        VStack {
            if let alert = alertService.activeAlert {
                AlertBannerView(event: alert)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .onTapGesture {
                        alertService.dismissCurrentAlert()
                    }
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: alertService.activeAlert?.id)
        .allowsHitTesting(alertService.activeAlert != nil)
    }
}

struct AlertBannerView: View {
    let event: AlertEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.iconName)
                .font(.title2)
                .foregroundColor(alertColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(event.type.displayName)
                        .font(.caption.bold())
                        .foregroundColor(alertColor)

                    if let amount = event.amount {
                        Text(amount)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }

                Text(event.username)
                    .font(.headline)
                    .foregroundColor(.white)

                if let message = event.message {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(alertColor.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var alertColor: Color {
        switch event.type {
        case .follow: return .blue
        case .subscribe: return .purple
        case .bits: return .orange
        case .donation: return .green
        case .superchat: return .yellow
        case .membership: return .cyan
        }
    }
}

struct AlertPreviewView: View {
    @ObservedObject var alertService: AlertService

    var body: some View {
        VStack(spacing: 16) {
            Text("Alert Preview")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(AlertType.allCases) { type in
                    Button {
                        alertService.previewAlert(type: type)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.iconName)
                                .font(.title3)
                            Text(type.displayName)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6).opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
}
