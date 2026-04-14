import Foundation
import AVFoundation
import ReplayKit
import UIKit
import Combine

/// Legacy capture service — kept for dependency compatibility.
/// Actual capture is handled by HaishinKit (in-app) or Broadcast Extension (system-wide).
final class CaptureService: NSObject, ObservableObject {
    @Published var isMicEnabled: Bool = true
    @Published var currentCaptureMode: CaptureMode = .screen
    @Published var isCapturing: Bool = false
    @Published var isPaused: Bool = false
    @Published var isOrientationLocked: Bool = false

    var onVideoSampleBuffer: ((CMSampleBuffer) -> Void)?
    var onAudioSampleBuffer: ((CMSampleBuffer) -> Void)?
    var onFrameDropped: (() -> Void)?

    func startCapture(mode: CaptureMode) async throws {
        currentCaptureMode = mode
        isCapturing = true
    }

    func stopCapture() {
        isCapturing = false
        isPaused = false
    }

    func toggleMic() { isMicEnabled.toggle() }
    func pauseStream() { isPaused = true }
    func resumeStream() { isPaused = false }
    func lockOrientation(_ locked: Bool) { isOrientationLocked = locked }
}
