import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showEmailLogin = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 56))
                        .foregroundStyle(.linearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("StreamForge")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 14) {
                    // Twitch
                    Button {
                        Task { await viewModel.loginWithTwitch() }
                    } label: {
                        Label("Continue with Twitch", systemImage: "gamecontroller.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // YouTube
                    Button {
                        Task { await viewModel.loginWithYouTube() }
                    } label: {
                        Label("Continue with YouTube", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // Email
                    Button {
                        showEmailLogin = true
                    } label: {
                        Label("Continue with Email", systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // Guest
                    Button {
                        viewModel.loginAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.gray)
                    }
                }
                .font(.headline)
                .padding(.horizontal, 24)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer().frame(height: 40)
            }
        }
        .sheet(isPresented: $showEmailLogin) {
            EmailLoginSheet(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
    }
}

struct EmailLoginSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                }

                Section {
                    Button("Sign In") {
                        Task {
                            await viewModel.loginWithEmail()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Email Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
