import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var selectedTab: AppTab
    @EnvironmentObject var deps: AppDependencies
    @State private var showYouTubeGoLive = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // YouTube Go Live (OBS-style)
                    YouTubeGoLiveCard {
                        showYouTubeGoLive = true
                    }

                    // Quick Go Live
                    if viewModel.hasDestinations {
                        QuickGoLiveCard {
                            Task { await viewModel.quickGoLive() }
                        }
                    }

                    // Setup prompts
                    if !viewModel.hasDestinations {
                        SetupPromptCard(
                            icon: "plus.circle.fill",
                            title: "Add a Destination",
                            subtitle: "Connect Twitch, YouTube, or custom RTMP to start streaming",
                            action: { selectedTab = .destinations }
                        )
                    }

                    // New Stream
                    SetupPromptCard(
                        icon: "video.fill",
                        title: "New Stream",
                        subtitle: "Configure and start a custom stream",
                        action: { selectedTab = .stream }
                    )

                    // Recent streams placeholder
                    if !viewModel.recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Streams")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(viewModel.recentSessions) { session in
                                RecentSessionRow(session: session)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .background(Color.black)
            .navigationTitle("StreamForge")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { viewModel.refresh() }
            .sheet(isPresented: $showYouTubeGoLive) {
                YouTubeGoLiveView(
                    goLiveService: deps.youtubeGoLive,
                    streamingService: deps.streamingService,
                    performanceMonitor: deps.performanceMonitor
                )
            }
        }
    }
}

struct YouTubeGoLiveCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.red)
                        Text("YouTube Go Live")
                            .font(.title3.bold())
                    }
                    Text("Create event, stream & go live — like OBS")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
            }
            .padding(20)
            .background(Color.red.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .foregroundColor(.white)
        .padding(.horizontal)
    }
}

struct QuickGoLiveCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Go Live")
                        .font(.title3.bold())
                    Text("Start with last used settings")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .padding(20)
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(16)
        }
        .foregroundColor(.white)
        .padding(.horizontal)
    }
}

struct SetupPromptCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color(.systemGray6).opacity(0.15))
            .cornerRadius(12)
        }
        .foregroundColor(.white)
        .padding(.horizontal)
    }
}

struct RecentSessionRow: View {
    let session: StreamSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                if let start = session.startedAt {
                    Text(start, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Text(session.status.rawValue.capitalized)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(session.status == .ended ? Color.gray.opacity(0.3) : Color.red.opacity(0.3))
                .cornerRadius(6)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(10)
    }
}
