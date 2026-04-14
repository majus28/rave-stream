import Foundation

final class OverlayEditorViewModel: ObservableObject {
    @Published var overlays: [Overlay] = []
    @Published var selectedOverlayId: UUID?
    @Published var showAddOverlaySheet: Bool = false

    static let maxOverlayCount = 4
    static let maxWebOverlays = 2

    var streamSessionId: UUID

    init(streamSessionId: UUID) {
        self.streamSessionId = streamSessionId
    }

    var selectedOverlay: Overlay? {
        overlays.first { $0.id == selectedOverlayId }
    }

    var canAddOverlay: Bool {
        overlays.count < Self.maxOverlayCount
    }

    var webOverlayCount: Int {
        overlays.filter { $0.type == .web }.count
    }

    func addOverlay(type: OverlayType, content: String = "") {
        guard canAddOverlay else { return }
        if type == .web && webOverlayCount >= Self.maxWebOverlays { return }

        let overlay = Overlay(
            streamSessionId: streamSessionId,
            type: type,
            content: content
        )
        overlays.append(overlay)
        selectedOverlayId = overlay.id
    }

    func updateOverlayPosition(_ id: UUID, x: CGFloat, y: CGFloat) {
        guard let index = overlays.firstIndex(where: { $0.id == id }) else { return }
        overlays[index].position = OverlayPosition(x: x, y: y)
    }

    func updateOverlaySize(_ id: UUID, width: CGFloat, height: CGFloat) {
        guard let index = overlays.firstIndex(where: { $0.id == id }) else { return }
        overlays[index].size = OverlaySize(width: width, height: height)
    }

    func toggleOverlayVisibility(_ id: UUID) {
        guard let index = overlays.firstIndex(where: { $0.id == id }) else { return }
        overlays[index].visible.toggle()
    }

    func deleteOverlay(_ id: UUID) {
        overlays.removeAll { $0.id == id }
        if selectedOverlayId == id {
            selectedOverlayId = nil
        }
    }
}
