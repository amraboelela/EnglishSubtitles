# EnglishSubtitles for macOS

A macOS application that generates live English subtitles from **screen audio** using local AI models. Captures audio from any app (YouTube, VLC, Netflix, etc.) and displays subtitles in a **floating window** controlled via the menu bar.

## Key Features

- **Menu Bar Control** - Toggle subtitles with "Subtitles → Show Subtitles" menu item
- **Screen Audio Capture** - Uses ScreenCaptureKit to capture audio from your screen (not microphone)
- **Local AI Transcription** - SwiftWhisper with Whisper large models for highest accuracy
- **Floating Window** - Always-on-top, click-through subtitle display
- **Auto-Start/Stop** - Opening window starts transcription, closing stops it
- **Fullscreen Support** - Works with most apps in fullscreen (YouTube, VLC)
- **Voice Activity Detection** - WebRTC VAD segments audio at natural speech boundaries
- **100% Free & Private** - Everything runs on your Mac, no cloud services
- **Offline Support** - Works without internet after model download
- **Multi-language** - Supports 99+ languages with automatic English translation
- **No Browser Extension Required** - Works with any application
- **Native macOS Experience** - Similar to QuickTime's Picture-in-Picture

## Architecture

### Audio Processing Flow

```
Menu Bar: "Subtitles → Show Subtitles"
    ↓
Floating Window Opens
    ↓
Screen Audio (ScreenCaptureKit)
    ↓
WebRTC VAD (Speech Detection)
    ↓
Audio Segmentation (Natural Speech Boundaries)
    ↓
SwiftWhisper (Local Transcription)
    ↓
Floating Window Display (Always-on-Top)
    ↓
Window Close → Stop Transcription
```

### Core Components

1. **Menu Bar Integration** - Native macOS menu for show/hide control
2. **ScreenAudioCaptureService** - Captures screen audio at 16kHz mono
3. **VADService** - WebRTC-based Voice Activity Detection
4. **TranscriptionService** - SwiftWhisper integration for local AI transcription
5. **ModelDownloadService** - Downloads and manages Whisper models
6. **SubtitleFloatingWindow** - Floating, always-on-top, click-through window for subtitle display

## Requirements

- **macOS 13.0+** (Ventura or later)
- **Xcode 16.0+**
- **Swift 5.9+**
- **~3GB disk space** for large-v3 model
- **Screen Recording permission** (required by ScreenCaptureKit)

## Dependencies

### Swift Package Manager

- **SwiftWhisper** - Local Whisper model inference (TBD: package URL)
- **WebRTC** - Voice Activity Detection

## Installation

### 1. Build the macOS App

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/EnglishSubtitles.git
cd EnglishSubtitles

# Open in Xcode
open EnglishSubtitles.xcodeproj

