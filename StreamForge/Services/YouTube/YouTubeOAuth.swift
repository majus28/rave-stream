import Foundation
import AuthenticationServices
import CommonCrypto

/// Handles Google/YouTube OAuth 2.0 with PKCE for iOS.
final class YouTubeOAuth: ObservableObject {
    @Published var accessToken: String?
    @Published var isAuthenticated: Bool = false
    @Published var channelName: String?
    @Published var error: String?

    private let clientId: String
    private let redirectUri: String
    private let callbackScheme: String
    private var refreshToken: String?
    private let keychain = KeychainService.shared

    // Must keep a strong reference or the session gets deallocated
    private var authSession: ASWebAuthenticationSession?

    private let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenURL = "https://oauth2.googleapis.com/token"

    private let scopes = [
        "https://www.googleapis.com/auth/youtube",
        "https://www.googleapis.com/auth/youtube.force-ssl"
    ].joined(separator: " ")

    init(clientId: String, redirectUri: String) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        // Extract scheme: "com.googleusercontent.apps.XXX:/oauth2redirect" -> "com.googleusercontent.apps.XXX"
        self.callbackScheme = redirectUri.components(separatedBy: ":").first ?? redirectUri
        loadStoredTokens()
    }

    // MARK: - Auth Flow

    @MainActor
    func login(anchor: ASPresentationAnchor) async throws {
        let codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.sha256Base64(codeVerifier)
        let state = UUID().uuidString

        var components = URLComponents(string: authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authorizationURL = components.url else {
            throw OAuthError.invalidURL
        }

        StreamLogger.log(.stream, "YouTube OAuth: opening browser")
        StreamLogger.log(.stream, "YouTube OAuth: callback scheme = \(callbackScheme)")
        StreamLogger.log(.stream, "YouTube OAuth: auth URL = \(authorizationURL.absoluteString.prefix(100))...")

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { url, error in
                if let error = error {
                    StreamLogger.log(.stream, "YouTube OAuth: browser error: \(error)")
                    continuation.resume(throwing: error)
                } else if let url = url {
                    StreamLogger.log(.stream, "YouTube OAuth: got callback URL")
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: OAuthError.cancelled)
                }
            }

            let provider = AnchorProvider(anchor: anchor)
            session.presentationContextProvider = provider
            session.prefersEphemeralWebBrowserSession = false

            // Keep strong references so they don't get deallocated
            self.authSession = session

            let started = session.start()
            StreamLogger.log(.stream, "YouTube OAuth: session.start() = \(started)")

            if !started {
                continuation.resume(throwing: OAuthError.invalidURL)
            }
        }

        // Clean up
        self.authSession = nil

        // Validate state parameter (CSRF protection)
        let params = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
        let returnedState = params?.first(where: { $0.name == "state" })?.value
        guard returnedState == state else {
            StreamLogger.log(.stream, "YouTube OAuth: state mismatch — possible CSRF")
            throw OAuthError.cancelled
        }

        // Extract authorization code
        guard let code = params?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noCode
        }

        StreamLogger.log(.stream, "YouTube OAuth: got authorization code")

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)

        // Fetch channel info
        try await fetchChannelInfo()
    }

    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken ?? keychain.loadString(key: "yt_refresh_token") else {
            throw OAuthError.noRefreshToken
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(clientId)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        keychain.save(string: response.accessToken, for: "yt_access_token")

        await MainActor.run {
            accessToken = response.accessToken
            isAuthenticated = true
        }

        StreamLogger.log(.stream, "YouTube OAuth: token refreshed")
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        channelName = nil
        keychain.delete(key: "yt_access_token")
        keychain.delete(key: "yt_refresh_token")
    }

    // MARK: - Private

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(clientId)",
            "code=\(code)",
            "code_verifier=\(codeVerifier)",
            "grant_type=authorization_code",
            "redirect_uri=\(redirectUri)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        // Log response for debugging
        if let httpResponse = response as? HTTPURLResponse {
            StreamLogger.log(.stream, "YouTube OAuth: token exchange HTTP \(httpResponse.statusCode)")
        }
        if let bodyStr = String(data: data, encoding: .utf8) {
            StreamLogger.log(.stream, "YouTube OAuth: token response = \(bodyStr.prefix(200))")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        keychain.save(string: tokenResponse.accessToken, for: "yt_access_token")
        if let refresh = tokenResponse.refreshToken {
            keychain.save(string: refresh, for: "yt_refresh_token")
        }

        await MainActor.run {
            accessToken = tokenResponse.accessToken
            refreshToken = tokenResponse.refreshToken
            isAuthenticated = true
        }

        StreamLogger.log(.stream, "YouTube OAuth: tokens obtained!")
    }

    private func fetchChannelInfo() async throws {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let items = json?["items"] as? [[String: Any]],
           let snippet = items.first?["snippet"] as? [String: Any],
           let title = snippet["title"] as? String {
            await MainActor.run { channelName = title }
            StreamLogger.log(.stream, "YouTube OAuth: channel = \(title)")
        }
    }

    private func loadStoredTokens() {
        if let token = keychain.loadString(key: "yt_access_token") {
            accessToken = token
            isAuthenticated = true
        }
        refreshToken = keychain.loadString(key: "yt_refresh_token")
    }

    // MARK: - PKCE

    private static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func sha256Base64(_ input: String) -> String {
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Types

    struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    enum OAuthError: LocalizedError {
        case invalidURL, cancelled, noCode, noRefreshToken, tokenExchangeFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid OAuth URL"
            case .cancelled: return "Login was cancelled"
            case .noCode: return "No authorization code received"
            case .noRefreshToken: return "No refresh token — please sign in again"
            case .tokenExchangeFailed: return "Token exchange failed"
            }
        }
    }
}

// MARK: - Presentation Anchor

private class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}
