import SwiftUI
import PhotosUI
import AVKit
import ImageIO
import UniformTypeIdentifiers

/// StreamChamp-style scene editor with dark purple theme.
struct SceneEditorView: View {
    @State var layout: SceneLayout
    @State private var selectedLayerId: UUID?
    @State private var showAddWidget = false
    @State private var imagePickerLayerId: UUID?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFilePicker = false
    @State private var filePickerLayerId: UUID?
    @State private var overlayImages: [UUID: UIImage] = [:]

    // Scenes
    @State private var sceneCollection: SceneCollection = SceneLayoutStore.loadScenes()
    @State private var showSceneManager = false

    var onSave: (SceneLayout) -> Void

    private let purple = Color(red: 0.4, green: 0.2, blue: 0.8)
    private let darkBg = Color(red: 0.08, green: 0.06, blue: 0.12)

    var body: some View {
        VStack(spacing: 0) {
            // Scenes bar
            scenesBar

            // Canvas
            canvasPreview.padding(8)

            // Layer tabs + controls
            layerEditor
        }
        .background(darkBg)
        .onAppear {
            sceneCollection = SceneLayoutStore.loadScenes()
            if let active = sceneCollection.activeScene {
                layout = active.layout
            }
            loadImages()
        }
        .sheet(isPresented: $showAddWidget) { addWidgetSheet }
        .sheet(isPresented: $showFilePicker) {
            FilePickerView(layerId: filePickerLayerId, layerType: selectedLayerType) { id, data, url in
                handlePickedFile(layerId: id, data: data, url: url)
            }
        }
        .sheet(isPresented: $showSceneManager) { sceneManagerSheet }
    }

    // MARK: - Scenes Bar

