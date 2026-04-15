import Foundation
import Combine

/// YouTube Go Live — non-blocking polling.
@MainActor
final class YouTubeGoLiveService: ObservableObject {

    enum GoLiveState: Equatable {
        case idle
        case creatingEvent
        case readyToBroadcast
        case waitingForYouTube(Int)
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
    private var pollTask: Task<Void, Never>?
    var hkManager: HKStreamManager?

    let oauth: YouTubeOAuth

    nonisolated init(oauth: YouTubeOAuth) {
        self.oauth = oauth
    }

    // MARK: - Step 1: Create Event

    func createEvent(
        title: String,
        description: String = "",
        privacy: String = "unlisted",
        resolution: StreamResolution = .hd720p,
        orientation: StreamOrientation = .landscape,
        fps: StreamFPS = .fps30,
        bitrate: Int = 2500,
        thumbnailData: Data? = nil
    ) async throws {
        guard let token = oauth.accessToken else {
            throw YouTubeLiveAPI.APIError.invalidResponse
        }

        let api = YouTubeLiveAPI(accessToken: token)
        self.api = api

        let resStr = resolution == .hd1080p ? "1080p" : resolution == .qhd1440p ? "1440p" : "720p"
        let width: Int
        let height: Int
        if orientation == .landscape {
            width = resolution.width
            height = resolution.height
        } else {
            width = resolution.height
            height = resolution.width
        }

        state = .creatingEvent
        statusMessage = "Creating stream..."

        let stream = try await api.createLiveStream(title: "\(title) - stream", resolution: resStr, frameRate: "\(fps.rawValue)fps")
        self.streamId = stream.id
        guard let info = stream.cdn?.ingestionInfo else { throw YouTubeLiveAPI.APIError.invalidResponse }

        statusMessage = "Creating broadcast..."
        let broadcast = try await api.createLiveBroadcast(title: title, description: description, privacyStatus: privacy, enableMonitorStream: false)
        self.broadcastId = broadcast.id

        if let thumbnailData = thumbnailData {
            statusMessage = "Uploading thumbnail..."
            do {
                try await api.uploadThumbnail(videoId: broadcast.id, imageData: thumbnailData)
            } catch {
                StreamLogger.log(.rtmp, "YT: Thumbnail upload failed: \(error)")
                // Don't block the stream — continue without thumbnail
            }
        }

        statusMessage = "Binding..."
        _ = try await api.bindBroadcastToStream(broadcastId: broadcast.id, streamId: stream.id)

        BroadcastConfig.save(
            url: info.ingestionAddress,
            streamKey: info.streamName,
            bitrate: bitrate,
            width: width,
            height: height,
            fps: fps.rawValue
        )

        state = .readyToBroadcast
        statusMessage = "Ready! Start the broadcast, then tap Go Live."
    }

    // MARK: - Step 2: Poll + Go Live (non-blocking)

    func waitAndGoLive() {
        guard let api = api, let sid = streamId, let bid = broadcastId else {
            state = .error("No event created")
            return
        }

        state = .waitingForYouTube(0)
        statusMessage = "Waiting for YouTube..."

        // Run polling on a background task — UI stays responsive
        pollTask = Task.detached { [weak self] in
            var attempts = 0
            let maxAttempts = 90

            // Poll stream status
            while attempts < maxAttempts {
                do {
                    let status = try await api.getStreamStatus(streamId: sid)
                    attempts += 1

                    await MainActor.run {
                        self?.state = .waitingForYouTube(attempts)
                        self?.statusMessage = "YouTube: \(status) (\(attempts)/\(maxAttempts))"
                    }

                    if status == "active" { break }
                    if status == "error" {
                        await MainActor.run { self?.state = .error("YouTube stream error") }
                        return
                    }
                } catch {
                    await MainActor.run { self?.state = .error(error.localizedDescription) }
                    return
                }

                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
            }

            if attempts >= maxAttempts {
                await MainActor.run { self?.state = .error("Timeout — YouTube didn't detect stream") }
                return
            }

            // Transition to live
            await MainActor.run {
                self?.state = .goingLive
                self?.statusMessage = "Going live..."
            }

            do {
                _ = try await api.transitionBroadcast(broadcastId: bid, to: "live")
            } catch {
                let msg = error.localizedDescription
                if !msg.contains("Redundant") && !msg.contains("redundant") {
                    await MainActor.run { self?.state = .error(msg) }
                    return
                }
            }

            // Wait for live status
            for _ in 1...15 {
                do {
                    let bs = try await api.getBroadcastStatus(broadcastId: bid)
                    if bs == "live" { break }
                } catch { break }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
            }

            await MainActor.run {
                self?.state = .live
                self?.statusMessage = "LIVE on YouTube!"
            }
        }
    }

    // MARK: - End

    func endBroadcast() async {
        pollTask?.cancel()
        pollTask = nil
        BroadcastConfig.clear()
        if let api = api, let bid = broadcastId {
            try? await api.endBroadcast(broadcastId: bid)
        }
        state = .ended
        statusMessage = "Broadcast ended"
        api = nil; broadcastId = nil; streamId = nil
    }

    func reset() {
        pollTask?.cancel()
        pollTask = nil
        BroadcastConfig.clear()
        state = .idle; statusMessage = ""
        broadcastId = nil; streamId = nil; api = nil
    }
}
