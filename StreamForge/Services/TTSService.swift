import Foundation
import AVFoundation

/// Text-to-Speech service for reading chat messages and alerts aloud.
final class TTSService: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var volume: Float = 0.8
    @Published var rate: Float = 0.5  // 0.0 - 1.0

    private let synthesizer = AVSpeechSynthesizer()
    private var messageQueue: [String] = []
    private var isSpeaking = false

    func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }

        messageQueue.append(text)
        processQueue()
    }

    func speakAlert(type: String, username: String, message: String?) {
        guard isEnabled else { return }

        var text = "\(username) "
        switch type {
        case "follow": text += "just followed!"
        case "subscribe": text += "just subscribed!"
        case "donation": text += "donated. \(message ?? "")"
        case "bits": text += "cheered. \(message ?? "")"
        default: text += "\(type). \(message ?? "")"
        }

        speak(text)
    }

    func speakChatMessage(username: String, message: String) {
        guard isEnabled else { return }
        speak("\(username) says: \(message)")
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        messageQueue.removeAll()
        isSpeaking = false
    }

    private func processQueue() {
        guard !isSpeaking, let text = messageQueue.first else { return }
        messageQueue.removeFirst()
        isSpeaking = true

        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = volume
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.postUtteranceDelay = 0.3

        synthesizer.speak(utterance)

        // Simple completion check
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.08 + 1.0) { [weak self] in
            self?.isSpeaking = false
            self?.processQueue()
        }
    }
}
