import ReplayKit
import VideoToolbox
import AVFoundation
import CoreMedia
import CoreImage
import HaishinKit
import RTMPHaishinKit

/// Broadcast Upload Extension — full phone screen capture with overlays.
/// Optimized for minimal frame drops.
class SampleHandler: RPBroadcastSampleHandler {

    private var rtmpConnection: RTMPConnection?
    private var rtmpStream: RTMPStream?
    private var mediaMixer: MediaMixer?
    private var isReady = false
    private var videoFrameCount = 0
    private var audioFrameCount = 0
    private let frameProcessor = FrameProcessor()

    // H.264 encoder
    private var compressionSession: VTCompressionSession?
    private var isLandscape = false
    private var encoderWidth: Int32 = 1280
    private var encoderHeight: Int32 = 720

    // Frame pacing — target 24fps, skip excess frames
    private let videoProcessingQueue = DispatchQueue(label: "com.streamforge.broadcast.video", qos: .userInitiated)
    private var isProcessingFrame = false
    private var lastFrameTime: CFTimeInterval = 0
    private let targetFrameInterval: CFTimeInterval = 1.0 / 24.0  // 24fps
    private var skippedFrames = 0
    private var consecutiveSkips = 0

    static let appGroupId = "group.com.majuz.streamforge"

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        log("========= BROADCAST STARTED =========")

        let defaults = UserDefaults(suiteName: Self.appGroupId)
        let url = defaults?.string(forKey: "rtmp_url") ?? ""
        let streamKey = defaults?.string(forKey: "rtmp_stream_key") ?? ""
        let bitrate = max(defaults?.integer(forKey: "rtmp_bitrate") ?? 2500, 1000)
        let savedWidth = max(defaults?.integer(forKey: "rtmp_width") ?? 1280, 480)
        let savedHeight = max(defaults?.integer(forKey: "rtmp_height") ?? 720, 480)

        isLandscape = savedWidth > savedHeight
        encoderWidth = Int32(isLandscape ? max(savedWidth, savedHeight) : min(savedWidth, savedHeight))
        encoderHeight = Int32(isLandscape ? min(savedWidth, savedHeight) : max(savedWidth, savedHeight))

        log("Encoder: \(encoderWidth)x\(encoderHeight) @ \(bitrate)kbps, landscape=\(isLandscape)")
        frameProcessor.forceRotateToLandscape = isLandscape

