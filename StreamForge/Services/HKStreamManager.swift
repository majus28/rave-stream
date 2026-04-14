import Foundation
import AVFoundation
import VideoToolbox
import ReplayKit
import HaishinKit
import RTMPHaishinKit
import Combine

/// RTMP streaming via HaishinKit — screen capture + audio.
@MainActor
final class HKStreamManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isPublishing: Bool = false
    @Published var currentFPS: Int = 0
    @Published var currentBitrate: Int = 0
    @Published var error: String?
    @Published var isScreenCaptureActive: Bool = false

    // Non-published counters — updated from background threads safely
    nonisolated(unsafe) var videoFramesSent: Int = 0
    nonisolated(unsafe) var audioFramesSent: Int = 0

    private var rtmpConnection: RTMPHaishinKit.RTMPConnection?
    private var rtmpStream: RTMPHaishinKit.RTMPStream?
    private var mediaMixer: MediaMixer?
    private var metricsTimer: Timer?
    private var screenRecorder: RPScreenRecorder?

    init() {}

    func startPublishing(
        url: String, streamKey: String,
        resolution: StreamResolution, fps: StreamFPS,
        bitrate: Int, captureMode: CaptureMode, orientation: StreamOrientation
    ) async {
        StreamLogger.log(.rtmp, "HK: === START (screen + audio) ===")
        StreamLogger.log(.rtmp, "HK: URL=\(url)")
        StreamLogger.log(.rtmp, "HK: Key=\(String(streamKey.prefix(8)))...")

        do {
            // Request permissions based on mode
            if captureMode == .screen {
                try await Self.requestMicPermission()
            } else {
                try await Self.requestCameraAndMicPermission()
            }

            let connection = RTMPHaishinKit.RTMPConnection()
            let stream = RTMPHaishinKit.RTMPStream(connection: connection)

            let width = orientation == .portrait ? resolution.height : resolution.width
            let height = orientation == .portrait ? resolution.width : resolution.height

            StreamLogger.log(.encode, "HK: Video \(width)x\(height) \(bitrate)kbps")
            try await stream.setVideoSettings(VideoCodecSettings(
                videoSize: CGSize(width: width, height: height),
                bitRate: bitrate * 1000,
                profileLevel: kVTProfileLevel_H264_Main_AutoLevel as String,
                maxKeyFrameIntervalDuration: 2
            ))
            try await stream.setAudioSettings(AudioCodecSettings(bitRate: 128000))

            // Create MediaMixer — NO camera, screen frames via append()
            let mixer = MediaMixer()

            // Attach mic for audio
            if let mic = AVCaptureDevice.default(for: .audio) {
                try await mixer.attachAudio(mic)
                StreamLogger.log(.audio, "HK: Mic attached")
            }

            // Connect mixer → stream
            await mixer.addOutput(stream)

            // === KEY: Start the mixer's internal pipeline ===
            await mixer.startRunning()
            StreamLogger.log(.stream, "HK: Mixer started running!")

            self.rtmpConnection = connection
            self.rtmpStream = stream
            self.mediaMixer = mixer
            self.videoFramesSent = 0
            self.audioFramesSent = 0

            // Start capture based on mode
            if captureMode == .screen {
                StreamLogger.log(.capture, "HK: Starting screen capture...")
                try await startScreenCapture(mixer: mixer)
                StreamLogger.log(.capture, "HK: Waiting for frames...")
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } else {
                // Camera mode — attach camera directly to mixer
                let position: AVCaptureDevice.Position = captureMode == .rearCamera ? .back : .front
                if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
                    try await mixer.attachVideo(camera)
                    StreamLogger.log(.capture, "HK: Camera attached (\(position == .front ? "front" : "rear"))")
                }
                await mixer.startRunning()
                StreamLogger.log(.capture, "HK: Mixer running with camera")
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }

            // NOW connect RTMP — frames are already being produced
            StreamLogger.log(.rtmp, "HK: Connecting RTMP...")
            let cr = try await connection.connect(url)
            isConnected = true
            StreamLogger.log(.rtmp, "HK: Connected: \(cr)")

            // Publish
            StreamLogger.log(.rtmp, "HK: Publishing...")
            let pr = try await stream.publish(streamKey)
            isPublishing = true
            StreamLogger.log(.rtmp, "HK: Published: \(pr)")

            // Check FPS
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let curFps = await stream.currentFPS
            StreamLogger.log(.stream, "HK: FPS after publish = \(curFps)")
            StreamLogger.log(.stream, "HK: === STREAMING (screen + audio) ===")

            startMetricsTracking()

        } catch {
            StreamLogger.log(.rtmp, "HK: FAILED: \(error)")
            self.error = error.localizedDescription
            isConnected = false
            isPublishing = false
        }
    }

    func stopPublishing() async {
        StreamLogger.log(.rtmp, "HK: Stopping (V=\(videoFramesSent) A=\(audioFramesSent))")
        metricsTimer?.invalidate()
        metricsTimer = nil
        stopScreenCapture()

        if let mixer = mediaMixer {
            try? await mixer.attachAudio(nil)
            await mixer.stopRunning()
        }
        if let s = rtmpStream { _ = try? await s.close() }
        if let c = rtmpConnection { try? await c.close() }

        rtmpStream = nil
        rtmpConnection = nil
        mediaMixer = nil
        isConnected = false
        isPublishing = false
        isScreenCaptureActive = false
    }

    func setMicMuted(_ muted: Bool) {
        Task {
            if muted { try? await mediaMixer?.attachAudio(nil) }
            else if let mic = AVCaptureDevice.default(for: .audio) { try? await mediaMixer?.attachAudio(mic) }
        }
    }

    func updateBitrate(_ kbps: Int) {
        Task { try? await rtmpStream?.setVideoSettings(VideoCodecSettings(bitRate: kbps * 1000)) }
    }

    func switchCamera() {
        Task {
            guard let mixer = mediaMixer else { return }
            // Toggle between front and back
            let positions: [AVCaptureDevice.Position] = [.front, .back]
            for pos in positions {
                if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos) {
                    try? await mixer.attachVideo(cam)
                    StreamLogger.log(.capture, "HK: Camera switched to \(pos == .front ? "front" : "rear")")
                    break
                }
            }
        }
    }

    // MARK: - Screen Capture → MediaMixer.append()

    private func startScreenCapture(mixer: MediaMixer) async throws {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else { throw CaptureError.screenCaptureUnavailable }

        recorder.isMicrophoneEnabled = true
        screenRecorder = recorder

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.startCapture(handler: { [weak self, weak mixer] sampleBuffer, bufferType, error in
                if error != nil { return }
                guard let self = self, let mixer = mixer else { return }

                switch bufferType {
                case .video:
                    mixer.append(sampleBuffer)
                    self.videoFramesSent += 1
                    if self.videoFramesSent == 1 {
                        StreamLogger.log(.capture, "HK: First SCREEN frame → mixer!")
                    }
                    if self.videoFramesSent % 300 == 0 {
                        StreamLogger.log(.perf, "HK: V=\(self.videoFramesSent) A=\(self.audioFramesSent)")
                    }

                case .audioApp:
                    mixer.append(sampleBuffer)
                    self.audioFramesSent += 1
                    if self.audioFramesSent == 1 {
                        StreamLogger.log(.audio, "HK: First APP AUDIO → mixer!")
                    }

                case .audioMic:
                    // Mic already attached directly to mixer
                    break

                @unknown default: break
                }
            }) { error in
                if let error = error {
                    StreamLogger.log(.capture, "HK: ReplayKit FAILED: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    StreamLogger.log(.capture, "HK: ReplayKit started!")
                    continuation.resume()
                }
            }
        }

        await MainActor.run { isScreenCaptureActive = true }
    }

    private func stopScreenCapture() {
        guard let r = screenRecorder, r.isRecording else { screenRecorder = nil; return }
        r.stopCapture { _ in }
        screenRecorder = nil
    }

    // MARK: - Permissions

    private static func requestMicPermission() async throws {
        let s = AVCaptureDevice.authorizationStatus(for: .audio)
        if s == .notDetermined { if !(await AVCaptureDevice.requestAccess(for: .audio)) { throw Err.mic } }
        else if s == .denied || s == .restricted { throw Err.mic }
    }

    private static func requestCameraAndMicPermission() async throws {
        let vs = AVCaptureDevice.authorizationStatus(for: .video)
        if vs == .notDetermined { if !(await AVCaptureDevice.requestAccess(for: .video)) { throw Err.cam } }
        else if vs == .denied || vs == .restricted { throw Err.cam }
        try await requestMicPermission()
    }

    enum Err: LocalizedError {
        case mic, cam
        var errorDescription: String? {
            switch self {
            case .mic: return "Mic access denied. Go to Settings > StreamForge."
            case .cam: return "Camera access denied. Go to Settings > StreamForge."
            }
        }
    }
    enum CaptureError: LocalizedError {
        case screenCaptureUnavailable
        var errorDescription: String? { "Screen capture unavailable on this device" }
    }

    // MARK: - Metrics

    private func startMetricsTracking() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if let s = self.rtmpStream {
                    let info = await s.info
                    self.currentBitrate = info.currentBytesPerSecond * 8 / 1000
                    self.currentFPS = Int(await s.currentFPS)
                }
            }
        }
    }
}
