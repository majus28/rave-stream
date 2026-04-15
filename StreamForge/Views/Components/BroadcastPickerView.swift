import SwiftUI
import ReplayKit

/// Full-size tappable broadcast picker that shows iOS system broadcast dialog.
struct BroadcastPickerView: UIViewRepresentable {
    let extensionBundleId = "com.majuz.streamforge.broadcast"

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))

        let picker = RPSystemBroadcastPickerView(frame: containerView.bounds)
        picker.preferredExtension = extensionBundleId
        picker.showsMicrophoneButton = false
        picker.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Make the internal button fill the entire view
        if let button = picker.subviews.compactMap({ $0 as? UIButton }).first {
            button.imageView?.tintColor = .white
            // Make button fill the container
            button.frame = picker.bounds
            button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        containerView.addSubview(picker)
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Helper to save RTMP config to shared App Group for the extension to read
enum BroadcastConfig {
    static let appGroupId = "group.com.majuz.streamforge"

    static func save(url: String, streamKey: String, bitrate: Int, width: Int, height: Int, fps: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            StreamLogger.log(.stream, "BroadcastConfig: FAILED to access App Group!")
            return
        }
        defaults.set(url, forKey: "rtmp_url")
        defaults.set(streamKey, forKey: "rtmp_stream_key")
        defaults.set(bitrate, forKey: "rtmp_bitrate")
        defaults.set(width, forKey: "rtmp_width")
        defaults.set(height, forKey: "rtmp_height")
        defaults.set(fps, forKey: "rtmp_fps")
        defaults.synchronize()
        StreamLogger.log(.stream, "BroadcastConfig: Saved (\(url), \(width)x\(height)@\(fps)fps \(bitrate)kbps)")

        // Verify it was saved
        let check = defaults.string(forKey: "rtmp_url")
        StreamLogger.log(.stream, "BroadcastConfig: Verify read back = \(check ?? "nil")")
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.removeObject(forKey: "rtmp_url")
        defaults.removeObject(forKey: "rtmp_stream_key")
        defaults.removeObject(forKey: "rtmp_bitrate")
        defaults.removeObject(forKey: "rtmp_width")
        defaults.removeObject(forKey: "rtmp_height")
        defaults.removeObject(forKey: "rtmp_fps")
    }
}
