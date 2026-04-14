import Foundation

enum AuthProvider: String, Codable, CaseIterable {
    case email
    case twitch
    case youtube
}

enum UserMode: String, Codable {
    case guest
    case authenticated
}

struct User: Identifiable, Codable {
    let id: UUID
    var email: String?
    var mode: UserMode
    var provider: AuthProvider?
    let createdAt: Date

    static func guest() -> User {
        User(
            id: UUID(),
            email: nil,
            mode: .guest,
            provider: nil,
            createdAt: Date()
        )
    }
}
