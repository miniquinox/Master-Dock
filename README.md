#  Master Dock

> **The ultimate native macOS productivity dock powered by Apple Intelligence, multitouch gestures, and liquid glass design.**

Master Dock is a high-performance, native macOS menu bar and overlay dock application built with **Swift 5.10 / macOS 14+ / Sequoia 15+** and **SwiftUI**.

---

## ✨ Key Features

- 🖐️ **Low-Level Multitouch Gesture Engine**:
  - Interactive **2-Finger Left Edge Swipe** to smoothly reveal and dismiss Master Dock.
  - Interactive **2-Finger Top Edge Swipe** to directly launch the Apple Intelligence Voice Assistant.
  - Global keyboard shortcuts: `Option + Space` (Toggle Dock) & `Option + Shift + Space` (Toggle Voice Mode).
-  **Native Apple Intelligence Foundation Model**:
  - Direct on-device neural language model inference via Apple's official `FoundationModels` framework.
  - 100% private, zero-latency on-device token streaming powered by Apple Silicon Neural Engine (NPU).
  - Quick action prompt library with one-click contextual templates.
  - Attach any file (`+` button) for real-time document analysis, code review, and summarization.
- 🎙️ **Real-Time Voice Companion**:
  - Live audio buffer streaming speech recognition (`SFSpeechAudioBufferRecognitionRequest`).
  - Intelligent Voice Activity Detection (VAD) that auto-commits and answers after 1.8 seconds of natural silence.
  - Dynamic audio waveform visualizer and liquid glowing status orb.
- 🖼️ **Native macOS Desktop Wallpaper Switcher**:
  - Live preview and one-click application of official macOS system wallpapers (`/System/Library/Desktop Pictures`).
  - Asynchronous downsampled thumbnail caching at 120 FPS.
- 📋 **Liquid Clipboard History**:
  - Continuous pasteboard monitor saving your 10 most recent clippings with visual type badges and click-to-copy.
- 📅 **Today's Agenda & Calendar**:
  - EventKit integration with live countdown timers and meeting detail sheets.
- 🎵 **Now Playing Media Controller**:
  - Controls playback for Apple Music and Spotify via Apple Events script bridging.
- ✅ **Daily Checklist**:
  - Interactive daily task manager with persistent completion tracking.
- 📊 **Widget Drawer & System Stats**:
  - Live circular dials for CPU usage, memory pressure, storage, and battery.
- 🎨 **macOS Notification Center Glass Aesthetics**:
  - Pure Apple glassmorphic blur (`NSVisualEffectView` `fullScreenUI` / `behindWindow`) with soft edge dissolve gradient masks.
- ⚙️ **Configurable Dimensions**:
  - Live width slider in Settings (`240pt` to `480pt`) with instant interactive resizing.

---

## 🛠️ Building & Running

### Requirements
- **macOS 14.0+** (Apple Silicon M1/M2/M3/M4 recommended for Apple Intelligence on-device models)
- **Xcode 15.0+** / Swift 5.10+ command line tools

### Build & Run Tests
```bash
./build_and_test.sh
```

### Package Application Bundle
```bash
./package_app_bundle.sh
open MasterDock.app
```

---

## 📂 Project Architecture

```
Master Dock/
├── Sources/
│   ├── MasterDockMultitouchC/     # C bridging to MultitouchSupport.framework
│   ├── MasterDockCore/            # Gesture State Machine, Glass Windowing, Permissions
│   ├── MasterDockServices/        # System Services: Clipboard, Wallpapers, Calendar, Media
│   ├── MasterDockAI/              # Apple Intelligence Foundation Model, Voice Pipeline, VAD
│   ├── MasterDockUI/              # SwiftUI Liquid Glass Design System & Section Views
│   └── MasterDockApp/             # App entry point, ViewModel & Menu Bar Controller
├── Tests/
│   └── MasterDockTests/           # Comprehensive Unit & Integration Test Suite
├── MasterDock.entitlements         # Microphone, Speech, Calendar, and Security Entitlements
├── Package.swift                  # Swift Package Manager Manifest
├── build_and_test.sh              # Automated build & test pipeline
└── package_app_bundle.sh          # Codesigning & .app bundle packaging
```

---

## 📄 License
MIT License. Crafted with Swift on macOS.
