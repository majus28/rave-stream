import Foundation
import UIKit

/// Shared overlay/BRB config between main app and Broadcast Extension via App Group.
enum BroadcastOverlayConfig {
    static let appGroupId = "group.com.majuz.streamforge"

    // MARK: - BRB Screen

    static func setBRBActive(_ active: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(active, forKey: "brb_active")
        defaults.synchronize()
    }

    static func isBRBActive() -> Bool {
        UserDefaults(suiteName: appGroupId)?.bool(forKey: "brb_active") ?? false
    }

    /// Save a BRB image to the shared App Group container
    static func saveBRBImage(_ image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        let fileURL = containerURL.appendingPathComponent("brb_image.jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }

    static func loadBRBImage() -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
        let fileURL = containerURL.appendingPathComponent("brb_image.jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Text Overlay

    static func setTextOverlay(text: String, position: String = "bottom") {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(text, forKey: "overlay_text")
        defaults.set(position, forKey: "overlay_text_position") // "top", "bottom", "center"
        defaults.set(true, forKey: "overlay_text_enabled")
        defaults.synchronize()
    }

    static func clearTextOverlay() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set("", forKey: "overlay_text")
        defaults.set(false, forKey: "overlay_text_enabled")
        defaults.synchronize()
    }

    static func getTextOverlay() -> (text: String, position: String, enabled: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return ("", "bottom", false) }
        return (
            defaults.string(forKey: "overlay_text") ?? "",
            defaults.string(forKey: "overlay_text_position") ?? "bottom",
            defaults.bool(forKey: "overlay_text_enabled")
        )
    }

    // MARK: - Image Overlay (logo/watermark)

    static func saveOverlayImage(_ image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        let fileURL = containerURL.appendingPathComponent("overlay_image.png")
        if let data = image.pngData() {
            try? data.write(to: fileURL)
        }
    }

    static func setOverlayImageEnabled(_ enabled: Bool, position: String = "topRight") {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        defaults.set(enabled, forKey: "overlay_image_enabled")
        defaults.set(position, forKey: "overlay_image_position") // "topLeft", "topRight", "bottomLeft", "bottomRight"
        defaults.synchronize()
    }

    static func loadOverlayImage() -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
        let fileURL = containerURL.appendingPathComponent("overlay_image.png")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func getOverlayImageConfig() -> (enabled: Bool, position: String) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return (false, "topRight") }
        return (defaults.bool(forKey: "overlay_image_enabled"), defaults.string(forKey: "overlay_image_position") ?? "topRight")
    }

    // MARK: - Clear All

    static func clearAll() {
        setBRBActive(false)
        clearTextOverlay()
        setOverlayImageEnabled(false)
    }
}
