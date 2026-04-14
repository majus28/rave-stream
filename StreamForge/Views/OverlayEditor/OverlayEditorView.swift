import SwiftUI

struct OverlayEditorView: View {
    @ObservedObject var viewModel: OverlayEditorViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Preview canvas
                    overlayCanvas
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        .background(Color(.systemGray6).opacity(0.15))
                        .cornerRadius(12)
                        .padding()

                    // Overlay list
                    overlayList
                }
            }
            .navigationTitle("Overlays")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showAddOverlaySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!viewModel.canAddOverlay)
                }
            }
            .sheet(isPresented: $viewModel.showAddOverlaySheet) {
                AddOverlaySheet(viewModel: viewModel)
            }
        }
    }

    private var overlayCanvas: some View {
        GeometryReader { geo in
            ZStack {
                // Stream preview placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "video.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.3))
                    }

                // Overlay items
                ForEach(viewModel.overlays.filter(\.visible)) { overlay in
                    OverlayItemView(overlay: overlay)
                        .position(
                            x: overlay.position.x * geo.size.width,
                            y: overlay.position.y * geo.size.height
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let x = value.location.x / geo.size.width
                                    let y = value.location.y / geo.size.height
                                    viewModel.updateOverlayPosition(
                                        overlay.id,
                                        x: min(max(x, 0), 1),
                                        y: min(max(y, 0), 1)
                                    )
                                }
                        )
                        .onTapGesture {
                            viewModel.selectedOverlayId = overlay.id
                        }
                }
            }
        }
    }

    private var overlayList: some View {
        List {
            ForEach(viewModel.overlays) { overlay in
                HStack {
                    Image(systemName: overlay.type.iconName)
                        .foregroundColor(.blue)
                    Text(overlay.type.displayName)
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        viewModel.toggleOverlayVisibility(overlay.id)
                    } label: {
                        Image(systemName: overlay.visible ? "eye.fill" : "eye.slash")
                            .foregroundColor(overlay.visible ? .blue : .gray)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(
                    viewModel.selectedOverlayId == overlay.id
                        ? Color.blue.opacity(0.2)
                        : Color(.systemGray6).opacity(0.15)
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteOverlay(viewModel.overlays[index].id)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct OverlayItemView: View {
    let overlay: Overlay

    var body: some View {
        Group {
            switch overlay.type {
            case .text:
                Text(overlay.content.isEmpty ? "Text" : overlay.content)
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            case .image:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: overlay.size.width * 0.3, height: overlay.size.height * 0.3)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                    }
            case .webcam:
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "web.camera")
                            .foregroundColor(.white)
                    }
            case .web:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: overlay.size.width * 0.3, height: overlay.size.height * 0.3)
                    .overlay {
                        Image(systemName: "globe")
                            .foregroundColor(.white)
                    }
            }
        }
    }
}

struct AddOverlaySheet: View {
    @ObservedObject var viewModel: OverlayEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(OverlayType.allCases, id: \.self) { type in
                    Button {
                        viewModel.addOverlay(type: type)
                        dismiss()
                    } label: {
                        Label(type.displayName, systemImage: type.iconName)
                    }
                    .disabled(type == .web && viewModel.webOverlayCount >= OverlayEditorViewModel.maxWebOverlays)
                }
            }
            .navigationTitle("Add Overlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
