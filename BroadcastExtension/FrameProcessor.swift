import Foundation
import CoreMedia
import CoreGraphics
import CoreImage
import UIKit
import AVFoundation
import ImageIO

/// Optimized frame processor — renders scene layout with overlays.
/// Reuses buffers and skips compositing when no overlays are active.
final class FrameProcessor {
    private let appGroupId = "group.com.majuz.streamforge"

    private var frameCounter = 0
    var forceRotateToLandscape = false
    // No longer permanently disabling overlays — removed forceSkipOverlays

    // Cached scene layout
    private var cachedLayout: SceneLayout?
    private var cachedOverlayImages: [UUID: CGImage] = [:]
    private var cachedGIFFrames: [UUID: GIFAnimation] = [:]
    private var cachedBRBActive = false
    private var cachedBRBPixelBuffer: CVPixelBuffer?
    private var hasOverlays = false
    private var isFullScreen = true

    // Color filter — cached filter instances (NEVER allocate per-frame)
    private var cachedFilterParams = FilterParams()
    private var hasFilter = false
    private lazy var colorControlsFilter = CIFilter(name: "CIColorControls")
    private lazy var temperatureFilter = CIFilter(name: "CITemperatureAndTint")
    private lazy var sepiaFilter = CIFilter(name: "CISepiaTone")
    private lazy var vignetteFilter = CIFilter(name: "CIVignette")

    /// True when no processing is needed — raw frames can go straight to encoder
    var canSkipProcessing: Bool {
        !cachedBRBActive && !hasOverlays && isFullScreen && !forceRotateToLandscape && !hasFilter
    }

    // Reusable output buffer (avoid allocation every frame)
    private var reusableBuffer: CVPixelBuffer?
    private var reusableBufferW = 0
    private var reusableBufferH = 0

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    struct GIFAnimation {
        let frames: [CGImage]
        let durations: [Double]
        var currentFrame: Int = 0
        var elapsed: Double = 0

        mutating func advance(dt: Double) -> CGImage? {
            guard !frames.isEmpty else { return nil }
            elapsed += dt
            if elapsed >= durations[currentFrame] {
                elapsed = 0
                currentFrame = (currentFrame + 1) % frames.count
            }
            return frames[currentFrame]
        }
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        frameCounter += 1
        if frameCounter % 30 == 1 { refreshConfig() }

        // BRB mode
        if cachedBRBActive {
            if let brb = getBRBPixelBuffer(from: sampleBuffer) {
                return createSampleBuffer(from: brb, timing: sampleBuffer) ?? sampleBuffer
            }
            return sampleBuffer
        }

        // FAST PATH: no overlays and game is full screen
        if !hasOverlays && isFullScreen {
            if hasFilter || forceRotateToLandscape {
                guard let src = CMSampleBufferGetImageBuffer(sampleBuffer) else { return sampleBuffer }
                if let processed = applyFilterAndRotate(src) {
                    return createSampleBuffer(from: processed, timing: sampleBuffer) ?? sampleBuffer
                }
            }
            return sampleBuffer
        }

        // COMPOSITE PATH: render scene layout with overlays
        return compositeFrame(sampleBuffer)
    }

    // MARK: - Composite (only when overlays exist or game screen is resized)

    private func compositeFrame(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        guard let srcBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return sampleBuffer }

        let layout = cachedLayout ?? .default
        let outW = layout.canvasWidth
        let outH = layout.canvasHeight

        // Reuse output buffer
        let dst = getOrCreateBuffer(width: outW, height: outH)

