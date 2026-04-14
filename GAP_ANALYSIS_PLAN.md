StreamForge vs StreamChamp Gap Plan

Objective
Build feature parity with StreamChamp’s public feature set while fixing current correctness gaps.

Phase 0: Fix Critical Correctness Issues
1. Wire live controls to real stream pipeline
- Route mic mute to `StreamingService.setMicMuted(_:)`.
- Disable Pause in UI or implement true pause in `HKStreamManager`.
- Files: `StreamForge/ViewModels/LiveControlViewModel.swift`, `StreamForge/Services/StreamingService.swift`, `StreamForge/Services/HKStreamManager.swift`, `StreamForge/Views/LiveControlRoom/LiveControlRoomView.swift`.
2. Restore destination persistence on launch
- Call `destinationService.loadIfNeeded()` on app start.
- Files: `StreamForge/App/StreamForgeApp.swift`, `StreamForge/Services/DestinationService.swift`.
3. Fix dropped-frame accounting
- Track per-interval deltas, not cumulative sums.
- Update `connectionHealth` to use recent deltas.
- Files: `StreamForge/Services/PerformanceMonitor.swift`.
4. Remove double unlock in broadcast extension
- Remove the second `CVPixelBufferUnlockBaseAddress`.
- Files: `BroadcastExtension/FrameProcessor.swift`.
5. Main-thread safety for `@Published` in streaming manager
- Mark `HKStreamManager` as `@MainActor` or funnel updates through `MainActor.run`.
- Files: `StreamForge/Services/HKStreamManager.swift`.
6. Enforce single-destination streaming in UI
- Block “Go Live” when multiple destinations are selected unless relay is enabled.
- Files: `StreamForge/ViewModels/StreamSetupViewModel.swift`, `StreamForge/Views/StreamSetup/StreamSetupView.swift`.

Phase 1: Audio and Control Parity
1. Integrate `AudioService` into streaming path
- Apply mic/app audio volume to `HKStreamManager` and/or broadcast extension.
- Expose live audio meters in the control room.
- Files: `StreamForge/Services/AudioService.swift`, `StreamForge/Services/HKStreamManager.swift`, `StreamForge/Views/Components/AudioControlsView.swift`, `StreamForge/Views/LiveControlRoom/LiveControlRoomView.swift`.
2. Interruption notifications
- Wire `NetworkMonitor` to show in-app alerts and status badges.
- Files: `StreamForge/Services/NetworkMonitor.swift`, `StreamForge/Views/LiveControlRoom/LiveControlRoomView.swift`.

Phase 2: Camera and Overlay Parity
1. Implement camera capture modes
- Support front and rear camera input for `HKStreamManager`.
- Provide PiP overlay and positioning.
- Files: `StreamForge/Services/HKStreamManager.swift`, `StreamForge/Models/StreamSession.swift`, `StreamForge/Views/StreamSetup/StreamSetupView.swift`, `StreamForge/Views/LiveControlRoom/LiveControlRoomView.swift`.
2. Improve overlay editor UX
- Add drag, resize, snap, and z-order controls.
- Make overlay cache invalidation deterministic.
- Files: `StreamForge/ViewModels/OverlayEditorViewModel.swift`, `StreamForge/Utilities/SceneLayout.swift`, `BroadcastExtension/FrameProcessor.swift`.

Phase 3: Platform Features
1. RTMPS support
- Validate and test RTMPS URLs end-to-end.
- Add UI warnings for unsupported protocols.
- Files: `StreamForge/Models/Destination.swift`, `StreamForge/Services/StreamingService.swift`.
2. Recording and export
- Add local recording of streams and share/export UI.
- Files: new `StreamForge/Services/RecordingService.swift`, `StreamForge/Views/StreamSummary/StreamSummaryView.swift`.
3. Chat notifications and TTS
- Implement Twitch/YouTube chat integration and system notifications.
- Add TTS or sound alerts pipeline.
- Files: `StreamForge/Services/ChatService.swift`, `StreamForge/Services/AlertService.swift`.

Phase 4: Device Tier Enhancements
1. 1440p support for iPad Pro/Air
- Add 1440p preset gated by device capability.
- Files: `StreamForge/Models/StreamSession.swift`, `StreamForge/Utilities/DeviceTier.swift`.

Acceptance Criteria
1. Live controls (mic mute, pause/BRB) reliably affect stream output.
2. Destinations persist across relaunch.
3. Performance summary uses correct drop-frame math.
4. Broadcast extension no longer double-unlocks pixel buffers.
5. Streaming manager state updates are main-thread safe.
6. Single-destination streaming is enforced or relay is implemented.
7. Audio controls change live stream levels.
8. Camera capture with PiP works in at least one mode.
9. RTMPS streams connect successfully in production.
10. Recording/export produces a playable file.
11. Chat notifications and TTS alerts function for at least one provider.

Testing Plan
1. Unit tests for `PerformanceMonitor.generateSummary()`.
2. Integration test: mic mute stops audio output.
3. UI test: destination persistence across relaunch.
4. Manual test checklist: RTMP/RTMPS, camera modes, overlays, recording, chat notifications.
