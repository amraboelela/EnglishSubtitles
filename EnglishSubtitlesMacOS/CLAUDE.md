# CLAUDE.md - EnglishSubtitles macOS

This file provides guidance to Claude Code (claude.ai/code) when working with the macOS version of EnglishSubtitles.

## Project Overview

EnglishSubtitles macOS is a macOS application that generates live English subtitles from **screen audio** (not microphone). It captures audio from the screen (e.g., YouTube, VLC, some streaming apps) using ScreenCaptureKit and transcribes it locally using SwiftFasterWhisper with Whisper large models (up to large-v2).

The app displays subtitles in a **floating subtitle window** controlled via the macOS menu bar. Simple, intuitive, and native macOS experience similar to QuickTime.

**Key Features:**
- **Menu bar control** - "Subtitles → Show Subtitles" toggles subtitle window
- Captures **screen audio** via ScreenCaptureKit (not microphone)
- Uses **SwiftFasterWhisper** (not WhisperKit) for local transcription
- **Faster inference** using faster-whisper backend (CTranslate2)
- **Adaptive speech detection** - SwiftFasterWhisper performs adaptive speech detection and silence filtering
- **Floating window** - Always-on-top, click-through subtitle display
- **Auto-start/stop** - Opening window starts transcription, closing window stops it
- **Fullscreen support** - Works with most apps in fullscreen (YouTube, VLC)
- **DRM limitations** - May not work with DRM-protected content (audio capture may work but overlay may fail)
- Supports **Whisper models** (medium, large-v2) with persistent storage
- Models stored in Application Support directory

**Key Differences from iOS version:**
- Captures **screen audio** via ScreenCaptureKit (not microphone)
- Uses **SwiftFasterWhisper** (not WhisperKit)
- **Faster inference** using CTranslate2 backend with built-in VAD
- **Menu bar control** - Toggle subtitle window via menu (not auto-start)
- **Floating window** for subtitle display (not fullscreen view)
- Supports **larger Whisper models** (medium, large-v2) with persistent storage
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
│   ├── TranscriptionService.swift           # SwiftFasterWhisper integration (adaptive speech detection)
│   └── ModelDownloadService.swift           # Downloads and manages Whisper models
├── Utilities/
│   └── AudioBufferProcessor.swift           # Audio buffer conversion utilities
└── EnglishSubtitlesMacOSApp.swift           # App entry point with menu bar
```

## Architecture

### macOS-Specific Services

1. **ScreenAudioCaptureService** - Captures screen audio using ScreenCaptureKit
2. **TranscriptionService** - Integrates SwiftFasterWhisper for local transcription with adaptive speech detection
3. **ModelDownloadService** - Downloads and manages large Whisper models
4. **SubtitleFloatingWindow** - Floating, always-on-top, click-through window for subtitle display

### Data Flow

1. App launches → Menu bar appears with "Subtitles" menu
2. User selects "Subtitles → Show Subtitles" from menu bar
3. Floating subtitle window opens and appears on screen
4. `ScreenAudioCaptureService` begins capturing screen audio
5. Audio stream sent to `TranscriptionService`
6. `TranscriptionService` uses SwiftFasterWhisper with adaptive speech detection to process audio
7. SwiftFasterWhisper detects speech, segments audio, and transcribes locally
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

### Voice Activity Detection (Built-in)

SwiftFasterWhisper includes adaptive speech detection:
- Monitors audio stream for speech vs silence automatically
- Detects speech segments using adaptive energy-based filtering
- Segments audio into chunks at natural speech boundaries
- Prevents transcribing silence or background noise
- No separate VAD service needed

## Development Setup

### Requirements
- macOS 13.0+ (Ventura or later)
- Xcode 16.0+
- Swift 5.9+

### Dependencies (Swift Package Manager)
- **SwiftFasterWhisper** - Local Whisper model inference using faster-whisper backend
  - URL: `https://github.com/amraboelela/SwiftFasterWhisper.git`
  - Provides faster inference using CTranslate2
  - Includes adaptive speech detection and silence filtering

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
// Default model: large-v2
let modelPath = ModelDownloadService.shared.getModelPath(for: "large-v2")
let transcriptionService = TranscriptionService(modelPath: modelPath)
```

**Available Models:**
- `large-v2` (~3GB) - **Default** - Best accuracy, multilingual
- `medium` (~1.5GB) - Faster, good accuracy
- `small` (~500MB) - Fast, decent accuracy
- `base` (~150MB) - Very fast, lower accuracy
- `tiny` (~75MB) - Fastest, basic accuracy

⚠️ **large-v3 is not supported**
SwiftFasterWhisper uses the 80-mel Whisper pipeline (v1–v2). large-v3 requires 128 mel bands and cannot be used.

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
// SwiftFasterWhisper handles adaptive speech detection internally
// No separate VAD implementation needed

func transcribe(_ audioData: Data) async throws -> TranscriptionResult {
    // SwiftFasterWhisper automatically:
    // 1. Detects speech using adaptive energy-based filtering
    // 2. Segments audio at natural boundaries
    // 3. Transcribes only speech segments
    let result = try await whisper.transcribe(audioData)
    return result
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
- May not work with DRM-protected content (Netflix, Disney+, Apple TV+)
  - Audio capture may work but overlay rendering may fail
  - Sometimes both fail depending on macOS + DRM
- Models downloaded on first launch (~3GB for large-v2)
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
- Never run xcodebuild by yourself