        guard !url.isEmpty, !streamKey.isEmpty else {
            log("ERROR: No RTMP config!")
            finishBroadcastWithError(NSError(domain: "StreamForge", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Open StreamForge and create a YouTube event first."]))
            return
        }

        // H.264 encoder — use Baseline for speed
        setupEncoder(width: encoderWidth, height: encoderHeight, bitrate: bitrate)

        Task {
            do {
                let connection = RTMPConnection()
                let stream = RTMPStream(connection: connection)

                try await stream.setVideoSettings(VideoCodecSettings(
                    videoSize: CGSize(width: Int(encoderWidth), height: Int(encoderHeight)),
                    bitRate: bitrate * 1000,
                    profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
                    maxKeyFrameIntervalDuration: 2
                ))
                try await stream.setAudioSettings(AudioCodecSettings(bitRate: 128000))

                let mixer = MediaMixer()
                await mixer.addOutput(stream)
                await mixer.startRunning()

                self.rtmpConnection = connection
                self.rtmpStream = stream
                self.mediaMixer = mixer

                try await Task.sleep(nanoseconds: 1_000_000_000)

                log("Connecting RTMP...")
                _ = try await connection.connect(url)
                log("Connected!")

                _ = try await stream.publish(streamKey)
                log("Published!")

                self.isReady = true
            } catch {
                log("FAILED: \(error)")
                self.finishBroadcastWithError(NSError(domain: "StreamForge", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Stream failed: \(error.localizedDescription)"]))
            }
        }
    }

    override func broadcastPaused() { log("Paused") }
    override func broadcastResumed() { log("Resumed") }

    override func broadcastFinished() {
        log("Finished (V=\(videoFrameCount) A=\(audioFrameCount))")
        isReady = false
        destroyEncoder()
        Task {
            if let m = mediaMixer { await m.stopRunning() }
            if let s = rtmpStream { _ = try? await s.close() }
            if let c = rtmpConnection { try? await c.close() }
        }
        rtmpStream = nil; rtmpConnection = nil; mediaMixer = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard isReady else { return }

        switch sampleBufferType {
        case .video:
            videoFrameCount += 1

            // Frame pacing: skip if too soon or still processing
            let now = CACurrentMediaTime()
            guard now - lastFrameTime >= targetFrameInterval else { return }

            if isProcessingFrame {
                // Previous frame still processing — drop this one
                skippedFrames += 1
                consecutiveSkips += 1

                // If we're consistently dropping, disable overlays to reduce CPU
                if consecutiveSkips > 10 {
                    frameProcessor.forceSkipOverlays = true
                    if consecutiveSkips == 11 { log("Adaptive: disabling overlays due to frame drops") }
                }
                return
            }

            consecutiveSkips = 0
            lastFrameTime = now
            isProcessingFrame = true

            let count = videoFrameCount
            videoProcessingQueue.async { [weak self] in
                guard let self else { return }
                self.processVideoFrame(sampleBuffer)
                self.isProcessingFrame = false
                if count == 1 { self.log("First VIDEO frame!") }
                if count % 300 == 0 { self.log("V=\(count) A=\(self.audioFrameCount) skip=\(self.skippedFrames)") }
            }

        case .audioApp, .audioMic:
            if let mixer = mediaMixer {
                Task { await mixer.append(sampleBuffer) }
            }
            audioFrameCount += 1

        @unknown default: break
        }
    }

    // MARK: - Video Processing

    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let session = compressionSession else { return }
        guard let srcBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let dur = CMSampleBufferGetDuration(sampleBuffer)

        // ZERO-COST PATH: no overlays, no BRB, game fullscreen — encode raw buffer directly
        if frameProcessor.canSkipProcessing {
            // Just encode the raw ReplayKit frame — no CoreImage, no CoreGraphics, no copies
            VTCompressionSessionEncodeFrame(session, imageBuffer: srcBuffer,
                presentationTimeStamp: pts, duration: dur,
                frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
            return
        }

        // OVERLAY PATH: process frame (compositing needed)
        let processed = frameProcessor.processFrame(sampleBuffer)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(processed) else { return }

        VTCompressionSessionEncodeFrame(session, imageBuffer: pixelBuffer,
            presentationTimeStamp: pts, duration: dur,
            frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
    }

    // MARK: - H.264 Encoder

    private func setupEncoder(width: Int32, height: Int32, bitrate: Int) {
        let callback: VTCompressionOutputCallback = { refCon, _, status, _, sampleBuffer in
            guard let refCon = refCon, status == noErr, let sb = sampleBuffer else { return }
            Unmanaged<SampleHandler>.fromOpaque(refCon).takeUnretainedValue().handleEncodedFrame(sb)
        }

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: width, height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil, imageBufferAttributes: nil,
            compressedDataAllocator: nil, outputCallback: callback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session else {
            log("Encoder FAILED: \(status)")
            return
        }

        // Baseline profile = fastest encoding
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: (bitrate * 1000) as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 24 as CFNumber) // 24fps saves ~20% CPU vs 30
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 72 as CFNumber) // keyframe every 3s
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowTemporalCompression, value: kCFBooleanTrue)

        // Use hardware encoder explicitly
        if #available(iOSApplicationExtension 17.4, *) {
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue)
        }

        VTCompressionSessionPrepareToEncodeFrames(session)
        compressionSession = session
        log("H.264 encoder ready (Baseline): \(width)x\(height) @ \(bitrate)kbps")
    }

    private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isReady, let stream = rtmpStream else { return }
        Task { await stream.append(sampleBuffer) }
    }

    private func destroyEncoder() {
        if let s = compressionSession {
            VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(s)
        }
        compressionSession = nil
    }

    private func log(_ msg: String) { NSLog("[StreamForge Broadcast] \(msg)") }
}
