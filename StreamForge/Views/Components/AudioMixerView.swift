import SwiftUI

/// OBS-style audio mixer — mic volume, app audio volume, sound alerts, levels display.
/// Settings saved to App Group for broadcast extension to read.
struct AudioMixerView: View {
    @State private var micVolume: Float = 100
    @State private var appAudioVolume: Float = 40
    @State private var micEnabled: Bool = true
    @State private var appAudioEnabled: Bool = true
    @State private var micLevel: Float = 0
    @State private var appLevel: Float = 0

    // Sound alerts
    @State private var alertSoundEnabled: Bool = true
    @State private var alertVolume: Float = 80
    @State private var selectedAlertSound: String = "chime"
    @State private var showSoundPicker: Bool = false

    private let purple = Color(red: 0.4, green: 0.2, blue: 0.8)
    private let darkBg = Color(red: 0.08, green: 0.06, blue: 0.12)

    private let alertSounds = [
        ("chime", "Chime"),
        ("ding", "Ding"),
        ("pop", "Pop"),
        ("bell", "Bell"),
        ("coin", "Coin"),
        ("levelup", "Level Up"),
        ("fanfare", "Fanfare"),
        ("notification", "Notification"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "speaker.wave.3.fill").foregroundColor(purple)
                Text("Audio Mixer").font(.headline).foregroundColor(.white)
            }

            // Mic
            audioChannel(
                icon: "mic.fill",
                label: "Microphone",
                enabled: $micEnabled,
                volume: $micVolume,
                level: micLevel,
                color: .green
            )

            // App Audio
            audioChannel(
                icon: "speaker.wave.2.fill",
                label: "Game / App Audio",
                enabled: $appAudioEnabled,
                volume: $appAudioVolume,
                level: appLevel,
                color: .blue
            )

            Divider().background(purple.opacity(0.2))

            // Alert Sounds
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.badge.fill").foregroundColor(.orange).font(.caption)
                    Text("Alert Sounds").font(.subheadline.bold()).foregroundColor(.white)
                    Spacer()
                    Toggle("", isOn: $alertSoundEnabled)
                        .labelsHidden()
                        .onChange(of: alertSoundEnabled) { _, _ in saveConfig() }
                }

                if alertSoundEnabled {
                    // Volume
                    HStack {
                        Text("Volume").font(.caption2).foregroundColor(.gray).frame(width: 50, alignment: .leading)
                        Slider(value: $alertVolume, in: 0...100, step: 5)
                            .tint(.orange)
                            .onChange(of: alertVolume) { _, _ in saveConfig() }
                        Text("\(Int(alertVolume))%")
                            .font(.caption2.monospaced()).foregroundColor(.white).frame(width: 35)
                    }

                    // Sound picker
                    Button {
                        showSoundPicker.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "music.note").font(.caption)
                            Text(alertSounds.first { $0.0 == selectedAlertSound }?.1 ?? "Chime")
                                .font(.caption)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    if showSoundPicker {
                        VStack(spacing: 2) {
                            ForEach(alertSounds, id: \.0) { sound in
                                Button {
                                    selectedAlertSound = sound.0
                                    showSoundPicker = false
                                    saveConfig()
                                } label: {
                                    HStack {
                                        Text(sound.1).font(.caption).foregroundColor(.white)
                                        Spacer()
                                        if selectedAlertSound == sound.0 {
                                            Image(systemName: "checkmark").font(.caption2).foregroundColor(purple)
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(selectedAlertSound == sound.0 ? purple.opacity(0.15) : Color.clear)
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            }

            Divider().background(purple.opacity(0.2))

            // EQ Preset
            VStack(alignment: .leading, spacing: 6) {
                Text("Mic EQ").font(.caption.bold()).foregroundColor(.gray)
                HStack(spacing: 6) {
                    eqButton("Flat", tag: "flat")
                    eqButton("Voice", tag: "voice")
                    eqButton("Bass+", tag: "bass")
                    eqButton("Treble+", tag: "treble")
                }
            }
        }
        .padding()
        .background(darkBg)
        .cornerRadius(12)
        .onAppear { loadConfig() }
    }

    // MARK: - Audio Channel Row

    private func audioChannel(icon: String, label: String, enabled: Binding<Bool>, volume: Binding<Float>, level: Float, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(enabled.wrappedValue ? color : .gray)
                    .frame(width: 20)
                Text(label).font(.caption).foregroundColor(.white)
                Spacer()
                Button {
                    enabled.wrappedValue.toggle()
                    saveConfig()
                } label: {
                    Image(systemName: enabled.wrappedValue ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.caption)
                        .foregroundColor(enabled.wrappedValue ? color : .red)
                }
            }

            // Level meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level > 0.8 ? Color.red : color)
                        .frame(width: geo.size.width * CGFloat(enabled.wrappedValue ? level * (volume.wrappedValue / 100) : 0))
                        .animation(.linear(duration: 0.1), value: level)
                }
            }
            .frame(height: 6)

            // Volume slider
            HStack {
                Slider(value: volume, in: 0...100, step: 1)
                    .tint(color)
                    .disabled(!enabled.wrappedValue)
                    .onChange(of: volume.wrappedValue) { _, _ in saveConfig() }
                Text("\(Int(volume.wrappedValue))%")
                    .font(.caption2.monospaced())
                    .foregroundColor(enabled.wrappedValue ? .white : .gray)
                    .frame(width: 35)
            }
        }
    }

    // MARK: - EQ Button

    @State private var selectedEQ: String = "flat"

    private func eqButton(_ label: String, tag: String) -> some View {
        Button {
            selectedEQ = tag
            saveConfig()
        } label: {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selectedEQ == tag ? purple : Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
    }

    // MARK: - Persistence

    private func saveConfig() {
        guard let defaults = UserDefaults(suiteName: "group.com.majuz.streamforge") else { return }
        defaults.set(micVolume, forKey: "audio_mic_volume")
        defaults.set(appAudioVolume, forKey: "audio_app_volume")
        defaults.set(micEnabled, forKey: "audio_mic_enabled")
        defaults.set(appAudioEnabled, forKey: "audio_app_enabled")
        defaults.set(alertSoundEnabled, forKey: "audio_alert_enabled")
        defaults.set(alertVolume, forKey: "audio_alert_volume")
        defaults.set(selectedAlertSound, forKey: "audio_alert_sound")
        defaults.set(selectedEQ, forKey: "audio_mic_eq")
        defaults.synchronize()
    }

    private func loadConfig() {
        guard let defaults = UserDefaults(suiteName: "group.com.majuz.streamforge") else { return }
        micVolume = defaults.object(forKey: "audio_mic_volume") as? Float ?? 100
        appAudioVolume = defaults.object(forKey: "audio_app_volume") as? Float ?? 40
        micEnabled = defaults.object(forKey: "audio_mic_enabled") as? Bool ?? true
        appAudioEnabled = defaults.object(forKey: "audio_app_enabled") as? Bool ?? true
        alertSoundEnabled = defaults.object(forKey: "audio_alert_enabled") as? Bool ?? true
        alertVolume = defaults.object(forKey: "audio_alert_volume") as? Float ?? 80
        selectedAlertSound = defaults.string(forKey: "audio_alert_sound") ?? "chime"
        selectedEQ = defaults.string(forKey: "audio_mic_eq") ?? "flat"
    }
}