# Select the EnglishSubtitlesMacOS scheme
# Build and run (⌘R)
```

### 2. Grant Permissions

When you first run the app, macOS will prompt for **Screen Recording** permission:

1. System Settings → Privacy & Security → Screen Recording
2. Enable "EnglishSubtitles"
3. Restart the app

## Usage

1. Launch EnglishSubtitles app
2. Grant Screen Recording permission if prompted (first launch only)
3. Select **"Subtitles → Show Subtitles"** from the menu bar
4. The floating subtitle window appears at the bottom of your screen
5. Transcription starts automatically
6. Play content with foreign language audio (YouTube, VLC, Netflix, etc.)
7. Subtitles appear in the floating window in real-time
8. To stop: Close the floating window or select **"Subtitles → Hide Subtitles"** from menu
9. The floating window works in fullscreen mode for most apps

### Menu Bar Controls

- **Show Subtitles** - Opens floating window and starts transcription
- **Hide Subtitles** - Closes floating window and stops transcription
- **Keyboard Shortcut** - ⌘⇧S (Command+Shift+S) toggles subtitles

### Floating Window

The subtitle floating window is:
- **Always-on-top** - Floats above all other windows
- **Click-through** - Mouse clicks pass through to underlying content
- **Fullscreen compatible** - Works with most apps (YouTube, VLC)
- **DRM limitations** - May not display in DRM-protected fullscreen (Netflix, Disney+, Apple TV+)
- **Draggable** - Reposition by dragging (when not in click-through mode)

### Customization

- **Position** - Drag the window to reposition
- **Font Size** - Adjust in app settings
- **Background** - Semi-transparent black by default

## Voice Activity Detection (VAD)

The app uses **WebRTC's built-in VAD** for robust speech detection:

- **Speech Detection** - Uses WebRTC VAD to detect speech vs silence
- **Silence Threshold** - Configurable (default: 1.5 seconds)
- **Natural Segmentation** - Segments audio at natural speech boundaries
- **Noise Filtering** - Prevents transcribing background noise
- **Robust** - More accurate than simple RMS-based detection

### Configuration

```swift
// In VADService.swift
let silenceThreshold: TimeInterval = 1.5  // Silence duration to end segment
```

## Model Configuration

### Available Models

The app supports multiple Whisper models with different trade-offs:

| Model | Size | Speed | Accuracy | Recommended For |
|-------|------|-------|----------|-----------------|
| tiny | ~75MB | Fastest | Basic | Testing, low-resource Macs |
| base | ~150MB | Very Fast | Decent | Quick transcription |
| small | ~500MB | Fast | Good | Balanced performance |
| medium | ~1.5GB | Moderate | High | Higher accuracy needs |
| large-v2 | ~3GB | Slower | Very High | Best accuracy (previous gen) |
| large-v3 | ~3GB | Slower | Best | **Default** - Latest, most accurate |

### Changing Models

```swift
// In TranscriptionService.swift
let modelPath = ModelDownloadService.shared.getModelPath(for: "large-v3")
let transcriptionService = TranscriptionService(modelPath: modelPath)
```

### Model Storage

Models are stored in:
```
~/Library/Application Support/EnglishSubtitles/models/
├── large-v3/
│   ├── model.bin
│   └── config.json
├── large-v2/
└── medium/
```

## Development

### Project Structure

```
EnglishSubtitlesMacOS/
├── Models/
│   └── Subtitle.swift                       # Subtitle data model
├── ViewModels/
│   └── SubtitlesViewModel.swift             # Main ViewModel
├── Views/
│   ├── ContentView.swift                    # Root view
│   ├── SubtitleFloatingWindow.swift         # Floating subtitle window
│   └── SubtitleView.swift                   # Subtitle display UI
├── Services/
│   ├── ScreenAudioCaptureService.swift      # ScreenCaptureKit integration
│   ├── TranscriptionService.swift           # SwiftWhisper integration
│   ├── VADService.swift                     # WebRTC VAD
│   └── ModelDownloadService.swift           # Model management
├── Utilities/
│   └── AudioBufferProcessor.swift           # Audio conversion utilities
└── EnglishSubtitlesMacOSApp.swift           # App entry point with menu bar
```

### Building

```bash
# Build for development
xcodebuild -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitlesMacOS build

# Run tests
xcodebuild test -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitlesMacOS -destination 'platform=macOS'
```

### Testing with Audio Files

```swift
// In TranscriptionService.swift
func testAudioFile(path: String) async throws {
    let audioData = try Data(contentsOf: URL(fileURLWithPath: path))
    let result = try await transcribe(audioData)
    print("Transcription: \(result.text)")
}
```

Place test audio files in:
```
~/Library/Application Support/EnglishSubtitles/test/
```

## Troubleshooting

### No Audio Captured

1. Check Screen Recording permission in System Settings
2. Restart the app after granting permission
3. Ensure audio is playing from the screen (not headphones)
4. Make sure you've selected "Show Subtitles" from the menu bar

### Floating Window Not Visible

1. Check that the floating window is not hidden behind fullscreen DRM content
2. Try repositioning the floating window by dragging it
3. Close and reopen via "Subtitles → Hide/Show Subtitles" menu
4. Check if window is visible in non-fullscreen mode first
5. Some DRM-protected apps (Netflix, Disney+, Apple TV+) may block overlays in fullscreen

### Menu Item Not Working

1. Ensure the app is running (check menu bar for "Subtitles" menu)
2. Try the keyboard shortcut: ⌘⇧S (Command+Shift+S)
3. Restart the app if menu is unresponsive

### Poor Transcription Quality

1. Try a larger model (e.g., large-v3 instead of medium)
2. Adjust VAD threshold in VADService.swift
3. Ensure audio is clear and not too quiet
4. Check that screen audio capture is working properly

### High Memory Usage

1. Use a smaller model (e.g., medium instead of large-v3)
2. Reduce audio buffer size in ScreenAudioCaptureService
3. Adjust VAD silence threshold to create shorter segments

## Privacy & Security

- **100% Local Processing** - No data sent to cloud services
- **No Telemetry** - No analytics or tracking
- **Screen Audio Only** - Does not access microphone
- **Open Source** - Code is fully auditable

## Performance

Tested on:
- **MacBook Pro M1** (16GB RAM) - Processes in real-time with large-v3
- **MacBook Air M2** (8GB RAM) - Processes in real-time with medium model
- **Intel Mac** (2019, 16GB RAM) - Processes with ~2-3 second delay using large-v3

## License

See LICENSE file for details.

## Author

Created by Amr Aboelela

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues, questions, or feature requests, please open an issue on GitHub.
