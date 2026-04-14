import SwiftUI

struct DestinationsView: View {
    @ObservedObject var viewModel: DestinationsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.destinations.isEmpty {
                    emptyState
                } else {
                    destinationList
                }
            }
            .navigationTitle("Destinations")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.resetForm()
                        viewModel.showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddDestinationSheet(viewModel: viewModel)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Destinations")
                .font(.title3.bold())
                .foregroundColor(.white)

            Text("Add Twitch, YouTube, or custom RTMP destinations to start streaming")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                viewModel.resetForm()
                viewModel.showAddSheet = true
            } label: {
                Label("Add Destination", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
    }

    private var destinationList: some View {
        List {
            ForEach(viewModel.destinations) { destination in
                DestinationRow(destination: destination)
                    .listRowBackground(Color(.systemGray6).opacity(0.15))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteDestination(id: viewModel.destinations[index].id)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct DestinationRow: View {
    let destination: Destination

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: destination.type.iconName)
                .font(.title2)
                .foregroundColor(colorForType(destination.type))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(destination.type.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(destination.streamProtocol.rawValue.uppercased())
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }

    private func colorForType(_ type: DestinationType) -> Color {
        switch type {
        case .twitch: return .purple
        case .youtube: return .red
        case .customRTMP: return .blue
        }
    }
}

struct AddDestinationSheet: View {
    @ObservedObject var viewModel: DestinationsViewModel
    @Environment(\.dismiss) private var dismiss

    private var streamKeyHint: String {
        switch viewModel.newType {
        case .twitch:
            return "Find your stream key at dashboard.twitch.tv/settings/stream"
        case .youtube:
            return "Find your stream key at studio.youtube.com under Go Live"
        case .customRTMP:
            return ""
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Platform") {
                    Picker("Type", selection: $viewModel.newType) {
                        ForEach(DestinationType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.newType) { _, newType in
                        let testKey = newType.defaultTestStreamKey
                        if !testKey.isEmpty && viewModel.newStreamKey.isEmpty {
                            viewModel.newStreamKey = testKey
                        }
                    }
                }

                Section("Details") {
                    TextField("Name", text: $viewModel.newName)
                        .textInputAutocapitalization(.words)

                    if viewModel.newType == .customRTMP {
                        TextField("RTMP URL", text: $viewModel.newRtmpUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Picker("Protocol", selection: $viewModel.newProtocol) {
                            ForEach(StreamProtocol.allCases, id: \.self) { proto in
                                Text(proto.rawValue.uppercased()).tag(proto)
                            }
                        }
                    }
                }

                Section(viewModel.newType == .customRTMP ? "Stream Key" : "Stream Key (from \(viewModel.newType.displayName) dashboard)") {
                    SecureField("Paste your stream key", text: $viewModel.newStreamKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if viewModel.newType.usesOAuth {
                        Label(streamKeyHint, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Add Destination") {
                        viewModel.addDestination()
                        dismiss()
                    }
                    .disabled(viewModel.newStreamKey.isEmpty && viewModel.newType != .customRTMP)
                    .disabled(viewModel.newType == .customRTMP && viewModel.newRtmpUrl.isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Destination")
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
        .presentationDetents([.medium, .large])
    }
}
