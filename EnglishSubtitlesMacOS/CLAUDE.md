# CLAUDE.md - EnglishSubtitles macOS

This file provides guidance to Claude Code (claude.ai/code) when working with the macOS version of EnglishSubtitles.

## Project Overview

EnglishSubtitles macOS is a macOS application that generates live English subtitles from **screen audio** (not microphone). It captures audio from the screen (e.g., YouTube, VLC, Netflix, streaming videos) using ScreenCaptureKit and transcribes it locally using SwiftWhisper with Whisper large models.

The app displays subtitles in a **floating subtitle window** controlled via the macOS menu bar. Simple, intuitive, and native macOS experience similar to QuickTime.

**Key Features:**
- **Menu bar control** - "Subtitles → Show Subtitles" toggles subtitle window
- Captures **screen audio** via ScreenCaptureKit (not microphone)
- Uses **SwiftWhisper** (not WhisperKit) for local transcription
- **Floating window** - Always-on-top, click-through subtitle display
- **Auto-start/stop** - Opening window starts transcription, closing window stops it
- **Fullscreen support** - Works with most apps in fullscreen (YouTube, VLC)
- **Voice Activity Detection (VAD)** using WebRTC for audio segmentation
- Supports **larger Whisper models** (large-v2, large-v3) with persistent storage
- Models stored in Application Support directory

**Key Differences from iOS version:**
- Captures **screen audio** via ScreenCaptureKit (not microphone)
- Uses **SwiftWhisper** (not WhisperKit)
- **Menu bar control** - Toggle subtitle window via menu (not auto-start)
- **Floating window** for subtitle display (not fullscreen view)
- Includes **WebRTC VAD** for audio segmentation
- Supports **larger Whisper models** (large-v2, large-v3) with persistent storage
- Works with **any application** (not just mobile apps)

## Project Structure

```
EnglishSubtitlesMacOS/
├── Models/
│   └── Subtitle.swift                       # Subtitle data model
├── ViewModels/
│   └── SubtitlesViewModel.swift             # Main ViewModel
├── Views/
│   ├── ContentView.swift                    # Root view wrapper
│   ├── SubtitleFloatingWindow.swift         # Floating subtitle window
│   └── SubtitleView.swift                   # Subtitle display UI
├── Services/
│   ├── ScreenAudioCaptureService.swift      # ScreenCaptureKit integration
│   ├── TranscriptionService.swift           # SwiftWhisper integration
│   ├── VADService.swift                     # WebRTC Voice Activity Detection
│   └── ModelDownloadService.swift           # Downloads and manages Whisper models
├── Utilities/
│   └── AudioBufferProcessor.swift           # Audio buffer conversion utilities
└── EnglishSubtitlesMacOSApp.swift           # App entry point with menu bar
```

## Architecture

### macOS-Specific Services

1. **ScreenAudioCaptureService** - Captures screen audio using ScreenCaptureKit
2. **TranscriptionService** - Integrates SwiftWhisper for local transcription
3. **VADService** - Voice Activity Detection using WebRTC
4. **ModelDownloadService** - Downloads and manages large Whisper models
5. **SubtitleFloatingWindow** - Floating, always-on-top, click-through window for subtitle display

### Data Flow

1. App launches → Menu bar appears with "Subtitles" menu
2. User selects "Subtitles → Show Subtitles" from menu bar
3. Floating subtitle window opens and appears on screen
4. `ScreenAudioCaptureService` begins capturing screen audio
5. `VADService` uses WebRTC to monitor audio and detect speech segments
6. When speech ends (silence detected by WebRTC VAD), audio segment sent to `TranscriptionService`
7. `TranscriptionService` uses SwiftWhisper to transcribe segment locally
8. Transcription result updates `SubtitlesViewModel`
9. `SubtitleFloatingWindow` displays subtitle text in floating window
10. User closes window → Transcription stops automatically
11. Menu item returns to "Subtitles → Show Subtitles"

### Menu Bar Integration

The app uses native macOS menu bar for control:
- **Menu Item**: "Subtitles → Show Subtitles"
- **Action**: Opens floating window and starts transcription
- **Toggle**: Menu changes to "Subtitles → Hide Subtitles" when active
- **Close Window**: Automatically stops transcription and resets menu
- **Native Experience**: Similar to QuickTime's Picture-in-Picture behavior

### Floating Window Behavior

The subtitle floating window:
- **Always-on-top** - Floats above all other windows
- **Click-through** - Mouse clicks pass through to underlying content
- **Fullscreen compatible** - Works with most apps in fullscreen (YouTube, VLC)
- **DRM limitations** - May not work with DRM-protected fullscreen (Netflix, Disney+, Apple TV+)
- **Customizable position** - Bottom center by default, user can reposition
- **Auto-sizing** - Adjusts size based on subtitle text length
- **Auto-start/stop** - Opening window starts transcription, closing stops it

### Voice Activity Detection (WebRTC VAD)

The VAD service uses WebRTC's built-in Voice Activity Detection:
- Monitors audio stream for speech vs silence
- Detects speech start when WebRTC VAD indicates speech
- Detects speech end when silence duration exceeds threshold (e.g., 1.5 seconds)
- Segments audio into chunks for transcription
- Prevents sending silence to transcription service
- More robust than simple RMS-based detection

## Development Setup

### Requirements
- macOS 13.0+ (Ventura or later)
- Xcode 16.0+
- Swift 5.9+

