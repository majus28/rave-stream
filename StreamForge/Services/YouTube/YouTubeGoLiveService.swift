import Foundation
import Combine

/// YouTube Go Live — two-step flow:
/// 1. Create event (API) + save config to App Group
/// 2. User starts Broadcast Extension, then taps Go Live to poll + transition
@MainActor
final class YouTubeGoLiveService: ObservableObject {

    enum GoLiveState: Equatable {
        case idle
        case creatingEvent
        case readyToBroadcast        // Event created, waiting for user to start broadcast
        case waitingForYouTube(Int)   // Polling stream status
        case goingLive
        case live
        case error(String)
        case ended
    }

    @Published var state: GoLiveState = .idle
    @Published var broadcastId: String?
    @Published var streamId: String?
    @Published var statusMessage: String = ""

    private var api: YouTubeLiveAPI?
    var hkManager: HKStreamManager?

    let oauth: YouTubeOAuth

    nonisolated init(oauth: YouTubeOAuth) {
        self.oauth = oauth
    }

    // MARK: - Step 1: Create YouTube Event

    func createEvent(
        title: String,
        description: String = "",
        privacy: String = "unlisted",
        resolution: StreamResolution = .hd720p,
        orientation: StreamOrientation = .landscape,
        bitrate: Int = 2500,
        thumbnailData: Data? = nil
    ) async throws {
        guard let token = oauth.accessToken else {
            throw YouTubeLiveAPI.APIError.invalidResponse
        }

        let api = YouTubeLiveAPI(accessToken: token)
        self.api = api

        let resStr = resolution == .hd1080p ? "1080p" : "720p"
        let width: Int
        let height: Int
        if orientation == .landscape {
            width = resolution == .hd1080p ? 1920 : 1280
            height = resolution == .hd1080p ? 1080 : 720
        } else {
            width = resolution == .hd1080p ? 1080 : 720
            height = resolution == .hd1080p ? 1920 : 1280
        }

        state = .creatingEvent
        statusMessage = "Creating stream..."

        // Create liveStream
        let stream = try await api.createLiveStream(title: "\(title) - stream", resolution: resStr, frameRate: "30fps")
        self.streamId = stream.id
        guard let info = stream.cdn?.ingestionInfo else { throw YouTubeLiveAPI.APIError.invalidResponse }

        // Create broadcast
        statusMessage = "Creating broadcast..."
        let broadcast = try await api.createLiveBroadcast(title: title, description: description, privacyStatus: privacy, enableMonitorStream: false)
        self.broadcastId = broadcast.id

        // Upload thumbnail if provided
        if let thumbnailData = thumbnailData {
            statusMessage = "Uploading thumbnail..."
            do {
                try await api.uploadThumbnail(videoId: broadcast.id, imageData: thumbnailData)
                StreamLogger.log(.rtmp, "YT: Thumbnail uploaded!")
            } catch {
                StreamLogger.log(.rtmp, "YT: Thumbnail upload failed: \(error) (continuing)")
            }
        }

        // Bind
        statusMessage = "Binding..."
        _ = try await api.bindBroadcastToStream(broadcastId: broadcast.id, streamId: stream.id)

        // Save to App Group for Broadcast Extension
        BroadcastConfig.save(
            url: info.ingestionAddress,
            streamKey: info.streamName,
            bitrate: bitrate,
            width: width,
            height: height
        )

        state = .readyToBroadcast
        statusMessage = "Ready! Start the broadcast, then tap Go Live."
        StreamLogger.log(.rtmp, "YT: Event created. Config saved to App Group.")
    }

    // MARK: - Step 2: Poll + Go Live

    func waitAndGoLive() async throws {
        guard let api = api, let sid = streamId, let bid = broadcastId else {
            throw YouTubeLiveAPI.APIError.invalidResponse
        }

        statusMessage = "Waiting for YouTube to detect stream..."

        var attempts = 0
        let maxAttempts = 90 // 90 * 3s = ~4.5 minutes

        while attempts < maxAttempts {
            let status = try await api.getStreamStatus(streamId: sid)
            attempts += 1
            state = .waitingForYouTube(attempts)
            statusMessage = "YouTube: \(status) (\(attempts)/\(maxAttempts))"
            StreamLogger.log(.rtmp, "YT: Poll \(attempts): \(status)")

            if status == "active" { break }
            if status == "error" { state = .error("YouTube stream error"); return }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }

        if attempts >= maxAttempts {
            state = .error("Timeout — YouTube didn't detect stream")
            return
        }

        // Transition
        state = .goingLive
        statusMessage = "Going live..."

        do {
            _ = try await api.transitionBroadcast(broadcastId: bid, to: "live")
        } catch {
            if !error.localizedDescription.contains("Redundant") &&
               !error.localizedDescription.contains("redundant") { throw error }
        }

        // Wait for live
        for i in 1...15 {
            let bs = try await api.getBroadcastStatus(broadcastId: bid)
            if bs == "live" { break }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        state = .live
        statusMessage = "LIVE on YouTube!"
        StreamLogger.log(.stream, "YT: === LIVE ===")
    }

    func endBroadcast() async {
        BroadcastConfig.clear()
        if let api = api, let bid = broadcastId {
            try? await api.endBroadcast(broadcastId: bid)
        }
        state = .ended
        statusMessage = "Broadcast ended"
        api = nil; broadcastId = nil; streamId = nil
    }

    func reset() {
        BroadcastConfig.clear()
        state = .idle; statusMessage = ""
        broadcastId = nil; streamId = nil; api = nil
    }
}
