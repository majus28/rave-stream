import SwiftUI

struct LiveControlRoomView: View {
    @ObservedObject var viewModel: LiveControlViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar - status
                statusBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Stream preview
                streamPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Performance + Audio
                performanceBar
                    .padding(.horizontal)
                    .padding(.vertical, 4)

                audioBar
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                // Controls
                controlBar
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .alert("End Stream?", isPresented: $viewModel.showStopConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Stream", role: .destructive) {
                Task { await viewModel.stopStream() }
            }
        } message: {
            Text("Your stream will be stopped on all destinations.")
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                Text("LIVE")
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.15))
            .cornerRadius(8)

            // Duration
            Text(viewModel.formattedDuration)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - Stream Preview

    private var streamPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.1))

            VStack(spacing: 16) {
                // Screen capture indicator
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 52))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                if let hkManager = viewModel.streamingService.hkManager,
                   hkManager.isScreenCaptureActive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Screen Sharing Active")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }

                    Text("Your screen is being streamed")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("Starting screen capture...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Audio indicator
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .foregroundColor(viewModel.isMicMuted ? .red : .green)
                    Text(viewModel.isMicMuted ? "Mic Off" : "Mic On")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("|")
                        .foregroundColor(.gray.opacity(0.3))

                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.green)
                    Text("App Audio On")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Pause overlay
            if viewModel.isPaused {
                Color.black.opacity(0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 48))
                    Text("Stream Paused")
                        .font(.headline)
                }
                .foregroundColor(.white)
            }

            // Connection status badge
            VStack {
                Spacer()
                Text(viewModel.streamingService.connectionStatus)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding(8)
            }
        }
        .padding(.horizontal)
    }

    private var captureIcon: String {
        switch viewModel.currentSession?.captureMode {
        case .screen: return "rectangle.on.rectangle"
        case .frontCamera: return "camera.fill"
        case .rearCamera: return "camera.fill"
        case .none: return "video.fill"
        }
    }

    // MARK: - Performance Bar

    private var performanceBar: some View {
        HStack(spacing: 16) {
            PerformanceIndicator(
                icon: "arrow.up.circle",
                label: "\(viewModel.performanceMonitor.currentBitrate) Kbps",
                color: .green
            )

            PerformanceIndicator(
                icon: "drop.triangle",
                label: "\(viewModel.performanceMonitor.droppedFrames) drops",
                color: viewModel.performanceMonitor.droppedFrames > 10 ? .red : .green
            )

            PerformanceIndicator(
                icon: viewModel.performanceMonitor.thermalState.iconName,
                label: viewModel.performanceMonitor.thermalState.displayName,
                color: viewModel.performanceMonitor.thermalState.isAcceptable ? .green : .orange
            )

            PerformanceIndicator(
                icon: "wifi",
                label: viewModel.performanceMonitor.connectionHealth.displayName,
                color: connectionColor
            )
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(10)
    }

    private var connectionColor: Color {
        switch viewModel.performanceMonitor.connectionHealth {
        case .excellent, .good: return .green
        case .fair: return .yellow
        case .poor: return .red
        }
    }

    // MARK: - Audio Bar

    private var audioBar: some View {
        HStack(spacing: 12) {
            // Mic
            HStack(spacing: 6) {
                Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.caption)
                    .foregroundColor(viewModel.isMicMuted ? .red : .green)
                Text(viewModel.isMicMuted ? "Off" : "100%")
                    .font(.caption2.monospaced())
                    .foregroundColor(.white)
            }

            Spacer()

            // Network
            HStack(spacing: 4) {
                Image(systemName: "wifi")
                    .font(.caption)
                    .foregroundColor(connectionColor)
                Text(viewModel.performanceMonitor.connectionHealth.displayName)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGray6).opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 32) {
            // Mic toggle
            ControlButton(
                icon: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill",
                label: "Mic",
                isActive: !viewModel.isMicMuted,
                action: viewModel.toggleMic
            )

            // Stop stream
            ControlButton(
                icon: "stop.fill",
                label: "End",
                isActive: false,
                isDestructive: true,
                action: { viewModel.showStopConfirmation = true }
            )
        }
    }
}

struct PerformanceIndicator: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(
                        isDestructive ? Color.red.opacity(0.2) :
                            isActive ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(
                        isDestructive ? .red :
                            isActive ? .blue : .gray
                    )
                    .clipShape(Circle())

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
}
