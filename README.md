# StreamForge iOS

A live streaming app for iPhone. Stream to Twitch, YouTube, or custom RTMP servers with multi-destination support, overlays, alerts, and real-time performance monitoring.

## Requirements

- macOS 15.0+
- Xcode 16.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.42+
- iOS 17.0+ deployment target
- Physical iPhone recommended for camera/streaming features (simulator works for UI)

## Setup

### 1. Install XcodeGen (if not installed)

```bash
brew install xcodegen
```

### 2. Clone and generate the project

```bash
git clone <repo-url>
cd rave-stream
xcodegen generate
```

This creates `StreamForge.xcodeproj` from `project.yml`.

### 3. Open in Xcode

```bash
open StreamForge.xcodeproj
```

### 4. Configure signing

1. Select the **StreamForge** target in Xcode
2. Go to **Signing & Capabilities**
3. Select your development team
4. Xcode will auto-manage provisioning profiles

### 5. Build and run

- Select a simulator (e.g. iPhone 16) or a connected device
- Press `Cmd + R` to build and run

> Camera, microphone, screen capture, and RTMP streaming require a **physical device**. The simulator will run the full UI but hardware features won't function.

## Project Structure

```
StreamForge/
├── App/                    # App entry point, DI container, navigation
├── Models/                 # Data models (User, Destination, StreamSession, etc.)
├── Services/               # Business logic
│   ├── AuthService          # Guest/email/OAuth authentication
│   ├── StreamingService     # Stream lifecycle & multi-destination management
│   ├── CaptureService       # AVFoundation camera + ReplayKit screen capture
│   ├── VideoEncoder         # H.264/HEVC encoding via VideoToolbox
│   ├── RTMPConnection       # RTMP/RTMPS protocol over NWConnection
│   ├── AudioService         # Audio levels, input selection, volume control
│   ├── AlertService         # Stream alerts (follows, subs, donations)
│   ├── ChatService          # Multi-provider live chat aggregation
│   ├── PerformanceMonitor   # Thermal, bitrate, dropped frames tracking
│   ├── PerformanceCoach     # Adaptive quality recommendations
│   ├── NetworkMonitor       # Connectivity & disconnect protection
│   ├── KeychainService      # Secure credential storage
│   └── APIClient            # REST backend client
├── ViewModels/             # MVVM view models for each screen
├── Views/                  # SwiftUI views
│   ├── Splash/              # Launch animation
│   ├── Auth/                # Login / guest entry
│   ├── Home/                # Dashboard with Quick Go Live
│   ├── Destinations/        # Manage streaming destinations
│   ├── StreamSetup/         # Configure stream settings
│   ├── OverlayEditor/       # Drag-and-drop overlay positioning
│   ├── LiveControlRoom/     # Live controls, monitoring, scene switching
│   ├── StreamSummary/       # Post-stream quality report
│   ├── Settings/            # App preferences
│   └── Components/          # Reusable UI (audio meter, alerts, chat)
├── Utilities/              # Device tier detection, overlay templates
└── Resources/              # Assets, Info.plist
```

## Configuration

### Backend (Optional)

The app works fully offline in local-only mode. To enable cloud sync:

```swift
// In your app initialization or settings
APIClient.shared.configure(
    baseURL: "https://your-api-server.com",
    authToken: "user-auth-token"
)
```

### Stream Destinations

Add destinations in the **Destinations** tab:

| Type | Setup |
|------|-------|
| **Twitch** | Connects via OAuth (requires Twitch app credentials) |
| **YouTube** | Connects via OAuth (requires Google Cloud project) |
| **Custom RTMP** | Enter RTMP URL + stream key manually |

### Quality Presets

| Preset | Resolution | FPS | Bitrate |
|--------|-----------|-----|---------|
| Performance | 720p | 30 | 1500 kbps |
| Balanced | 720p | 30 | 2500 kbps |
| Quality | 1080p | 60 | 4000 kbps |

Settings are automatically clamped based on detected device tier (low/mid/high).

## Key Files

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen project definition |
| `PRD.json` | Product requirements document |
| `FEATURES.md` | Feature implementation status |

## Regenerating the Xcode Project

After adding/removing source files or changing build settings:

```bash
xcodegen generate
```

The `.xcodeproj` is generated from `project.yml` and should not be edited manually.

## Architecture

- **Pattern**: MVVM with service layer
- **UI**: SwiftUI (iOS 17+)
- **Streaming**: VideoToolbox (encoding) + NWConnection (RTMP transport)
- **Capture**: AVFoundation (camera) + ReplayKit (screen)
- **Storage**: UserDefaults (settings/sessions) + Keychain (credentials/stream keys)
- **Networking**: NWPathMonitor (connectivity) + URLSession (API)
