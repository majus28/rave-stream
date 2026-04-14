import Foundation

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var baseURL: URL?
    private var authToken: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(baseURL: String, authToken: String? = nil) {
        self.baseURL = URL(string: baseURL)
        self.authToken = authToken
    }

    var isConfigured: Bool {
        baseURL != nil
    }

    // MARK: - Auth

    func loginWithEmail(email: String, password: String) async throws -> User {
        try await post("/auth/login", body: ["email": email, "password": password])
    }

    func loginWithOAuth(provider: String, code: String) async throws -> User {
        try await post("/auth/oauth", body: ["provider": provider, "code": code])
    }

    func loginAsGuest() async throws -> User {
        try await post("/auth/guest", body: [:] as [String: String])
    }

    // MARK: - Destinations

    func createDestination(_ destination: Destination) async throws -> Destination {
        try await post("/destinations", body: destination)
    }

    func getDestinations() async throws -> [Destination] {
        try await get("/destinations")
    }

    func updateDestination(_ destination: Destination) async throws -> Destination {
        try await patch("/destinations/\(destination.id)", body: destination)
    }

    func deleteDestination(id: UUID) async throws {
        try await delete("/destinations/\(id)")
    }

    // MARK: - Streams

    func createStream(_ session: StreamSession) async throws -> StreamSession {
        try await post("/streams", body: session)
    }

    func getStream(id: UUID) async throws -> StreamSession {
        try await get("/streams/\(id)")
    }

    func updateStream(_ session: StreamSession) async throws -> StreamSession {
        try await patch("/streams/\(session.id)", body: session)
    }

    func startStream(id: UUID) async throws {
        let _: EmptyResponse = try await post("/streams/\(id)/start", body: [:] as [String: String])
    }

    func stopStream(id: UUID) async throws {
        let _: EmptyResponse = try await post("/streams/\(id)/stop", body: [:] as [String: String])
    }

    func reconnectStream(id: UUID) async throws {
        let _: EmptyResponse = try await post("/streams/\(id)/reconnect", body: [:] as [String: String])
    }

    // MARK: - Overlays

    func createOverlay(_ overlay: Overlay) async throws -> Overlay {
        try await post("/overlays", body: overlay)
    }

    func getOverlays(streamId: UUID) async throws -> [Overlay] {
        try await get("/overlays/\(streamId)")
    }

    func updateOverlay(_ overlay: Overlay) async throws -> Overlay {
        try await patch("/overlays/\(overlay.id)", body: overlay)
    }

    func deleteOverlay(id: UUID) async throws {
        try await delete("/overlays/\(id)")
    }

    // MARK: - Scenes

    func createScene(_ scene: StreamScene) async throws -> StreamScene {
        try await post("/scenes", body: scene)
    }

    func getScenes(streamId: UUID) async throws -> [StreamScene] {
        try await get("/scenes/\(streamId)")
    }

    func updateScene(_ scene: StreamScene) async throws -> StreamScene {
        try await patch("/scenes/\(scene.id)", body: scene)
    }

    func deleteScene(id: UUID) async throws {
        try await delete("/scenes/\(id)")
    }

    // MARK: - Performance

    func postPerformanceSample(streamId: UUID, sample: PerformanceSample) async throws {
        let _: EmptyResponse = try await post("/streams/\(streamId)/performance-samples", body: sample)
    }

    func getPerformanceSummary(streamId: UUID) async throws -> PerformanceSummary {
        try await get("/streams/\(streamId)/performance-summary")
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try jsonEncoder.encode(body)
        return try await execute(request)
    }

    private func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "PATCH")
        request.httpBody = try jsonEncoder.encode(body)
        return try await execute(request)
    }

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        guard let base = baseURL else { throw APIError.notConfigured }

        guard let url = URL(string: path, relativeTo: base) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Types

    private struct EmptyResponse: Decodable {}

    enum APIError: LocalizedError {
        case notConfigured
        case invalidURL
        case requestFailed
        case httpError(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "API client not configured"
            case .invalidURL: return "Invalid URL"
            case .requestFailed: return "Request failed"
            case .httpError(let code): return "HTTP error \(code)"
            }
        }
    }
}

// Make PerformanceSummary decodable for API responses
extension PerformanceSummary: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        averageBitrate = try container.decode(Int.self, forKey: .averageBitrate)
        totalDroppedFrames = try container.decode(Int.self, forKey: .totalDroppedFrames)
        droppedFramePercentage = try container.decode(Double.self, forKey: .droppedFramePercentage)
        reconnectCount = try container.decode(Int.self, forKey: .reconnectCount)
        peakThermalState = try container.decode(ThermalState.self, forKey: .peakThermalState)
        qualityScore = try container.decode(Int.self, forKey: .qualityScore)
        topIssues = try container.decode([String].self, forKey: .topIssues)
        suggestions = try container.decode([String].self, forKey: .suggestions)
    }

    private enum CodingKeys: String, CodingKey {
        case averageBitrate, totalDroppedFrames, droppedFramePercentage
        case reconnectCount, peakThermalState, qualityScore, topIssues, suggestions
    }
}
