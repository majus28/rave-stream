import Foundation

final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func loginAsGuest() {
        authService.loginAsGuest()
    }

    func loginWithEmail() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        isLoading = true
        errorMessage = nil
        await authService.loginWithEmail(email: email, password: password)
        isLoading = false
    }

    func loginWithTwitch() async {
        isLoading = true
        errorMessage = nil
        await authService.loginWithTwitch()
        isLoading = false
    }

    func loginWithYouTube() async {
        isLoading = true
        errorMessage = nil
        await authService.loginWithYouTube()
        isLoading = false
    }
}
