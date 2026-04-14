import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                // Account
                Section("Account") {
                    if let user = viewModel.authService.currentUser {
                        LabeledContent("Mode", value: user.mode.rawValue.capitalized)
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                        if let provider = user.provider {
                            LabeledContent("Provider", value: provider.rawValue.capitalized)
                        }
                    }
                }

                // Defaults
                Section("Stream Defaults") {
                    Picker("Resolution", selection: $viewModel.defaultResolution) {
                        ForEach(StreamResolution.allCases, id: \.self) { res in
                            Text(res.displayName).tag(res)
                        }
                    }

                    Picker("Frame Rate", selection: $viewModel.defaultFps) {
                        ForEach(StreamFPS.allCases, id: \.self) { fps in
                            Text(fps.displayName).tag(fps)
                        }
                    }

                    Picker("Orientation", selection: $viewModel.defaultOrientation) {
                        ForEach(StreamOrientation.allCases, id: \.self) { o in
                            Text(o.displayName).tag(o)
                        }
                    }
                }

                // Performance
                Section("Performance") {
                    Toggle("Live Priority Mode", isOn: $viewModel.livePriorityMode)

                    if viewModel.livePriorityMode {
                        Label("Prioritizes stream stability over UI fidelity during live streams", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Noise Reduction", isOn: $viewModel.noiseReduction)
                }

                // Behavior
                Section("Behavior") {
                    Toggle("Remember Last Destination", isOn: $viewModel.saveLastUsedDestination)
                    Toggle("Remember Stream Config", isOn: $viewModel.saveLastUsedStreamConfig)
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        viewModel.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text(viewModel.authService.currentUser?.mode == .guest ? "Reset Guest Data" : "Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: viewModel.defaultResolution) { _, _ in viewModel.save() }
            .onChange(of: viewModel.defaultFps) { _, _ in viewModel.save() }
            .onChange(of: viewModel.defaultOrientation) { _, _ in viewModel.save() }
            .onChange(of: viewModel.livePriorityMode) { _, _ in viewModel.save() }
            .onChange(of: viewModel.noiseReduction) { _, _ in viewModel.save() }
            .onChange(of: viewModel.saveLastUsedDestination) { _, _ in viewModel.save() }
            .onChange(of: viewModel.saveLastUsedStreamConfig) { _, _ in viewModel.save() }
        }
    }
}