        CVPixelBufferLockBaseAddress(dst, [])
        defer { CVPixelBufferUnlockBaseAddress(dst, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(dst),
            width: outW, height: outH,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(dst),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return sampleBuffer }

        // Clear
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: outW, height: outH))

        // Flip for UIKit
        ctx.translateBy(x: 0, y: CGFloat(outH))
        ctx.scaleBy(x: 1, y: -1)

        // Draw game screen
        let gs = layout.gameScreen
        let gameRect = CGRect(
            x: CGFloat(outW) * gs.x,
            y: CGFloat(outH) * gs.y,
            width: CGFloat(outW) * gs.width,
            height: CGFloat(outH) * gs.height
        )

        // Render source buffer to game rect (with rotation if needed)
        let srcW = CVPixelBufferGetWidth(srcBuffer)
        let srcH = CVPixelBufferGetHeight(srcBuffer)

        var ciImage: CIImage
        if forceRotateToLandscape && srcH > srcW {
            ciImage = CIImage(cvPixelBuffer: srcBuffer)
                .transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
                .transformed(by: CGAffineTransform(translationX: 0, y: CGFloat(srcW)))
        } else {
            ciImage = CIImage(cvPixelBuffer: srcBuffer)
        }
        // Apply color filter
        if hasFilter {
            ciImage = applyCIFilter(to: ciImage)
        }

        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            drawCGImage(cgImage, in: gameRect, context: ctx, fillMode: true)
        }

        // Draw overlays
        let visibleOverlays = (layout.overlays.filter(\.visible).sorted { $0.order < $1.order })
        for layer in visibleOverlays {
            let layerRect = CGRect(
                x: CGFloat(outW) * layer.rect.x,
                y: CGFloat(outH) * layer.rect.y,
                width: CGFloat(outW) * layer.rect.width,
                height: CGFloat(outH) * layer.rect.height
            )

            ctx.saveGState()
            ctx.setAlpha(layer.opacity)
            let isFill = (layer.aspectMode ?? .fill) == .fill

            switch layer.type {
            case .image:
                if let img = cachedOverlayImages[layer.id] {
                    drawCGImage(img, in: layerRect, context: ctx, fillMode: isFill)
                }
            case .gif:
                let dt = 1.0 / 30.0
                if var anim = cachedGIFFrames[layer.id], let frame = anim.advance(dt: dt) {
                    drawCGImage(frame, in: layerRect, context: ctx, fillMode: isFill)
                    cachedGIFFrames[layer.id] = anim
                }
            case .video:
                if let img = cachedOverlayImages[layer.id] {
                    drawCGImage(img, in: layerRect, context: ctx, fillMode: isFill)
                }
            case .text:
                if !layer.content.isEmpty {
                    ctx.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
                    ctx.fill(layerRect)
                    UIGraphicsPushContext(ctx)
                    let fontSize = max(layerRect.height * 0.6, 10)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: fontSize),
                        .foregroundColor: UIColor.white
                    ]
                    let text = layer.content as NSString
                    let size = text.size(withAttributes: attrs)
                    text.draw(at: CGPoint(
                        x: layerRect.minX + (layerRect.width - size.width) / 2,
                        y: layerRect.minY + (layerRect.height - size.height) / 2
                    ), withAttributes: attrs)
                    UIGraphicsPopContext()
                }
            case .webURL:
                break // Web overlays need WebView — skipped in extension
            }

            ctx.restoreGState()
        }

        return createSampleBuffer(from: dst, timing: sampleBuffer) ?? sampleBuffer
    }

    // MARK: - Color Filter

    /// Apply filter + rotate in one pass (fast path)
    private func applyFilterAndRotate(_ srcBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        var ciImage = CIImage(cvPixelBuffer: srcBuffer)

        let srcW = CVPixelBufferGetWidth(srcBuffer)
        let srcH = CVPixelBufferGetHeight(srcBuffer)

        // Rotate if needed
        if forceRotateToLandscape && srcH > srcW {
            ciImage = ciImage
                .transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
                .transformed(by: CGAffineTransform(translationX: 0, y: CGFloat(srcW)))
        }

        // Apply filter
        if hasFilter {
            ciImage = applyCIFilter(to: ciImage)
        }

        let outW = forceRotateToLandscape && srcH > srcW ? srcH : srcW
        let outH = forceRotateToLandscape && srcH > srcW ? srcW : srcH
        let dst = getOrCreateBuffer(width: outW, height: outH)
        ciContext.render(ciImage, to: dst)
        return dst
    }

    /// Apply filter to source buffer (filter-only, no rotation)
    private func applyFilter(to srcBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        var ciImage = CIImage(cvPixelBuffer: srcBuffer)
        ciImage = applyCIFilter(to: ciImage)
        let w = CVPixelBufferGetWidth(srcBuffer)
        let h = CVPixelBufferGetHeight(srcBuffer)
        let dst = getOrCreateBuffer(width: w, height: h)
        ciContext.render(ciImage, to: dst)
        return dst
    }

    /// Apply CIFilter chain — uses CACHED filter instances (zero allocations per frame)
    private func applyCIFilter(to image: CIImage) -> CIImage {
        let p = cachedFilterParams
        var result = image

        if p.saturation != 1.0 || p.brightness != 0.0 || p.contrast != 1.0 {
            colorControlsFilter?.setValue(result, forKey: kCIInputImageKey)
            colorControlsFilter?.setValue(p.saturation, forKey: "inputSaturation")
            colorControlsFilter?.setValue(p.brightness, forKey: "inputBrightness")
            colorControlsFilter?.setValue(p.contrast, forKey: "inputContrast")
            result = colorControlsFilter?.outputImage ?? result
        }

        if p.temperature != 6500 || p.tint != 0 {
            temperatureFilter?.setValue(result, forKey: kCIInputImageKey)
            temperatureFilter?.setValue(CIVector(x: CGFloat(p.temperature), y: CGFloat(p.tint)), forKey: "inputNeutral")
            temperatureFilter?.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
            result = temperatureFilter?.outputImage ?? result
        }

        if p.sepia > 0 {
            sepiaFilter?.setValue(result, forKey: kCIInputImageKey)
            sepiaFilter?.setValue(p.sepia, forKey: "inputIntensity")
            result = sepiaFilter?.outputImage ?? result
        }

        if p.vignette > 0 {
            vignetteFilter?.setValue(result, forKey: kCIInputImageKey)
            vignetteFilter?.setValue(p.vignette, forKey: "inputIntensity")
            vignetteFilter?.setValue(max(result.extent.width, result.extent.height) * 0.1, forKey: "inputRadius")
            result = vignetteFilter?.outputImage ?? result
        }

        return result
    }

    // MARK: - Image Drawing

    private func drawCGImage(_ image: CGImage, in rect: CGRect, context ctx: CGContext, fillMode: Bool) {
        ctx.saveGState()

        if fillMode {
            let imgAspect = CGFloat(image.width) / CGFloat(image.height)
            let rectAspect = rect.width / rect.height
            var drawRect = rect

            if imgAspect > rectAspect {
                let sw = rect.height * imgAspect
                drawRect = CGRect(x: rect.minX - (sw - rect.width) / 2, y: rect.minY, width: sw, height: rect.height)
            } else {
                let sh = rect.width / imgAspect
                drawRect = CGRect(x: rect.minX, y: rect.minY - (sh - rect.height) / 2, width: rect.width, height: sh)
            }
            ctx.clip(to: rect)
            ctx.translateBy(x: 0, y: drawRect.minY + drawRect.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: drawRect.minX, y: drawRect.minY, width: drawRect.width, height: drawRect.height))
        } else {
            ctx.translateBy(x: 0, y: rect.minY + rect.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height))
        }

        ctx.restoreGState()
    }

    // MARK: - Rotation (only used in fast path)

    private func rotateToLandscape(_ srcBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let srcW = CVPixelBufferGetWidth(srcBuffer)
        let srcH = CVPixelBufferGetHeight(srcBuffer)

        let dst = getOrCreateBuffer(width: srcH, height: srcW)

        let ciImage = CIImage(cvPixelBuffer: srcBuffer)
            .transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
            .transformed(by: CGAffineTransform(translationX: 0, y: CGFloat(srcW)))

        ciContext.render(ciImage, to: dst)
        return dst
    }

    // MARK: - Buffer Pool

    private func getOrCreateBuffer(width: Int, height: Int) -> CVPixelBuffer {
        if let buf = reusableBuffer, reusableBufferW == width, reusableBufferH == height {
            return buf
        }

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        reusableBuffer = buffer
        reusableBufferW = width
        reusableBufferH = height
        return buffer!
    }

    // MARK: - BRB

    private func getBRBPixelBuffer(from sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
        if let cached = cachedBRBPixelBuffer { return cached }

        let layout = cachedLayout ?? .default
        let w = layout.canvasWidth
        let h = layout.canvasHeight

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &buffer)
        guard let buf = buffer else { return nil }

        CVPixelBufferLockBaseAddress(buf, [])
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buf),
            width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId),
               let data = try? Data(contentsOf: containerURL.appendingPathComponent("brb_image.jpg")),
               let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage {
                ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            } else {
                ctx.setFillColor(UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                ctx.translateBy(x: 0, y: CGFloat(h))
                ctx.scaleBy(x: 1, y: -1)
                UIGraphicsPushContext(ctx)
                let text = "Be Right Back" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: CGFloat(h) / 8),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.8)
                ]
                let size = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: (CGFloat(w) - size.width) / 2, y: (CGFloat(h) - size.height) / 2), withAttributes: attrs)
                UIGraphicsPopContext()
            }
        }
        CVPixelBufferUnlockBaseAddress(buf, [])

        cachedBRBPixelBuffer = buf
        return buf
    }

    // MARK: - Helpers

    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, timing: CMSampleBuffer) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(timing),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(timing),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(timing)
        )
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDesc)
        guard let desc = formatDesc else { return nil }
        var newBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescription: desc, sampleTiming: &timingInfo, sampleBufferOut: &newBuffer)
        return newBuffer
    }

    // MARK: - Config

    private func refreshConfig() {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }

        cachedBRBActive = defaults.bool(forKey: "brb_active")
        if !cachedBRBActive { cachedBRBPixelBuffer = nil }

        // Load color filter
        if let filterData = defaults.data(forKey: "video_filter_params"),
           let params = try? JSONDecoder().decode(FilterParams.self, from: filterData) {
            cachedFilterParams = params
            hasFilter = !params.isIdentity
        } else {
            hasFilter = false
            cachedFilterParams = FilterParams()
        }

        if let data = defaults.data(forKey: "scene_layout"),
           let layout = try? JSONDecoder().decode(SceneLayout.self, from: data) {
            cachedLayout = layout

            let visibleOverlays = layout.overlays.filter(\.visible)
            hasOverlays = !visibleOverlays.isEmpty
            isFullScreen = layout.gameScreen.x == 0 && layout.gameScreen.y == 0
                && layout.gameScreen.width >= 0.99 && layout.gameScreen.height >= 0.99

            // Invalidate caches for removed overlays
            let currentIds = Set(layout.overlays.map(\.id))
            cachedOverlayImages = cachedOverlayImages.filter { currentIds.contains($0.key) }
            cachedGIFFrames = cachedGIFFrames.filter { currentIds.contains($0.key) }

            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else { return }

            for layer in layout.overlays {
                switch layer.type {
                case .image, .video:
                    if cachedOverlayImages[layer.id] == nil {
                        let ext = layer.type == .video ? "mp4" : "png"
                        let fileURL = containerURL.appendingPathComponent("overlay_\(layer.id.uuidString).\(ext)")
                        if layer.type == .video {
                            if let img = Self.videoThumbnail(url: fileURL) { cachedOverlayImages[layer.id] = img }
                        } else if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
                            cachedOverlayImages[layer.id] = img.cgImage
                        }
                    }
                case .gif:
                    if cachedGIFFrames[layer.id] == nil {
                        let fileURL = containerURL.appendingPathComponent("overlay_\(layer.id.uuidString).gif")
                        if let data = try? Data(contentsOf: fileURL) { cachedGIFFrames[layer.id] = Self.decodeGIF(data) }
                    }
                default: break
                }
            }
        }
    }

    private static func decodeGIF(_ data: Data) -> GIFAnimation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var frames: [CGImage] = []
        var durations: [Double] = []

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(cgImage)
            var delay = 0.1
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let d = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, d > 0 { delay = d }
                else if let d = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double, d > 0 { delay = d }
            }
            durations.append(delay)
        }
        return GIFAnimation(frames: frames, durations: durations)
    }

    private static func videoThumbnail(url: URL) -> CGImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let gen = AVAssetImageGenerator(asset: AVAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        return try? gen.copyCGImage(at: .zero, actualTime: nil)
    }
}

