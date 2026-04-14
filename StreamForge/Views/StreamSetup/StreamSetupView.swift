import SwiftUI

struct StreamSetupView: View {
    @ObservedObject var viewModel: StreamSetupViewModel
    @State private var navigateToLive = false

    var body: some View {
        NavigationStack {
            Form {
                // Stream info
                Section("Stream Info") {
                    TextField("Title (optional)", text: $viewModel.title)
                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Destinations
                Section("Destinations (max \(StreamSetupViewModel.maxDestinations))") {
                    if viewModel.availableDestinations.isEmpty {
                        Text("No destinations configured")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.availableDestinations) { dest in
                            HStack {
                                Image(systemName: dest.type.iconName)
                                    .foregroundColor(dest.type == .twitch ? .purple : dest.type == .youtube ? .red : .blue)
                                Text(dest.name)
                                Spacer()
                                if viewModel.selectedDestinationIds.contains(dest.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleDestination(dest.id)
                            }
                        }
                    }
                }

                // Capture
                Section("Capture") {
                    HStack {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundColor(.blue)
                        Text("Screen + Audio")
                            .foregroundColor(.white)
                        Spacer()
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Picker("Orientation", selection: $viewModel.orientation) {
                        ForEach(StreamOrientation.allCases, id: \.self) { o in
                            Text(o.displayName).tag(o)
                        }
                    }
                }

                // Quality preset
                Section("Quality") {
                    Picker("Preset", selection: $viewModel.selectedPreset) {
                        ForEach(StreamPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedPreset) { _, newValue in
                        viewModel.applyPreset(newValue)
                    }

                    LabeledContent("Resolution", value: viewModel.resolution.displayName)
                    LabeledContent("FPS", value: viewModel.fps.displayName)
                    LabeledContent("Bitrate", value: "\(viewModel.bitrate) Kbps")
                }

                if viewModel.isMultistream {
                    Section {
                        Label("Multistream requires backend relay", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                // Go Live
                Section {
                    Button {
                        Task {
                            await viewModel.createAndStartStream()
                            navigateToLive = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Go Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!viewModel.canStartStream)
                    .tint(.red)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Stream")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
        }
    }
}
