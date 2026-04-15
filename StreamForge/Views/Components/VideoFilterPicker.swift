import SwiftUI

/// Color filter picker with presets and custom sliders.
struct VideoFilterPicker: View {
    @State private var selectedFilter: VideoFilter = .none
    @State private var customParams = FilterParams()
    @State private var showCustom = false

    private let purple = Color(red: 0.4, green: 0.2, blue: 0.8)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "camera.filters").foregroundColor(purple)
                Text("Color Filter").font(.headline).foregroundColor(.white)
                Spacer()
                if selectedFilter != .none {
                    Button("Reset") {
                        selectedFilter = .none
                        VideoFilterStore.save(.none)
                    }
                    .font(.caption).foregroundColor(.red)
                }
            }

            // Preset grid
            LazyVGrid(columns: [
                GridItem(.flexible()), GridItem(.flexible()),
                GridItem(.flexible()), GridItem(.flexible())
            ], spacing: 8) {
                ForEach(VideoFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                        customParams = filter.filterParams
                        VideoFilterStore.save(filter)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 16))
                                .frame(width: 36, height: 36)
                                .background(selectedFilter == filter ? purple : Color.white.opacity(0.08))
                                .foregroundColor(selectedFilter == filter ? .white : .gray)
                                .clipShape(Circle())

                            Text(filter.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(selectedFilter == filter ? .white : .gray)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Custom adjustments toggle
            Button {
                showCustom.toggle()
            } label: {
                HStack {
                    Text("Custom Adjustments").font(.caption).foregroundColor(purple)
                    Spacer()
                    Image(systemName: showCustom ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.gray)
                }
            }

            if showCustom {
                VStack(spacing: 6) {
                    filterSlider("Saturation", value: $customParams.saturation, range: 0...2.5)
                    filterSlider("Contrast", value: $customParams.contrast, range: 0.5...2.0)
                    filterSlider("Brightness", value: $customParams.brightness, range: -0.3...0.3)
                    filterSlider("Temperature", value: $customParams.temperature, range: 3000...9000)
                    filterSlider("Tint", value: $customParams.tint, range: -50...50)
                    filterSlider("Sepia", value: $customParams.sepia, range: 0...1)
                    filterSlider("Vignette", value: $customParams.vignette, range: 0...2)
                }
            }
        }
        .padding()
        .background(Color(red: 0.08, green: 0.06, blue: 0.12))
        .cornerRadius(12)
        .onAppear {
            let (filter, params) = VideoFilterStore.load()
            selectedFilter = filter
            customParams = params
        }
    }

    private func filterSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundColor(.gray).frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
                .tint(purple)
                .onChange(of: value.wrappedValue) { _, _ in
                    VideoFilterStore.saveCustomParams(customParams)
                }
            Text(String(format: "%.1f", value.wrappedValue))
                .font(.caption2.monospaced()).foregroundColor(.white).frame(width: 35)
        }
    }
}
