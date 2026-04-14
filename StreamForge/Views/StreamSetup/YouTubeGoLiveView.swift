import SwiftUI
import PhotosUI
import ReplayKit

struct YouTubeGoLiveView: View {
    @ObservedObject var goLiveService: YouTubeGoLiveService
    @ObservedObject var streamingService: StreamingService
    @ObservedObject var performanceMonitor: PerformanceMonitor

    @State private var title = ""
    @State private var description = ""
    @State private var privacy = "unlisted"
    @State private var resolution = "720p"
    @State private var orientation = "landscape"
    @State private var isWorking = false

    // Thumbnail
    @State private var thumbnailItem: PhotosPickerItem?
    @State private var thumbnailImage: UIImage?
    @State private var thumbnailData: Data?

    @Environment(\.dismiss) private var dismiss

    private static let presetKey = "yt_stream_preset"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    accountSection

                    if goLiveService.oauth.isAuthenticated {
                        switch goLiveService.state {
                        case .idle: setupForm
                        case .creatingEvent: progressView("Setting up YouTube event...")
                        case .readyToBroadcast: broadcastSection
                        case .waitingForYouTube, .goingLive: pollingSection
                        case .live: liveSection
                        case .error(let msg): errorSection(msg)
                        case .ended: endedSection
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("YouTube Go Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .keyboard) {
                    HStack { Spacer(); Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }}
                }
            }
            .onAppear { loadPreset() }
            .onChange(of: title) { _, _ in savePreset() }
            .onChange(of: description) { _, _ in savePreset() }
            .onChange(of: privacy) { _, _ in savePreset() }
            .onChange(of: resolution) { _, _ in savePreset() }
            .onChange(of: orientation) { _, _ in savePreset() }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(spacing: 12) {
            if goLiveService.oauth.isAuthenticated {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("YouTube Connected").font(.headline).foregroundColor(.white)
                        if let ch = goLiveService.oauth.channelName {
                            Text(ch).font(.caption).foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Button("Sign Out") { goLiveService.oauth.logout(); goLiveService.reset() }
                        .font(.caption).foregroundColor(.red)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill").font(.system(size: 40)).foregroundColor(.red)
                    Text("Sign in to YouTube").font(.headline).foregroundColor(.white)
                    Button {
                        Task {
                            guard let w = UIApplication.shared.connectedScenes
                                .compactMap({ $0 as? UIWindowScene }).flatMap(\.windows)
                                .first(where: \.isKeyWindow) else { return }
                            do { try await goLiveService.oauth.login(anchor: w) }
                            catch { goLiveService.state = .error(error.localizedDescription) }
                        }
                    } label: {
                        Label("Sign in with Google", systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.red).foregroundColor(.white).cornerRadius(10)
                    }
                }
            }
        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    // MARK: - Setup Form

    private var setupForm: some View {
        VStack(spacing: 14) {
            // Title
            TextField("Stream Title", text: $title)
                .textFieldStyle(.roundedBorder)

            // Description
            TextField("Description (optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            // Thumbnail
            VStack(alignment: .leading, spacing: 8) {
                Text("Thumbnail").font(.caption.bold()).foregroundColor(.gray)

                HStack(spacing: 12) {
                    // Preview
                    if let img = thumbnailImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 120, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5).opacity(0.3))
                            .frame(width: 120, height: 68)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        PhotosPicker(selection: $thumbnailItem, matching: .images) {
                            Label("Choose Image", systemImage: "photo.on.rectangle")
                                .font(.subheadline)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }

                        if thumbnailImage != nil {
                            Button {
                                thumbnailImage = nil
                                thumbnailData = nil
                                thumbnailItem = nil
                            } label: {
                                Text("Remove")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .onChange(of: thumbnailItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        thumbnailData = data
                        thumbnailImage = UIImage(data: data)
                    }
                }
            }

            // Orientation
            VStack(alignment: .leading, spacing: 4) {
                Text("Orientation").font(.caption.bold()).foregroundColor(.gray)
                Picker("Orientation", selection: $orientation) {
                    HStack {
                        Image(systemName: "rectangle.landscape.rotate")
                        Text("Landscape")
                    }.tag("landscape")
                    HStack {
                        Image(systemName: "rectangle.portrait.rotate")
                        Text("Portrait")
                    }.tag("portrait")
                }.pickerStyle(.segmented)
            }

            // Privacy + Quality
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy").font(.caption.bold()).foregroundColor(.gray)
                    Picker("Privacy", selection: $privacy) {
                        Text("Public").tag("public")
                        Text("Unlisted").tag("unlisted")
                        Text("Private").tag("private")
                    }.pickerStyle(.segmented)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Quality").font(.caption.bold()).foregroundColor(.gray)
                Picker("Quality", selection: $resolution) {
                    Text("720p").tag("720p")
                    Text("1080p").tag("1080p")
                }.pickerStyle(.segmented)
            }

            // Scene Layout Editor
            VStack(alignment: .leading, spacing: 4) {
                Text("Scene Layout").font(.caption.bold()).foregroundColor(.gray)
                Text("Drag to arrange game screen, add overlays, logos, GIFs")
                    .font(.caption2).foregroundColor(.gray)
            }
            SceneEditorView(layout: SceneLayoutStore.load()) { _ in }

            // BRB + text overlays
            StreamControlPanel()

            // Create Event button
            Button {
                Task {
                    isWorking = true
                    do {
                        try? await goLiveService.oauth.refreshAccessToken()
                        try await goLiveService.createEvent(
                            title: title,
                            description: description,
                            privacy: privacy,
                            resolution: resolution == "1080p" ? .hd1080p : .hd720p,
                            orientation: orientation == "landscape" ? .landscape : .portrait,
                            bitrate: resolution == "1080p" ? 4000 : 2500,
                            thumbnailData: thumbnailData
                        )
                    } catch {
                        goLiveService.state = .error(error.localizedDescription)
                    }
                    isWorking = false
                }
            } label: {
                HStack {
                    Spacer()
                    if isWorking { ProgressView().tint(.white) }
                    Text("Create YouTube Event").font(.headline)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(title.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white).cornerRadius(12)
            }
            .disabled(title.isEmpty || isWorking)

        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    // MARK: - Polling

    private var pollingSection: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white).scaleEffect(1.5)
            Text(goLiveService.statusMessage).font(.subheadline).foregroundColor(.white).multilineTextAlignment(.center)
        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    // MARK: - Live

    private var liveSection: some View {
        VStack(spacing: 16) {
            HStack { Circle().fill(.red).frame(width: 12, height: 12); Text("LIVE").font(.title3.bold()).foregroundColor(.red) }
            Text("You are live on YouTube!").foregroundColor(.green)

            // Scene Editor — edit overlays live
            SceneEditorView(layout: SceneLayoutStore.load()) { _ in }

            // BRB
            StreamControlPanel()

            Button {
                BroadcastOverlayConfig.clearAll()
                Task { await goLiveService.endBroadcast() }
            } label: {
                Label("End Broadcast", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(10)
            }
        }
    }

    private var broadcastSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundColor(.green)
            Text("YouTube Event Ready!").font(.title3.bold()).foregroundColor(.white)

            if orientation == "landscape" {
                Label("Landscape — rotate your phone sideways", systemImage: "rotate.right")
                    .font(.caption).foregroundColor(.orange)
            }

            // Scene editor — configure overlays, game screen size
            Text("Scene Layout (drag to arrange)").font(.caption.bold()).foregroundColor(.gray)
            SceneEditorView(layout: SceneLayoutStore.load()) { _ in }

            // BRB + text overlays
            StreamControlPanel()

            // Step 1
            VStack(spacing: 6) {
                Text("STEP 1").font(.caption.bold()).foregroundColor(.orange)
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.red).frame(height: 56)
                    HStack {
                        Image(systemName: "record.circle").font(.title2)
                        Text("Start Broadcast").font(.headline)
                    }.foregroundColor(.white).allowsHitTesting(false)
                    BroadcastPickerView().frame(height: 56)
                }
                Text("Select 'StreamForge Broadcast'").font(.caption).foregroundColor(.gray)
            }

            // Step 2
            VStack(spacing: 6) {
                Text("STEP 2").font(.caption.bold()).foregroundColor(.green)
                Button {
                    Task {
                        do { try await goLiveService.waitAndGoLive() }
                        catch { goLiveService.state = .error(error.localizedDescription) }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("Go Live on YouTube", systemImage: "dot.radiowaves.left.and.right").font(.headline)
                        Spacer()
                    }.padding(.vertical, 14).background(Color.green).foregroundColor(.white).cornerRadius(12)
                }
            }
        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    // MARK: - Helpers

    private func progressView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white).scaleEffect(1.5)
            Text(msg).font(.subheadline).foregroundColor(.white)
        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    private func errorSection(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundColor(.orange)
            Text(msg).font(.subheadline).foregroundColor(.white).multilineTextAlignment(.center)
            Button("Try Again") { goLiveService.reset() }.foregroundColor(.blue)
        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    private var endedSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.green)
            Text("Broadcast Ended").font(.headline).foregroundColor(.white)
            Button("New Broadcast") { goLiveService.reset() }.foregroundColor(.blue)
        }.padding().background(Color(.systemGray6).opacity(0.15)).cornerRadius(12)
    }

    // MARK: - Preset Persistence

    private func savePreset() {
        let defaults = UserDefaults.standard
        defaults.set(title, forKey: "yt_preset_title")
        defaults.set(description, forKey: "yt_preset_description")
        defaults.set(privacy, forKey: "yt_preset_privacy")
        defaults.set(resolution, forKey: "yt_preset_resolution")
        defaults.set(orientation, forKey: "yt_preset_orientation")

        // Save thumbnail to App Group so it persists
        if let data = thumbnailData {
            if let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.majuz.streamforge"
            ) {
                try? data.write(to: containerURL.appendingPathComponent("yt_thumbnail.jpg"))
            }
        }
    }

    private func loadPreset() {
        let defaults = UserDefaults.standard

        let savedTitle = defaults.string(forKey: "yt_preset_title") ?? ""
        let savedDesc = defaults.string(forKey: "yt_preset_description") ?? ""
        let savedPrivacy = defaults.string(forKey: "yt_preset_privacy") ?? "unlisted"
        let savedRes = defaults.string(forKey: "yt_preset_resolution") ?? "720p"
        let savedOrientation = defaults.string(forKey: "yt_preset_orientation") ?? "landscape"

        if !savedTitle.isEmpty { title = savedTitle }
        description = savedDesc
        privacy = savedPrivacy
        resolution = savedRes
        orientation = savedOrientation

        // Load saved thumbnail
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.majuz.streamforge"
        ) {
            let thumbURL = containerURL.appendingPathComponent("yt_thumbnail.jpg")
            if let data = try? Data(contentsOf: thumbURL) {
                thumbnailData = data
                thumbnailImage = UIImage(data: data)
            }
        }
    }
}
