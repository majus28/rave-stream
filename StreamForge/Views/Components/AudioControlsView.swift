import SwiftUI

struct AudioControlsView: View {
    @ObservedObject var audioService: AudioService

    var body: some View {
        VStack(spacing: 16) {
            // Audio level meter
            AudioLevelMeter(level: audioService.audioLevel)
                .frame(height: 24)

            // Mic controls
            HStack {
                Button {
                    audioService.toggleMic()
                } label: {
                    Image(systemName: audioService.isMicEnabled ? "mic.fill" : "mic.slash.fill")
                        .font(.title3)
                        .foregroundColor(audioService.isMicEnabled ? .blue : .red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Microphone")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Slider(value: Binding(
                        get: { audioService.micVolume },
                        set: { audioService.setMicVolume($0) }
                    ), in: 0...1)
                    .tint(.blue)
                    .disabled(!audioService.isMicEnabled)
                }
            }

            // Device audio
            HStack {
                Image(systemName: audioService.isDeviceAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.title3)
                    .foregroundColor(audioService.isDeviceAudioEnabled ? .blue : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Audio")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Slider(value: Binding(
                        get: { audioService.deviceAudioVolume },
                        set: { audioService.setDeviceAudioVolume($0) }
                    ), in: 0...1)
                    .tint(.blue)
                    .disabled(!audioService.isDeviceAudioEnabled)
                }
            }

            // Input selection
            if audioService.availableInputs.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Input")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Picker("Input", selection: Binding(
                        get: { audioService.selectedInputId ?? "" },
                        set: { audioService.selectInput(id: $0) }
                    )) {
                        ForEach(audioService.availableInputs) { input in
                            Text(input.name).tag(input.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
    }
}

struct AudioLevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5).opacity(0.3))

                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelGradient)
                    .frame(width: geo.size.width * CGFloat(level))
                    .animation(.linear(duration: 0.1), value: level)
            }
        }
    }

    private var levelGradient: LinearGradient {
        LinearGradient(
            colors: level > 0.8 ? [.yellow, .red] : [.green, .green],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
