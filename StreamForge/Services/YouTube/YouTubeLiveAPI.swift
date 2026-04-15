import Foundation
import UIKit

/// YouTube Data API v3 — Live Streaming endpoints
final class YouTubeLiveAPI {
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let session = URLSession.shared
    private var accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func updateToken(_ token: String) {
        self.accessToken = token
    }

    // MARK: - 1. Create Live Stream (ingest target)

    struct LiveStreamResponse: Decodable {
        let id: String
        let cdn: CDN?
        let status: StreamStatus?

        struct CDN: Decodable {
            let ingestionInfo: IngestionInfo?
            let resolution: String?
            let frameRate: String?
        }

        struct IngestionInfo: Decodable {
            let ingestionAddress: String
            let streamName: String
            let backupIngestionAddress: String?
        }

        struct StreamStatus: Decodable {
            let streamStatus: String?
            let healthStatus: HealthStatus?
        }

        struct HealthStatus: Decodable {
            let status: String?
        }
    }

    func createLiveStream(
        title: String,
        resolution: String = "720p",
        frameRate: String = "30fps"
    ) async throws -> LiveStreamResponse {
        StreamLogger.log(.rtmp, "YT API: Creating liveStream...")

        let body: [String: Any] = [
            "snippet": [
                "title": title
            ],
            "cdn": [
                "ingestionType": "rtmp",
                "resolution": resolution,
                "frameRate": frameRate
            ]
        ]

        let data = try await post(
            path: "/liveStreams?part=snippet,cdn,status",
            body: body
        )

        let stream = try JSONDecoder().decode(LiveStreamResponse.self, from: data)
        StreamLogger.log(.rtmp, "YT API: Stream created: id=\(stream.id)")
        if let info = stream.cdn?.ingestionInfo {
            StreamLogger.log(.rtmp, "YT API: Ingest: \(info.ingestionAddress)/\(String(info.streamName.prefix(8)))...")
        }
        return stream
    }

    // MARK: - 2. Create Live Broadcast (event)

    struct LiveBroadcastResponse: Decodable {
        let id: String
        let snippet: Snippet?
        let status: BroadcastStatus?
        let contentDetails: ContentDetails?

        struct Snippet: Decodable {
            let title: String?
            let scheduledStartTime: String?
        }

        struct BroadcastStatus: Decodable {
            let lifeCycleStatus: String?
            let privacyStatus: String?
        }

        struct ContentDetails: Decodable {
            let boundStreamId: String?
            let enableMonitorStream: Bool?
            let monitorStream: MonitorStream?
        }

        struct MonitorStream: Decodable {
            let enableMonitorStream: Bool?
        }
    }

