import Foundation

struct OverlayTemplate {
    let name: String
    let preset: ScenePreset
    let overlays: [TemplateOverlay]

    struct TemplateOverlay {
        let type: OverlayType
        let position: OverlayPosition
        let size: OverlaySize
        let content: String
    }
}

enum OverlayTemplateFactory {
    static func template(for preset: ScenePreset) -> OverlayTemplate {
        switch preset {
        case .talkingHead: return talkingHead
        case .gaming: return gaming
        case .irl: return irl
        case .minimal: return minimal
        }
    }

    static let talkingHead = OverlayTemplate(
        name: "Talking Head",
        preset: .talkingHead,
        overlays: [
            // Webcam centered (main view - camera already captures this)
            // Name/title overlay at bottom
            .init(
                type: .text,
                position: OverlayPosition(x: 0.5, y: 0.9),
                size: OverlaySize(width: 300, height: 40),
                content: "Stream Title"
            ),
            // Web widget for alerts at top
            .init(
                type: .web,
                position: OverlayPosition(x: 0.5, y: 0.1),
                size: OverlaySize(width: 400, height: 100),
                content: ""
            )
        ]
    )

    static let gaming = OverlayTemplate(
        name: "Gaming",
        preset: .gaming,
        overlays: [
            // Webcam overlay in bottom-left corner
            .init(
                type: .webcam,
                position: OverlayPosition(x: 0.15, y: 0.8),
                size: OverlaySize(width: 200, height: 150),
                content: ""
            ),
            // Chat overlay on the right side
            .init(
                type: .web,
                position: OverlayPosition(x: 0.9, y: 0.5),
                size: OverlaySize(width: 250, height: 400),
                content: ""
            ),
            // Recent event at top
            .init(
                type: .text,
                position: OverlayPosition(x: 0.5, y: 0.05),
                size: OverlaySize(width: 300, height: 30),
                content: "Latest Follower: --"
            )
        ]
    )

    static let irl = OverlayTemplate(
        name: "IRL",
        preset: .irl,
        overlays: [
            // Location/title at top
            .init(
                type: .text,
                position: OverlayPosition(x: 0.5, y: 0.05),
                size: OverlaySize(width: 300, height: 30),
                content: "IRL Stream"
            ),
            // Alert area at bottom
            .init(
                type: .web,
                position: OverlayPosition(x: 0.5, y: 0.85),
                size: OverlaySize(width: 350, height: 80),
                content: ""
            )
        ]
    )

    static let minimal = OverlayTemplate(
        name: "Minimal",
        preset: .minimal,
        overlays: [
            // Just a simple text overlay with stream title
            .init(
                type: .text,
                position: OverlayPosition(x: 0.5, y: 0.95),
                size: OverlaySize(width: 200, height: 24),
                content: ""
            )
        ]
    )

    static func applyTemplate(_ template: OverlayTemplate, to viewModel: OverlayEditorViewModel) {
        // Clear existing overlays
        for overlay in viewModel.overlays {
            viewModel.deleteOverlay(overlay.id)
        }

        // Add template overlays
        for templateOverlay in template.overlays {
            viewModel.addOverlay(type: templateOverlay.type, content: templateOverlay.content)

            // Update position and size of the last added overlay
            if let lastOverlay = viewModel.overlays.last {
                viewModel.updateOverlayPosition(
                    lastOverlay.id,
                    x: templateOverlay.position.x,
                    y: templateOverlay.position.y
                )
                viewModel.updateOverlaySize(
                    lastOverlay.id,
                    width: templateOverlay.size.width,
                    height: templateOverlay.size.height
                )
            }
        }
    }
}
