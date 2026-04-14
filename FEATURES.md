# StreamForge iOS - Feature Status

## Fully Implemented

### Auth & User
- [x] Auth state management (guest, email, twitch, youtube provider models)
- [x] User persistence (UserDefaults + Keychain)
- [x] Login/Guest screen with OAuth button layout

### Destinations
- [x] Destination CRUD (Twitch, YouTube, Custom RTMP)
- [x] Secure stream key storage (Keychain)
- [x] Stream protocol support (rtmp/rtmps/srt models)
- [x] Destination type rules (OAuth vs manual, editable fields)

### Stream Setup
- [x] Stream setup form (title, description, destinations, resolution, fps, bitrate, orientation, captureMode)
- [x] Quality presets (performance/balanced/quality with bitrate mapping)
- [x] Field conditions (RTMP URL/stream key shown only for custom_rtmp)
- [x] Max 3 destinations per stream

### Capture
- [x] Camera capture (AVCaptureSession with front/rear camera)
- [x] Camera switching (beginConfiguration/commitConfiguration device swap)
- [x] Screen capture (RPScreenRecorder with video/audio handlers)
- [x] Privacy screensaver (auto-activate on app background, manual toggle)
- [x] Pause placeholder (state management for static image feed)
- [x] Orientation lock
- [x] Video output with sample buffer delegate support

### Audio
- [x] Audio service (AVAudioEngine-based monitoring)
- [x] Audio level meter (RMS->dB->normalized, real-time via input tap)
- [x] Mic toggle (actual volume-based mute via inputNode)
- [x] Separate mic/device volume controls
- [x] Audio input selection (AVAudioSession preferredInput)
- [x] Audio route change observation
- [x] Audio level meter UI component
- [x] Noise reduction toggle (setting persisted)

### Streaming & Encoding
- [x] H.264 hardware encoding (VideoToolbox VTCompressionSession)
- [x] HEVC optional codec support
- [x] Real-time encoding with bitrate limits
- [x] Dynamic bitrate adjustment during stream
- [x] Key frame interval configuration
- [x] RTMP connection (NWConnection TCP/TLS)
- [x] RTMP handshake (C0/C1/S0/S1/S2/C2)
- [x] RTMP connect + publish commands (AMF0 encoding)
- [x] Video/audio packet building and sending
- [x] RTMPS (TLS) support
- [x] Multi-destination RTMP connections
- [x] Real-time bitrate tracking (bytes/sec -> kbps)
- [x] Graceful degradation on primary destination failure

### Overlays & Scenes
- [x] Overlay editor (drag-to-position, add/remove, visibility toggle)
- [x] Overlay type enforcement (max 4 total, max 2 web)
- [x] Overlay templates (talking_head, gaming, irl, minimal presets)
- [x] Template application to overlay editor
- [x] Scene model & presets (talking_head, gaming, irl, minimal)
- [x] Scene quick-switch UI in LiveControlRoom

### Widgets & Alerts
- [x] Widget types (alert_box, chat_box, event_list, goal)
- [x] Widget model with position/size/URL
- [x] Alert types (follow, subscribe, bits, donation, superchat, membership)
- [x] Alert event queue with auto-dismiss
- [x] Alert configuration (enabled types, duration, sound)
- [x] Alert banner UI with provider-colored styling
- [x] In-app alert preview (test all 6 alert types)
- [x] Alert overlay view with spring animations

### Live Chat
- [x] Chat message model (provider, username, badges, emotes)
- [x] Chat service with multi-provider support
- [x] Chat provider connection framework (Twitch IRC, YouTube polling)
- [x] Viewer count tracking per provider
- [x] Chat highlights with toast display (max 2 on screen)
- [x] Auto-highlight for moderator/subscriber messages
- [x] Highlight rotation with auto-dismiss (8s)
- [x] Chat toast UI with provider badges

### Performance
- [x] Performance monitoring UI (bitrate, dropped frames, thermal, connection health)
- [x] Thermal state observer (ProcessInfo thermalStateDidChangeNotification)
- [x] Device tier matrix (auto-detect low/mid/high via cores+RAM)
- [x] Device tier clamping (resolution, fps, bitrate per tier)
- [x] Performance coach (evaluate thermal + drop frames -> suggest actions)
- [x] Adaptive behavior (lower fps, reduce bitrate, disable overlays, cap preview)
- [x] Performance warnings with severity levels
- [x] Stream summary (quality score 0-100, top issues, suggestions)

### Network
- [x] Network monitor (NWPathMonitor for wifi/cellular/wired)
- [x] Disconnect protection (120s hold with countdown)
- [x] Auto-reconnect logic (max 5 attempts, 3s delay)
- [x] Connection type detection and display
- [x] Protection expiration callback

### Backend API
- [x] REST API client (GET/POST/PATCH/DELETE)
- [x] Auth endpoints (login, oauth, guest)
- [x] Destination endpoints (CRUD)
- [x] Stream endpoints (CRUD, start, stop, reconnect)
- [x] Overlay endpoints (CRUD)
- [x] Scene endpoints (CRUD)
- [x] Performance endpoints (post samples, get summary)
- [x] Bearer token auth header
- [x] Configurable base URL

### Settings & Navigation
- [x] Settings persistence (resolution, fps, orientation, live priority mode, noise reduction)
- [x] Splash screen with animation
- [x] Tab-based navigation (Home, Destinations, Stream, Settings)
- [x] Live control room (mic, camera flip, pause, orientation lock, stop)
- [x] Quick Go Live (last destination, balanced preset, skip setup)
- [x] Data persistence (guest=local_only, authenticated=local+optional sync)

## Pending (Require External Integration)
- [ ] Twitch OAuth PKCE flow (requires Twitch app credentials)
- [ ] YouTube OAuth backend exchange (requires Google Cloud project)
- [ ] Twitch IRC WebSocket connection (framework in place, needs credential wiring)
- [ ] YouTube Live Chat API polling (framework in place, needs API key)
- [ ] Companion web app (separate web project)
- [ ] Multistream backend relay/transcode (requires server infrastructure)
- [ ] Noise reduction DSP processing (setting persisted, no audio filter applied)
- [ ] Web overlay CPU budget enforcement (limits in place, WKWebView throttling needed)
- [ ] SRT transport protocol (model defined, NWConnection adaptation needed)