    func createLiveBroadcast(
        title: String,
        description: String = "",
        privacyStatus: String = "unlisted",
        enableMonitorStream: Bool = false
    ) async throws -> LiveBroadcastResponse {
        StreamLogger.log(.rtmp, "YT API: Creating liveBroadcast...")

        let isoDate = ISO8601DateFormatter().string(from: Date())

        let body: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description,
                "scheduledStartTime": isoDate
            ],
            "status": [
                "privacyStatus": privacyStatus,
                "selfDeclaredMadeForKids": false
            ],
            "contentDetails": [
                "enableAutoStart": false,
                "enableAutoStop": true,
                "monitorStream": [
                    "enableMonitorStream": enableMonitorStream
                ]
            ]
        ]

        let data = try await post(
            path: "/liveBroadcasts?part=snippet,status,contentDetails",
            body: body
        )

        let broadcast = try JSONDecoder().decode(LiveBroadcastResponse.self, from: data)
        StreamLogger.log(.rtmp, "YT API: Broadcast created: id=\(broadcast.id), status=\(broadcast.status?.lifeCycleStatus ?? "?")")
        return broadcast
    }

    // MARK: - 3. Bind broadcast ↔ stream

    func bindBroadcastToStream(broadcastId: String, streamId: String) async throws -> LiveBroadcastResponse {
        StreamLogger.log(.rtmp, "YT API: Binding broadcast \(broadcastId) to stream \(streamId)...")

        let data = try await post(
            path: "/liveBroadcasts/bind?id=\(broadcastId)&part=id,contentDetails&streamId=\(streamId)",
            body: nil
        )

        let broadcast = try JSONDecoder().decode(LiveBroadcastResponse.self, from: data)
        StreamLogger.log(.rtmp, "YT API: Bound! streamId=\(broadcast.contentDetails?.boundStreamId ?? "?")")
        return broadcast
    }

    // MARK: - 4. Get stream status (poll)

    func getStreamStatus(streamId: String) async throws -> String {
        let data = try await get(path: "/liveStreams?part=status&id=\(streamId)")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]]
        let status = (items?.first?["status"] as? [String: Any])?["streamStatus"] as? String
        return status ?? "unknown"
    }

    func getBroadcastStatus(broadcastId: String) async throws -> String {
        let data = try await get(path: "/liveBroadcasts?part=status&id=\(broadcastId)")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]]
        let status = (items?.first?["status"] as? [String: Any])?["lifeCycleStatus"] as? String
        return status ?? "unknown"
    }

    // MARK: - 5. Transition broadcast to live

    func transitionBroadcast(broadcastId: String, to status: String) async throws -> LiveBroadcastResponse {
        StreamLogger.log(.rtmp, "YT API: Transitioning broadcast to '\(status)'...")

        let data = try await post(
            path: "/liveBroadcasts/transition?broadcastStatus=\(status)&id=\(broadcastId)&part=id,status",
            body: nil
        )

        let broadcast = try JSONDecoder().decode(LiveBroadcastResponse.self, from: data)
        StreamLogger.log(.rtmp, "YT API: Transition result: \(broadcast.status?.lifeCycleStatus ?? "?")")
        return broadcast
    }

    // MARK: - 6. End broadcast

    func endBroadcast(broadcastId: String) async throws {
        StreamLogger.log(.rtmp, "YT API: Ending broadcast...")
        _ = try await transitionBroadcast(broadcastId: broadcastId, to: "complete")
    }

    // MARK: - 7. Delete broadcast (for stuck states)

    func deleteBroadcast(broadcastId: String) async throws {
        StreamLogger.log(.rtmp, "YT API: Deleting broadcast \(broadcastId)...")
        try await delete(path: "/liveBroadcasts?id=\(broadcastId)")
    }

    // MARK: - 8. Upload thumbnail

    func uploadThumbnail(videoId: String, imageData: Data) async throws {
        // Convert to JPEG if needed (YouTube requires JPEG/PNG, max 2MB)
        let jpegData: Data
        if let uiImage = UIImage(data: imageData) {
            jpegData = uiImage.jpegData(compressionQuality: 0.9) ?? imageData
        } else {
            jpegData = imageData
        }

        StreamLogger.log(.rtmp, "YT API: Uploading thumbnail (\(jpegData.count) bytes)...")

        // Simple media upload — send image directly as request body
        let url = URL(string: "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId=\(videoId)&uploadType=media")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(jpegData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = jpegData

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            StreamLogger.log(.rtmp, "YT API: Thumbnail upload HTTP \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8)?.prefix(200) {
                StreamLogger.log(.rtmp, "YT API: Thumbnail response: \(body)")
            }
        }

        try checkResponse(response, data: data)
        StreamLogger.log(.rtmp, "YT API: Thumbnail uploaded!")
    }

    // MARK: - HTTP Helpers

    private func get(path: String) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return data
    }

    private func post(path: String, body: [String: Any]?) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return data
    }

    private func delete(path: String) async throws {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            // Parse YouTube error
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            StreamLogger.log(.rtmp, "YT API ERROR (\(http.statusCode)): \(errorBody)")

            if errorBody.contains("liveStreamingNotEnabled") {
                throw APIError.liveStreamingNotEnabled
            }
            if errorBody.contains("livePermissionBlocked") {
                throw APIError.livePermissionBlocked
            }
            throw APIError.httpError(statusCode: http.statusCode, body: errorBody)
        }
    }

    enum APIError: LocalizedError {
        case invalidResponse
        case liveStreamingNotEnabled
        case livePermissionBlocked
        case httpError(statusCode: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid API response"
            case .liveStreamingNotEnabled: return "Live streaming is not enabled on this YouTube channel. Enable it at youtube.com/features"
            case .livePermissionBlocked: return "Live streaming permission is blocked. Your channel may need to wait 24 hours after enabling."
            case .httpError(let code, let body): return "YouTube API error \(code): \(body.prefix(200))"
            }
        }
    }
}