### Dependencies (Swift Package Manager)
- **SwiftWhisper** - Local Whisper model inference
  - URL: TBD (SwiftWhisper package URL)
- **WebRTC** - Voice Activity Detection

### Permissions Required

The app requires **Screen Recording** permission in macOS:
- System Settings → Privacy & Security → Screen Recording
- Add EnglishSubtitles to allowed apps

Configuration in `project.pbxproj`:
```
INFOPLIST_KEY_NSSystemExtensionUsageDescription = "EnglishSubtitles needs screen recording access to capture audio from your screen.";
```

## Common Commands

```bash
# Build the macOS app
xcodebuild -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitlesMacOS build

# Run tests
xcodebuild test -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitlesMacOS -destination 'platform=macOS'
```

## Code Conventions

- Use `if let handler {` instead of `if let handler = handler {`
- Main actor annotation on ViewModels: `@MainActor`
- Services are plain classes (not ObservableObject)
- Views use SwiftUI and follow declarative patterns
- Overlay window uses NSWindow with click-through and always-on-top properties

## Model Configuration

The app supports multiple Whisper models stored in Application Support:

```swift
// Default model: large-v3
let modelPath = ModelDownloadService.shared.getModelPath(for: "large-v3")
let transcriptionService = TranscriptionService(modelPath: modelPath)
```

**Available Models:**
- `large-v3` (~3GB) - **Default** - Best accuracy, multilingual
- `large-v2` (~3GB) - Previous generation, still very accurate
- `medium` (~1.5GB) - Faster, good accuracy
- `small` (~500MB) - Fast, decent accuracy
- `base` (~150MB) - Very fast, lower accuracy
- `tiny` (~75MB) - Fastest, basic accuracy

**Model Storage:**
- Location: `~/Library/Application Support/EnglishSubtitles/models/`
- Downloaded on first launch or on-demand
- Persistent across app launches

## Key Implementation Details

### Audio Capture with ScreenCaptureKit

```swift
// Configure screen audio capture
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let display = content.displays.first!

let filter = SCContentFilter(display: display, excludingWindows: [])
let config = SCStreamConfiguration()
config.capturesAudio = true
config.sampleRate = 16000 // Whisper requires 16kHz
config.channelCount = 1   // Mono

let stream = SCStream(filter: filter, configuration: config, delegate: self)
```

### Voice Activity Detection

```swift
// Detect speech segments using WebRTC VAD
import WebRTC

func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    // Use WebRTC's built-in VAD
    let vadResult = webRTCVAD.process(buffer)

    if vadResult.isSpeech {
        // Speech detected
        if !isSpeaking {
            isSpeaking = true
            currentSegment = []
        }
        currentSegment.append(buffer)
        lastSpeechTime = Date()
    } else {
        // Silence detected
        if isSpeaking && Date().timeIntervalSince(lastSpeechTime) > silenceThreshold {
            // End of speech - send for transcription
            transcribe(currentSegment)
            isSpeaking = false
            currentSegment = []
        }
    }
}
```

### Floating Window

```swift
// Create floating, always-on-top, click-through window
class SubtitleFloatingWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Always on top
        self.level = .floating

        // Click-through
        self.ignoresMouseEvents = true

        // Transparent background
        self.isOpaque = false
        self.backgroundColor = .clear

        // Show on all spaces and in fullscreen
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Position at bottom center
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - frame.width) / 2
            let y = 100  // 100 pixels from bottom
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    // Called when window is closed
    override func close() {
        // Stop transcription when window closes
        ScreenAudioCaptureService.shared.stop()
        super.close()
    }
}
```

### Menu Bar Implementation

```swift
// In EnglishSubtitlesMacOSApp.swift
@main
struct EnglishSubtitlesMacOSApp: App {
    @State private var subtitleWindow: SubtitleFloatingWindow?

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button(subtitleWindow == nil ? "Show Subtitles" : "Hide Subtitles") {
                    toggleSubtitles()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }

    func toggleSubtitles() {
        if let window = subtitleWindow {
            // Hide subtitles
            window.close()
            subtitleWindow = nil
        } else {
            // Show subtitles
            let window = SubtitleFloatingWindow()
            window.makeKeyAndOrderFront(nil)
            subtitleWindow = window

            // Start transcription
            ScreenAudioCaptureService.shared.start()
        }
    }
}
```

## Notes

- macOS-only application (does not run on iOS)
- Captures **screen audio** only (not microphone)
- Uses larger Whisper models for higher accuracy
- **Menu bar control** - "Subtitles → Show Subtitles" to toggle
- **Floating window** displays subtitles on top of any app
- Works in fullscreen for most apps (YouTube, VLC)
- DRM-protected fullscreen may block overlay (Netflix, Disney+, Apple TV+)
- Models downloaded on first launch (~3GB for large-v3)
- 100% free and private - everything runs locally
- No internet required after model download
- No browser extension required
- Native macOS experience similar to QuickTime

## Testing

- Use `testAudioFile()` method in `TranscriptionService` to test with audio files
- Record test audio with QuickTime Player (Audio Recording)
- Place test files in `~/Library/Application Support/EnglishSubtitles/test/`

## Do Not Run Tests

- Do not run tests by yourself
- Ask the user to run tests manually

## Code Style

- Replace `if let inputNode = inputNode {` with `if let inputNode {`
- Use `Task.sleep(for: .seconds(2))` format for sleep
- Do not add fallbacks - throw errors and let the user handle them
- Created by Amr Aboelela (not "Created by Claude")