// MARK: - FilterParams (extension duplicate)

struct FilterParams: Codable {
    var saturation: Float = 1.0
    var contrast: Float = 1.0
    var brightness: Float = 0.0
    var temperature: Float = 6500
    var tint: Float = 0
    var sepia: Float = 0
    var vignette: Float = 0

    var isIdentity: Bool {
        saturation == 1.0 && contrast == 1.0 && brightness == 0.0 &&
        temperature == 6500 && tint == 0 && sepia == 0 && vignette == 0
    }
}

// MARK: - SceneLayout (extension duplicate)

struct SceneLayout: Codable {
    var gameScreen: ScreenRect
    var overlays: [OverlayLayer]
    var canvasWidth: Int
    var canvasHeight: Int

    struct ScreenRect: Codable {
        var x: CGFloat; var y: CGFloat; var width: CGFloat; var height: CGFloat
        static let fullScreen = ScreenRect(x: 0, y: 0, width: 1, height: 1)
    }

    enum LayerType: String, Codable, CaseIterable, Identifiable {
        case image, gif, video, text, webURL
        var id: String { rawValue }
    }

    enum AspectMode: String, Codable { case fit, fill, stretch }

    struct OverlayLayer: Codable, Identifiable {
        let id: UUID; var type: LayerType; var name: String; var rect: ScreenRect
        var visible: Bool; var content: String; var opacity: CGFloat; var order: Int
        var aspectMode: AspectMode?
        var locked: Bool?
        var rotation: Double?
    }

    static let `default` = SceneLayout(gameScreen: .fullScreen, overlays: [], canvasWidth: 1280, canvasHeight: 720)
}
