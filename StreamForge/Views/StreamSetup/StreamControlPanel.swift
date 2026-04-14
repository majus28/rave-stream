import SwiftUI
import PhotosUI

/// Control panel shown during a live broadcast.
/// Controls overlays, BRB screen, etc. via App Group (shared with extension).
struct StreamControlPanel: View {
    @State private var isBRBActive = false
    @State private var overlayText = ""
    @State private var overlayTextPosition = "bottom"
    @State private var isTextOverlayEnabled = false
    @State private var isImageOverlayEnabled = false
    @State private var imageOverlayPosition = "topRight"

    // BRB image picker
    @State private var brbImageItem: PhotosPickerItem?
    @State private var brbPreviewImage: UIImage?

    // Logo/watermark picker
    @State private var logoImageItem: PhotosPickerItem?
    @State private var logoPreviewImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            // BRB Section
            brbSection

            // Text Overlay
            textOverlaySection

            // Image Overlay (Logo)
            imageOverlaySection
        }
        .onAppear { loadCurrentConfig() }
    }

    // MARK: - BRB Screen

    private var brbSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pause.rectangle.fill")
                    .foregroundColor(isBRBActive ? .orange : .gray)
                Text("Break Screen (BRB)")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isBRBActive)
                    .labelsHidden()
                    .onChange(of: isBRBActive) { _, active in
                        BroadcastOverlayConfig.setBRBActive(active)
                    }
            }

            if isBRBActive {
                Text("Viewers see a 'Be Right Back' screen instead of your screen")
                    .font(.caption).foregroundColor(.orange)
            }

            // Custom BRB image
            HStack(spacing: 12) {
                if let img = brbPreviewImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5).opacity(0.3))
                        .frame(width: 80, height: 45)
                        .overlay {
                            Text("BRB").font(.caption2).foregroundColor(.gray)
                        }
                }

                PhotosPicker(selection: $brbImageItem, matching: .images) {
                    Text("Custom BRB Image")
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                }
            }
            .onChange(of: brbImageItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        brbPreviewImage = image
                        BroadcastOverlayConfig.saveBRBImage(image)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Text Overlay

    private var textOverlaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(isTextOverlayEnabled ? .blue : .gray)
                Text("Text Overlay")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isTextOverlayEnabled)
                    .labelsHidden()
                    .onChange(of: isTextOverlayEnabled) { _, enabled in
                        if enabled {
                            BroadcastOverlayConfig.setTextOverlay(text: overlayText, position: overlayTextPosition)
                        } else {
                            BroadcastOverlayConfig.clearTextOverlay()
                        }
                    }
            }

            if isTextOverlayEnabled {
                TextField("Overlay text...", text: $overlayText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: overlayText) { _, text in
                        BroadcastOverlayConfig.setTextOverlay(text: text, position: overlayTextPosition)
                    }

                Picker("Position", selection: $overlayTextPosition) {
                    Text("Top").tag("top")
                    Text("Center").tag("center")
                    Text("Bottom").tag("bottom")
                }
                .pickerStyle(.segmented)
                .onChange(of: overlayTextPosition) { _, pos in
                    BroadcastOverlayConfig.setTextOverlay(text: overlayText, position: pos)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Image Overlay (Logo/Watermark)

    private var imageOverlaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.badge.plus")
                    .foregroundColor(isImageOverlayEnabled ? .purple : .gray)
                Text("Logo / Watermark")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $isImageOverlayEnabled)
                    .labelsHidden()
                    .onChange(of: isImageOverlayEnabled) { _, enabled in
                        BroadcastOverlayConfig.setOverlayImageEnabled(enabled, position: imageOverlayPosition)
                    }
            }

            HStack(spacing: 12) {
                if let img = logoPreviewImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                PhotosPicker(selection: $logoImageItem, matching: .images) {
                    Text(logoPreviewImage == nil ? "Choose Logo" : "Change Logo")
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
            }
            .onChange(of: logoImageItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        logoPreviewImage = image
                        BroadcastOverlayConfig.saveOverlayImage(image)
                        BroadcastOverlayConfig.setOverlayImageEnabled(isImageOverlayEnabled, position: imageOverlayPosition)
                    }
                }
            }

            if isImageOverlayEnabled {
                Picker("Position", selection: $imageOverlayPosition) {
                    Image(systemName: "arrow.up.left").tag("topLeft")
                    Image(systemName: "arrow.up.right").tag("topRight")
                    Image(systemName: "arrow.down.left").tag("bottomLeft")
                    Image(systemName: "arrow.down.right").tag("bottomRight")
                }
                .pickerStyle(.segmented)
                .onChange(of: imageOverlayPosition) { _, pos in
                    BroadcastOverlayConfig.setOverlayImageEnabled(true, position: pos)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }

    // MARK: - Load Config

    private func loadCurrentConfig() {
        isBRBActive = BroadcastOverlayConfig.isBRBActive()
        brbPreviewImage = BroadcastOverlayConfig.loadBRBImage()

        let textConfig = BroadcastOverlayConfig.getTextOverlay()
        overlayText = textConfig.text
        overlayTextPosition = textConfig.position
        isTextOverlayEnabled = textConfig.enabled

        let imgConfig = BroadcastOverlayConfig.getOverlayImageConfig()
        isImageOverlayEnabled = imgConfig.enabled
        imageOverlayPosition = imgConfig.position
        logoPreviewImage = BroadcastOverlayConfig.loadOverlayImage()
    }
}
