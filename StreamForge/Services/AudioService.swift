import Foundation
import AVFoundation
import Combine

final class AudioService: ObservableObject {
    @Published var isMicEnabled: Bool = true
    @Published var isDeviceAudioEnabled: Bool = true
    @Published var micVolume: Float = 1.0
    @Published var deviceAudioVolume: Float = 1.0
    @Published var audioLevel: Float = 0.0
    @Published var isNoiseReductionEnabled: Bool = true
    @Published var availableInputs: [AudioInput] = []
    @Published var selectedInputId: String?

    private var audioEngine: AVAudioEngine?
    private var levelTimer: Timer?
    private var inputNode: AVAudioInputNode?

    struct AudioInput: Identifiable {
        let id: String
        let name: String
        let portType: AVAudioSession.Port
    }

    init() {
        refreshAvailableInputs()
        observeRouteChanges()
    }

    func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        refreshAvailableInputs()
    }

    func startMonitoringLevels() {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(frameLength))
            let db = 20 * log10(max(rms, 0.000001))
            // Normalize to 0...1 range (roughly -60dB to 0dB)
            let normalized = max(0, min(1, (db + 60) / 60))

            DispatchQueue.main.async {
                self?.audioLevel = normalized
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            inputNode = input
        } catch {
            print("Audio engine start failed: \(error)")
        }
    }

    func stopMonitoringLevels() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioLevel = 0
    }

    func toggleMic() {
        isMicEnabled.toggle()
        if let input = inputNode {
            // Mute by setting volume to 0 on the input node
            input.volume = isMicEnabled ? micVolume : 0
        }
    }

    func setMicVolume(_ volume: Float) {
        micVolume = max(0, min(1, volume))
        if isMicEnabled, let input = inputNode {
            input.volume = micVolume
        }
    }

    func setDeviceAudioVolume(_ volume: Float) {
        deviceAudioVolume = max(0, min(1, volume))
    }

    func selectInput(id: String) {
        selectedInputId = id
        guard let input = availableInputs.first(where: { $0.id == id }) else { return }

        let session = AVAudioSession.sharedInstance()
        if let port = session.availableInputs?.first(where: { $0.portType == input.portType }) {
            try? session.setPreferredInput(port)
        }
    }

    func refreshAvailableInputs() {
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else {
            availableInputs = []
            return
        }

        availableInputs = inputs.map { port in
            AudioInput(
                id: port.uid,
                name: port.portName,
                portType: port.portType
            )
        }

        if selectedInputId == nil, let first = availableInputs.first {
            selectedInputId = first.id
        }
    }

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAvailableInputs()
        }
    }
}