    private var scenesBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sceneCollection.scenes) { scene in
                        Button {
                            switchToScene(scene.id)
                        } label: {
                            Text(scene.name)
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(sceneCollection.activeSceneId == scene.id ? purple : Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Button { showSceneManager = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Canvas

    private var canvasPreview: some View {
        GeometryReader { geo in
            let sz = fitCanvas(in: geo.size)

            ZStack {
                // Dark canvas bg
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.12, green: 0.1, blue: 0.18))
                    .frame(width: sz.width, height: sz.height)

                // Game screen
                let gs = layout.gameScreen
                if gs.width > 0 && gs.height > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                        .foregroundColor(purple.opacity(0.6))
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)))
                        .overlay {
                            Text("Video (\(layout.canvasWidth > layout.canvasHeight ? "Landscape" : "Portrait"))")
                                .font(.caption).foregroundColor(.white.opacity(0.5))
                        }
                        .frame(width: sz.width * gs.width, height: sz.height * gs.height)
                        .position(x: sz.width * (gs.x + gs.width / 2), y: sz.height * (gs.y + gs.height / 2))
                        .gesture(DragGesture().onChanged { v in
                            guard selectedLayerId == nil else { return }
                            layout.gameScreen.x = clamp(v.location.x / sz.width - gs.width / 2, 0, 1 - gs.width)
                            layout.gameScreen.y = clamp(v.location.y / sz.height - gs.height / 2, 0, 1 - gs.height)
                            saveLayout()
                        })
                        .onTapGesture { selectedLayerId = nil }
                }

                // Overlays
                ForEach(layout.overlays.filter(\.visible).sorted { $0.order < $1.order }) { layer in
                    overlayPreview(layer, sz: sz)
                }
            }
            .frame(width: sz.width, height: sz.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(CGFloat(layout.canvasWidth) / CGFloat(layout.canvasHeight), contentMode: .fit)
        .frame(maxHeight: 220)
    }

    @ViewBuilder
    private func overlayPreview(_ layer: SceneLayout.OverlayLayer, sz: CGSize) -> some View {
        let isSel = selectedLayerId == layer.id

        Group {
            switch layer.type {
            case .image, .gif, .video:
                if let img = overlayImages[layer.id] {
                    Image(uiImage: img).resizable()
                        .aspectRatio(contentMode: layer.aspectMode == .stretch ? .fill : layer.aspectMode == .fill ? .fill : .fit)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 3).fill(purple.opacity(0.2))
                        .overlay { Image(systemName: layer.type.icon).font(.caption).foregroundColor(purple) }
                }
            case .text:
                Text(layer.content.isEmpty ? "Text" : layer.content)
                    .font(.system(size: max(sz.height * layer.rect.height * 0.5, 8)))
                    .foregroundColor(.white).padding(2)
                    .background(Color.black.opacity(0.5)).cornerRadius(2)
            case .webURL:
                RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.15))
                    .overlay { Image(systemName: "globe").font(.caption2).foregroundColor(.orange) }
            }
        }
        .opacity(layer.opacity)
        .rotationEffect(.degrees(layer.rotation))
        .frame(width: sz.width * layer.rect.width, height: sz.height * layer.rect.height)
        .border(isSel ? Color.yellow : Color.clear, width: isSel ? 2 : 0)
        .position(x: sz.width * (layer.rect.x + layer.rect.width / 2),
                  y: sz.height * (layer.rect.y + layer.rect.height / 2))
        .onTapGesture { selectedLayerId = layer.id }
        .gesture(layer.locked ? nil : DragGesture().onChanged { v in
            guard let idx = layout.overlays.firstIndex(where: { $0.id == layer.id }) else { return }
            layout.overlays[idx].rect.x = clamp(v.location.x / sz.width - layer.rect.width / 2, 0, 1 - layer.rect.width)
            layout.overlays[idx].rect.y = clamp(v.location.y / sz.height - layer.rect.height / 2, 0, 1 - layer.rect.height)
            saveLayout()
        })
    }

    // MARK: - Layer Editor

    private var layerEditor: some View {
        VStack(spacing: 0) {
            // Tabs: Add / Layers
            HStack {
                Button { showAddWidget = true } label: {
                    Text("Add").font(.caption.bold()).padding(.horizontal, 14).padding(.vertical, 6)
                        .background(purple.opacity(0.3)).foregroundColor(purple).cornerRadius(8)
                }

                Spacer()

                // Game screen size
                HStack(spacing: 4) {
                    Text("Video").font(.caption2).foregroundColor(.gray)
                    Text("\(Int(layout.gameScreen.width * CGFloat(layout.canvasWidth)))x\(Int(layout.gameScreen.height * CGFloat(layout.canvasHeight)))px")
                        .font(.caption2.monospaced()).foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider().background(purple.opacity(0.2))

            // Game screen sliders
            VStack(spacing: 4) {
                sliderRow("W", value: $layout.gameScreen.width, range: 0...1)
                sliderRow("H", value: $layout.gameScreen.height, range: 0...1)
            }.padding(.horizontal, 12).padding(.vertical, 4)

            Divider().background(purple.opacity(0.2))

            // Layer list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(layout.overlays.sorted { $0.order > $1.order }) { layer in
                        layerRow(layer)
                    }
                }.padding(.horizontal, 8).padding(.vertical, 4)
            }.frame(maxHeight: 120)

            // Selected layer properties
            if let selId = selectedLayerId, let idx = layout.overlays.firstIndex(where: { $0.id == selId }) {
                Divider().background(purple.opacity(0.2))
                selectedEditor(idx)
            }
        }
        .background(darkBg)
    }

    private func layerRow(_ layer: SceneLayout.OverlayLayer) -> some View {
        HStack(spacing: 6) {
            Image(systemName: layer.type.icon).font(.caption2).foregroundColor(purple).frame(width: 16)
            Text(layer.name).font(.caption).foregroundColor(.white).lineLimit(1)
            Spacer()
            if layer.locked {
                Image(systemName: "lock.fill").font(.system(size: 9)).foregroundColor(.gray)
            }
            Button { toggleVisibility(layer.id) } label: {
                Image(systemName: layer.visible ? "eye.fill" : "eye.slash").font(.caption2)
                    .foregroundColor(layer.visible ? purple : .gray)
            }
            Button { deleteLayer(layer.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9)).foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .background(selectedLayerId == layer.id ? purple.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .onTapGesture { selectedLayerId = layer.id }
    }

    // MARK: - Selected Layer Editor

    private func selectedEditor(_ idx: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                let layer = layout.overlays[idx]

                // Header
                HStack {
                    Text(layer.name).font(.caption.bold()).foregroundColor(.white)
                    Spacer()
                    // Locked toggle
                    Button {
                        layout.overlays[idx].locked.toggle(); saveLayout()
                    } label: {
                        Image(systemName: layout.overlays[idx].locked ? "lock.fill" : "lock.open")
                            .font(.caption).foregroundColor(layout.overlays[idx].locked ? .orange : .gray)
                    }
                }

                // Visible
                Toggle("Visible", isOn: $layout.overlays[idx].visible)
                    .font(.caption).foregroundColor(.white)
                    .onChange(of: layout.overlays[idx].visible) { _, _ in saveLayout() }

                // Content picker
                contentPicker(idx: idx, layer: layer)

                // Aspect mode (image/gif/video)
                if [.image, .gif, .video].contains(layer.type) {
                    HStack(spacing: 0) {
                        ForEach(SceneLayout.AspectMode.allCases, id: \.self) { mode in
                            Button {
                                layout.overlays[idx].aspectMode = mode; saveLayout()
                            } label: {
                                Text(mode.displayName).font(.caption2)
                                    .frame(maxWidth: .infinity).padding(.vertical, 5)
                                    .background(layout.overlays[idx].aspectMode == mode ? purple : Color.white.opacity(0.08))
                                    .foregroundColor(.white)
                            }
                        }
                    }.cornerRadius(6)
                }

                // Position X / Y
                sliderRow("Pos X", value: $layout.overlays[idx].rect.x, range: 0...1)
                sliderRow("Pos Y", value: $layout.overlays[idx].rect.y, range: 0...1)

                // Size
                Text("Size \(Int(layer.rect.width * CGFloat(layout.canvasWidth)))x\(Int(layer.rect.height * CGFloat(layout.canvasHeight)))px")
                    .font(.caption2).foregroundColor(.gray)
                sliderRow("Width", value: $layout.overlays[idx].rect.width, range: 0.02...1)
                sliderRow("Height", value: $layout.overlays[idx].rect.height, range: 0.02...1)

                // Opacity
                sliderRow("Opacity", value: $layout.overlays[idx].opacity, range: 0.1...1)

                // Rotate
                HStack {
                    Text("Rotate").font(.caption2).foregroundColor(.gray).frame(width: 50, alignment: .leading)
                    Slider(value: $layout.overlays[idx].rotation, in: -180...180, step: 1)
                        .tint(purple)
                        .onChange(of: layout.overlays[idx].rotation) { _, _ in saveLayout() }
                    Text("\(Int(layout.overlays[idx].rotation))°")
                        .font(.caption2.monospaced()).foregroundColor(.white).frame(width: 35)
                }

                // Remove
                Button(role: .destructive) { deleteLayer(layer.id) } label: {
                    Text("Remove").font(.caption).frame(maxWidth: .infinity)
                        .padding(.vertical, 8).background(Color.red.opacity(0.15))
                        .foregroundColor(.red).cornerRadius(8)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
    }

    @ViewBuilder
    private func contentPicker(idx: Int, layer: SceneLayout.OverlayLayer) -> some View {
        switch layer.type {
        case .text:
            TextField("Text", text: $layout.overlays[idx].content)
                .textFieldStyle(.roundedBorder).font(.caption)
                .onChange(of: layout.overlays[idx].content) { _, _ in saveLayout() }
        case .webURL:
            TextField("URL (StreamElements, etc.)", text: $layout.overlays[idx].content)
                .textFieldStyle(.roundedBorder).font(.caption)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .onChange(of: layout.overlays[idx].content) { _, _ in saveLayout() }
        case .image:
            photoPicker(for: layer, label: "Choose Image")
        case .gif:
            HStack(spacing: 6) {
                photoPicker(for: layer, label: "From Photos")
                Button { filePickerLayerId = layer.id; showFilePicker = true } label: {
                    Label("Files", systemImage: "folder").font(.caption2).padding(.horizontal, 8).padding(.vertical, 5)
                        .background(purple.opacity(0.2)).foregroundColor(purple).cornerRadius(6)
                }
            }
        case .video:
            Button { filePickerLayerId = layer.id; showFilePicker = true } label: {
                Label("Choose Video", systemImage: "film").font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(purple.opacity(0.2)).foregroundColor(purple).cornerRadius(6)
            }
        }
    }

    private func photoPicker(for layer: SceneLayout.OverlayLayer, label: String) -> some View {
        PhotosPicker(selection: Binding(
            get: { selectedPhotoItem },
            set: { item in
                selectedPhotoItem = item
                imagePickerLayerId = layer.id
                if layer.type == .gif { loadPickedGIF() } else { loadPickedImage() }
            }
        ), matching: .images) {
            Label(label, systemImage: "photo").font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(purple.opacity(0.2)).foregroundColor(purple).cornerRadius(6)
        }
    }

    // MARK: - Slider Row

    private func sliderRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundColor(.gray).frame(width: 50, alignment: .leading)
            Slider(value: value, in: range, step: 0.01).tint(purple)
                .onChange(of: value.wrappedValue) { _, _ in saveLayout() }
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption2.monospaced()).foregroundColor(.white).frame(width: 35)
        }
    }

    // MARK: - Add Widget Sheet

    private var addWidgetSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SceneLayout.LayerType.allCases) { type in
                        Button {
                            addLayer(type: type)
                            showAddWidget = false
                        } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                }
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { showAddWidget = false } }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Scene Manager

    private var sceneManagerSheet: some View {
        NavigationStack {
            List {
                ForEach(sceneCollection.scenes) { scene in
                    HStack {
                        Text(scene.name).foregroundColor(.white)
                        Spacer()
                        if sceneCollection.activeSceneId == scene.id {
                            Image(systemName: "checkmark").foregroundColor(purple)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { switchToScene(scene.id); showSceneManager = false }
                }
                .onDelete { indexSet in
                    sceneCollection.scenes.remove(atOffsets: indexSet)
                    SceneLayoutStore.saveScenes(sceneCollection)
                }
            }
            .navigationTitle("Scenes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { showSceneManager = false } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        let scene = BroadcastScene(name: "Scene \(sceneCollection.scenes.count + 1)")
                        sceneCollection.scenes.append(scene)
                        SceneLayoutStore.saveScenes(sceneCollection)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func switchToScene(_ id: UUID) {
        // Save current layout to current scene
        if let activeId = sceneCollection.activeSceneId,
           let idx = sceneCollection.scenes.firstIndex(where: { $0.id == activeId }) {
            sceneCollection.scenes[idx].layout = layout
        }

        sceneCollection.activeSceneId = id
        if let scene = sceneCollection.scenes.first(where: { $0.id == id }) {
            layout = scene.layout
        }
        SceneLayoutStore.saveScenes(sceneCollection)
        loadImages()
    }

    private func addLayer(type: SceneLayout.LayerType) {
        let layer = SceneLayout.OverlayLayer(
            type: type, name: "\(type.displayName) \(layout.overlays.count + 1)",
            rect: .init(x: 0.3, y: 0.3, width: 0.2, height: 0.2),
            order: layout.overlays.count
        )
        layout.overlays.append(layer)
        selectedLayerId = layer.id
        saveLayout()
    }

    private func toggleVisibility(_ id: UUID) {
        if let idx = layout.overlays.firstIndex(where: { $0.id == id }) {
            layout.overlays[idx].visible.toggle(); saveLayout()
        }
    }

    private func deleteLayer(_ id: UUID) {
        layout.overlays.removeAll { $0.id == id }
        if selectedLayerId == id { selectedLayerId = nil }
        saveLayout()
    }

    private func saveLayout() {
        SceneLayoutStore.save(layout)
        if let activeId = sceneCollection.activeSceneId,
           let idx = sceneCollection.scenes.firstIndex(where: { $0.id == activeId }) {
            sceneCollection.scenes[idx].layout = layout
            SceneLayoutStore.saveScenes(sceneCollection)
        }
        onSave(layout)
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

    private var selectedLayerType: SceneLayout.LayerType {
        guard let id = filePickerLayerId, let l = layout.overlays.first(where: { $0.id == id }) else { return .gif }
        return l.type
    }

    private func fitCanvas(in size: CGSize) -> CGSize {
        let a = CGFloat(layout.canvasWidth) / CGFloat(layout.canvasHeight)
        let w = min(size.width, size.height * a)
        return CGSize(width: w, height: w / a)
    }

    // MARK: - Image Loading

    private func loadImages() {
        for layer in layout.overlays {
            switch layer.type {
            case .image:
                if let img = SceneLayoutStore.loadOverlayImage(id: layer.id) { overlayImages[layer.id] = img }
            case .gif:
                if let data = SceneLayoutStore.loadGIFData(id: layer.id),
                   let src = CGImageSourceCreateWithData(data as CFData, nil),
                   CGImageSourceGetCount(src) > 0,
                   let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                    overlayImages[layer.id] = UIImage(cgImage: cg)
                }
            case .video:
                if let url = SceneLayoutStore.videoURL(id: layer.id) {
                    let gen = AVAssetImageGenerator(asset: AVAsset(url: url))
                    gen.appliesPreferredTrackTransform = true
                    if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                        overlayImages[layer.id] = UIImage(cgImage: cg)
                    }
                }
            default: break
            }
        }
    }

    private func loadPickedImage() {
        guard let item = selectedPhotoItem, let layerId = imagePickerLayerId else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                overlayImages[layerId] = image
                SceneLayoutStore.saveOverlayImage(image, id: layerId)
                if let idx = layout.overlays.firstIndex(where: { $0.id == layerId }) {
                    layout.overlays[idx].content = "overlay_\(layerId.uuidString).png"
                }
                saveLayout()
            }
        }
    }

    private func loadPickedGIF() {
        guard let item = selectedPhotoItem, let layerId = imagePickerLayerId else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let isGIF = data.count > 4 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46
                if isGIF {
                    SceneLayoutStore.saveGIF(data, id: layerId)
                    if let src = CGImageSourceCreateWithData(data as CFData, nil),
                       let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                        overlayImages[layerId] = UIImage(cgImage: cg)
                    }
                } else if let image = UIImage(data: data) {
                    overlayImages[layerId] = image
                    if let png = image.pngData() { SceneLayoutStore.saveGIF(png, id: layerId) }
                }
                if let idx = layout.overlays.firstIndex(where: { $0.id == layerId }) {
                    layout.overlays[idx].content = "overlay_\(layerId.uuidString).gif"
                }
                saveLayout()
            }
        }
    }

    private func handlePickedFile(layerId: UUID, data: Data?, url: URL?) {
        guard let idx = layout.overlays.firstIndex(where: { $0.id == layerId }) else { return }
        if layout.overlays[idx].type == .gif, let data = data {
            SceneLayoutStore.saveGIF(data, id: layerId)
            if let src = CGImageSourceCreateWithData(data as CFData, nil),
               let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                overlayImages[layerId] = UIImage(cgImage: cg)
            }
            layout.overlays[idx].content = "overlay_\(layerId.uuidString).gif"
            saveLayout()
        } else if layout.overlays[idx].type == .video, let url = url {
            if SceneLayoutStore.saveVideo(from: url, id: layerId) {
                let gen = AVAssetImageGenerator(asset: AVAsset(url: url))
                gen.appliesPreferredTrackTransform = true
                if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                    overlayImages[layerId] = UIImage(cgImage: cg)
                }
                layout.overlays[idx].content = "overlay_\(layerId.uuidString).mp4"
                saveLayout()
            }
        }
    }
}

// MARK: - File Picker

struct FilePickerView: UIViewControllerRepresentable {
    let layerId: UUID?
    let layerType: SceneLayout.LayerType
    let onPick: (UUID, Data?, URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = layerType == .gif ? [.gif] : [.movie, .video, .mpeg4Movie]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerView
        init(_ p: FilePickerView) { parent = p }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, let id = parent.layerId else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if parent.layerType == .gif {
                parent.onPick(id, try? Data(contentsOf: url), nil)
            } else {
                parent.onPick(id, nil, url)
            }
        }
    }
}
