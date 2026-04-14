import Foundation
import ReplayKit
import Photos

/// Records the stream locally.
final class RecordingService: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var savedFileURL: URL?
    @Published var error: String?

    private var timer: Timer?
    private var startTime: Date?

    func startRecording() async throws {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else { throw RecordingError.unavailable }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "StreamForge_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = documentsPath.appendingPathComponent(fileName)
        savedFileURL = outputURL

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            recorder.startRecording { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        isRecording = true
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }

        StreamLogger.log(.stream, "Recording started")
    }

    func stopRecording() async {
        timer?.invalidate()
        timer = nil

        let recorder = RPScreenRecorder.shared()

        do {
            guard let outputURL = savedFileURL else { return }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                recorder.stopRecording(withOutput: outputURL) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            StreamLogger.log(.stream, "Recording saved: \(outputURL.lastPathComponent)")
        } catch {
            self.error = error.localizedDescription
            StreamLogger.log(.stream, "Recording save failed: \(error)")
        }

        isRecording = false
    }

    func saveToPhotos() async {
        guard let url = savedFileURL else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }
            StreamLogger.log(.stream, "Recording saved to Photos")
        } catch {
            self.error = "Failed to save to Photos: \(error.localizedDescription)"
        }
    }

    var formattedDuration: String {
        let total = Int(recordingDuration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    enum RecordingError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Screen recording is not available" }
    }
}
