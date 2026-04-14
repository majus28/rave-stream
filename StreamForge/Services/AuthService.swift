import Foundation
import AuthenticationServices

final class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let keychain = KeychainService.shared
    private let userDefaultsKey = "currentUser"

    init() {}

    func loadIfNeeded() {
        if currentUser == nil {
            loadPersistedUser()
        }
    }

    func loginAsGuest() {
        let user = User.guest()
        setCurrentUser(user)
    }

    func loginWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil

        let user = User(
            id: UUID(),
            email: email,
            mode: .authenticated,
            provider: .email,
            createdAt: Date()
        )
        setCurrentUser(user)
        isLoading = false
    }

    func loginWithTwitch() async {
        isLoading = true
        error = nil

        let user = User(
            id: UUID(),
            email: nil,
            mode: .authenticated,
            provider: .twitch,
            createdAt: Date()
        )
        setCurrentUser(user)
        isLoading = false
    }

    func loginWithYouTube() async {
        isLoading = true
        error = nil

        let user = User(
            id: UUID(),
            email: nil,
            mode: .authenticated,
            provider: .youtube,
            createdAt: Date()
        )
        setCurrentUser(user)
        isLoading = false
    }

    func logout() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        keychain.delete(key: "authToken")
    }

    private func setCurrentUser(_ user: User) {
        currentUser = user
        isAuthenticated = true
        persistUser(user)
    }

    private func persistUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadPersistedUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        currentUser = user
        isAuthenticated = true
    }
}
