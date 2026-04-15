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

    // Audio config (from App Group)
    private var cachedMicVolume: Float = 1.0
    private var cachedAppAudioVolume: Float = 0.4
    private var cachedMicEnabled: Bool = true
    private var cachedAppAudioEnabled: Bool = true
    private var audioConfigCounter = 0

    // Frame pacing — uses configured FPS, thread-safe via lock
    private let videoProcessingQueue = DispatchQueue(label: "com.streamforge.broadcast.video", qos: .userInitiated)
    private let pacingLock = NSLock()
    private var _isProcessingFrame = false
    private var _lastFrameTime: CFTimeInterval = 0
    private var _consecutiveSkips = 0
    private var targetFrameInterval: CFTimeInterval = 1.0 / 30.0
    private var skippedFrames = 0

    static let appGroupId = "group.com.majuz.streamforge"

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        log("========= BROADCAST STARTED =========")

        let defaults = UserDefaults(suiteName: Self.appGroupId)
        let url = defaults?.string(forKey: "rtmp_url") ?? ""
        let streamKey = defaults?.string(forKey: "rtmp_stream_key") ?? ""
        let bitrate = max(defaults?.integer(forKey: "rtmp_bitrate") ?? 2500, 1000)
        let fps = max(defaults?.integer(forKey: "rtmp_fps") ?? 30, 15)
        let savedWidth = max(defaults?.integer(forKey: "rtmp_width") ?? 1280, 480)
        let savedHeight = max(defaults?.integer(forKey: "rtmp_height") ?? 720, 480)

        isLandscape = savedWidth > savedHeight
        encoderWidth = Int32(isLandscape ? max(savedWidth, savedHeight) : min(savedWidth, savedHeight))
        encoderHeight = Int32(isLandscape ? min(savedWidth, savedHeight) : max(savedWidth, savedHeight))

        // Set frame pacing from config
        targetFrameInterval = 1.0 / Double(max(fps, 15))

        log("Encoder: \(encoderWidth)x\(encoderHeight) @ \(fps)fps \(bitrate)kbps, landscape=\(isLandscape)")
        log("Frame pacing: \(String(format: "%.1f", 1.0 / targetFrameInterval))fps target")
        frameProcessor.forceRotateToLandscape = isLandscape

        guard !url.isEmpty, !streamKey.isEmpty else {
            log("ERROR: No RTMP config!")
            finishBroadcastWithError(NSError(domain: "StreamForge", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Open StreamForge and create a YouTube event first."]))
            return
        }

        // H.264 encoder — use Baseline for speed
        setupEncoder(width: encoderWidth, height: encoderHeight, bitrate: bitrate, fps: fps)

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

        // Refresh audio config periodically
        audioConfigCounter += 1
        if audioConfigCounter % 30 == 1 { refreshAudioConfig() }

        switch sampleBufferType {
        case .video:
            videoFrameCount += 1

            // Thread-safe pacing check
            pacingLock.lock()
            let now = CACurrentMediaTime()
            let elapsed = now - _lastFrameTime
            let busy = _isProcessingFrame

            if elapsed < targetFrameInterval {
                pacingLock.unlock()
                return // Too soon
            }

            if busy {
                skippedFrames += 1
                _consecutiveSkips += 1
                pacingLock.unlock()
                return
            }

            _consecutiveSkips = 0
            _lastFrameTime = now
            _isProcessingFrame = true
            pacingLock.unlock()

            let count = videoFrameCount
            videoProcessingQueue.async { [weak self] in
                guard let self else { return }

                // Wrap in autorelease pool to prevent memory buildup from CIFilter/CGImage
                autoreleasepool {
                    self.processVideoFrame(sampleBuffer)
                }

                self.pacingLock.lock()
                self._isProcessingFrame = false
                self.pacingLock.unlock()

                if count == 1 { self.log("First VIDEO frame!") }
                if count % 300 == 0 {
                    let memMB = Self.currentMemoryMB()
                    self.log("V=\(count) A=\(self.audioFrameCount) skip=\(self.skippedFrames) mem=\(memMB)MB")
                }
            }

        case .audioApp:
            // Check if app audio is enabled
            guard cachedAppAudioEnabled else { break }
            if let stream = rtmpStream,
               let pcm = copyAudioToPCM(sampleBuffer, volumeScale: cachedAppAudioVolume),
               let time = makeAudioTime(from: sampleBuffer) {
                Task { await stream.append(pcm, when: time) }
                audioFrameCount += 1
                if audioFrameCount == 1 { log("First APP AUDIO frame!") }
            }

        case .audioMic:
            // Check if mic is enabled
            guard cachedMicEnabled else { break }
            if let stream = rtmpStream,
               let pcm = copyAudioToPCM(sampleBuffer, volumeScale: cachedMicVolume),
               let time = makeAudioTime(from: sampleBuffer) {
                Task { await stream.append(pcm, when: time) }
                audioFrameCount += 1
                if audioFrameCount == 1 { log("First MIC AUDIO frame!") }
            }

        @unknown default: break
        }
    }

    // MARK: - Audio Helpers

    /// Copy audio CMSampleBuffer to AVAudioPCMBuffer with volume scaling
    private func copyAudioToPCM(_ sampleBuffer: CMSampleBuffer, volumeScale: Float = 1.0) -> AVAudioPCMBuffer? {
        guard let formatDesc = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc),
              let format = AVAudioFormat(streamDescription: asbd) else { return nil }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0,
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        pcm.frameLength = AVAudioFrameCount(frameCount)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var length = 0
        var ptr: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &ptr)
        guard status == noErr, let srcPtr = ptr, length > 0 else { return nil }

        if let dest = pcm.floatChannelData {
            let sampleCount = min(length / MemoryLayout<Float>.size, Int(pcm.frameCapacity) * Int(format.channelCount))
            memcpy(dest[0], srcPtr, sampleCount * MemoryLayout<Float>.size)
            // Apply volume scaling
            if volumeScale != 1.0 {
                for i in 0..<sampleCount {
                    dest[0][i] *= volumeScale
                }
            }
        } else if let dest = pcm.int16ChannelData {
            let sampleCount = min(length / MemoryLayout<Int16>.size, Int(pcm.frameCapacity) * Int(format.channelCount))
            memcpy(dest[0], srcPtr, sampleCount * MemoryLayout<Int16>.size)
            if volumeScale != 1.0 {
                for i in 0..<sampleCount {
                    dest[0][i] = Int16(clamping: Int(Float(dest[0][i]) * volumeScale))
                }
            }
        } else {
            return nil
        }

        return pcm
    }

    private func refreshAudioConfig() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else { return }
        cachedMicVolume = (defaults.object(forKey: "audio_mic_volume") as? Float ?? 100) / 100.0
        cachedAppAudioVolume = (defaults.object(forKey: "audio_app_volume") as? Float ?? 40) / 100.0
        cachedMicEnabled = defaults.object(forKey: "audio_mic_enabled") as? Bool ?? true
        cachedAppAudioEnabled = defaults.object(forKey: "audio_app_enabled") as? Bool ?? true
    }

    private func makeAudioTime(from sampleBuffer: CMSampleBuffer) -> AVAudioTime? {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard pts.isValid else { return nil }
        return AVAudioTime(hostTime: CMClockConvertHostTimeToSystemUnits(pts))
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

    private func setupEncoder(width: Int32, height: Int32, bitrate: Int, fps: Int) {
        let callback: VTCompressionOutputCallback = { refCon, _, status, _, sampleBuffer in
            guard let refCon = refCon, status == noErr, let sb = sampleBuffer else { return }
            Unmanaged<SampleHandler>.fromOpaque(refCon).takeUnretainedValue().handleEncodedFrame(sb)
        }

        // Specify pixel format so encoder handles format conversions consistently
        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(width),
            kCVPixelBufferHeightKey as String: Int(height),
        ]

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: width, height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: pixelBufferAttrs as CFDictionary,
            compressedDataAllocator: nil, outputCallback: callback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session else {
            log("Encoder FAILED: \(status)")
            return
        }

        let fpsValue = max(15, fps)
        let keyframeInterval = fpsValue * 2
        let bps = bitrate * 1000

        // Main profile — better quality than Baseline (CABAC entropy, better compression)
        // Still hardware-accelerated on all modern iPhones
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)

        // Bitrate + data rate limits to prevent quality drops
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bps as CFNumber)

        // Allow 1.5x burst above average for fast-motion scenes (games)
        let byteLimit = Double(bps) * 1.5 / 8.0
        let limits = [byteLimit, 1.0] as CFArray
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits, value: limits)

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fpsValue as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: keyframeInterval as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 2 as CFNumber) // keyframe at least every 2s
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowTemporalCompression, value: kCFBooleanTrue)

        // Use hardware encoder
        if #available(iOSApplicationExtension 17.4, *) {
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue)
        }

        VTCompressionSessionPrepareToEncodeFrames(session)
        compressionSession = session
        log("H.264 encoder ready (Main): \(width)x\(height) @ \(fpsValue)fps \(bitrate)kbps (burst: \(Int(byteLimit * 8 / 1000))kbps)")
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

    /// Get current memory usage in MB
    static func currentMemoryMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size / 1024 / 1024) : 0
    }
}
