# EnglishSubtitles

Real-time English subtitle generation for iOS and macOS. Completely free, private, and runs on-device.

## Platforms

### iOS Version
An iOS application that displays English subtitles in real-time while watching foreign language content (e.g., Turkish drama) on iPhone. Uses **WhisperKit** to capture microphone audio for on-device speech recognition and translation.

### macOS Version
A macOS application that generates live English subtitles from **screen audio** (e.g., YouTube, VLC, some streaming apps). Uses **SwiftFasterWhisper** with ScreenCaptureKit to capture screen audio and transcribe locally. Displays subtitles in a **floating window** controlled via the macOS menu bar. Native experience similar to QuickTime.

## Features

### iOS Features
- Real-time speech-to-text from **microphone** using WhisperKit (works with any language)
- On-device translation to English using WhisperKit
- Fullscreen subtitle display for easy reading
- Base model (~75MB) optimized for iPhone performance
- Auto-starts listening when app launches

### macOS Features
- **Menu bar control** - "Subtitles → Show Subtitles" toggles subtitle window
- Real-time subtitle generation from **screen audio** using SwiftFasterWhisper
- **Adaptive speech detection** - SwiftFasterWhisper performs adaptive speech detection and silence filtering
- **Floating window** for subtitle display - always-on-top and click-through
- **Auto-start/stop** - Opening window starts transcription, closing stops it
- **Fullscreen support** - Works with most apps (YouTube, VLC)
- **DRM limitations** - May not work with DRM-protected content (Netflix, Disney+, Apple TV+)
- Whisper models (medium, large-v2) for high accuracy
- Persistent model storage in Application Support
- Works with **any application** (not just browsers)
- **Native macOS experience** - Similar to QuickTime's Picture-in-Picture
- **Keyboard shortcut** - ⌘⇧S to toggle subtitles

### Common Features (Both Platforms)
- Completely **FREE** - no API costs or subscriptions
- **Privacy-focused** - everything runs on-device, no data sent to servers
- Works **offline** (after initial model download)
- Supports any language with automatic English translation

## Requirements

### iOS
- iOS 16.0+
- Xcode 16.0+
- Swift 5.9+

### macOS
- macOS 13.0+ (Ventura or later)
- Xcode 16.0+
- Swift 5.9+

## Dependencies

### iOS
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition and translation

### macOS
- **SwiftFasterWhisper** - Local Whisper model inference using faster-whisper backend
  - URL: `https://github.com/amraboelela/SwiftFasterWhisper.git`
  - Includes adaptive speech detection and silence filtering

## How It Works

### iOS Version

WhisperKit supports two tasks:
1. **Transcription** (`.transcribe`) - Converts speech to text in the original language
2. **Translation** (`.translate`) - Converts speech directly to English

The app uses both tasks simultaneously to show:
- Original language text
- English translation

**Audio Flow:**
1. Captures microphone audio in real-time
2. Processes audio buffers through WhisperKit
3. Displays transcription and translation in fullscreen

### macOS Version

**Menu Bar Control:**
1. Select "Subtitles → Show Subtitles" from menu bar (or press **⌘⇧S**)
2. Floating subtitle window opens and appears on screen
3. ScreenCaptureKit captures screen audio (e.g., from YouTube, VLC, some streaming apps)
4. SwiftFasterWhisper processes audio with adaptive speech detection
5. SwiftFasterWhisper transcribes audio using local Whisper models (medium, large-v2)
6. Transcription updates ViewModel
7. Floating window displays subtitles
8. Close window (or select "Hide Subtitles") → Transcription stops automatically

**Adaptive Speech Detection:**
- SwiftFasterWhisper includes adaptive energy-based filtering for speech detection
- Automatically segments audio at natural speech boundaries
- Prevents transcribing silence or background noise

**Floating Window:**
- Always-on-top, click-through window
- Floats above all applications
- Works in fullscreen for most apps (YouTube, VLC)
- May not display in DRM-protected fullscreen (Netflix, Disney+, Apple TV+)
- Controlled via menu bar: "Subtitles → Show/Hide Subtitles"

## Project Structure

### iOS

```
EnglishSubtitles/
├── Models/
│   └── Subtitle.swift                    # Subtitle data model
├── ViewModels/
│   └── SubtitlesViewModel.swift          # Main ViewModel for subtitle screen
├── Views/
│   ├── ContentView.swift                 # Root view wrapper
│   └── SubtitleView.swift                # Main subtitle display UI
├── Services/
│   ├── SpeechRecognitionService.swift    # Main translation service with hallucination filtering
│   ├── WhisperKitManager.swift           # WhisperKit model loading and lifecycle management
│   └── AudioStreamManager.swift          # Real-time audio capture and processing
└── EnglishSubtitlesApp.swift             # App entry point
```

### macOS

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

## Core Services

### iOS Services

#### SpeechRecognitionService

The main service handling real-time speech translation with advanced filtering:

**Key Features:**
- **Natural Segments**: Processes audio until natural silence breaks (1.0s silence threshold)
- **WhisperKit Limit**: Only forces processing at 29 seconds (respects model's 30s limit)
- **Memory Optimized**: Uses async queue operations to prevent iOS memory kills
- **Smart Filtering**: Comprehensive hallucination detection and blocking

**Hallucination Filter:**
Automatically blocks common WhisperKit false positives:
- YouTube phrases: "Subscribe", "Thanks for watching", "See you in next video"
- Credits: "Translated by...", "Subtitle by..."
- Annotations: `(music)`, `[laughter]`, `*sounds*`, `-titles-`
- Repetitive patterns: "I'm sorry, I'm sorry", "-Come on. -Come on."

**Memory Management:**
- Non-blocking async queue operations with `withCheckedContinuation`
- Immediate buffer cleanup with `removeAll(keepingCapacity: false)`
- Detached WhisperKit processing tasks

#### WhisperKitManager

Handles model loading and lifecycle:
- Copies medium model from bundle to Documents directory
- Loading progress updates for UI
- Memory cleanup and cache clearing
- Background/foreground model management

#### AudioStreamManager

Real-time audio processing:
- AVAudioEngine integration for microphone capture
- 16kHz mono PCM resampling (WhisperKit requirement)
- RMS calculation for silence detection
- Float array conversion for WhisperKit

### macOS Services

#### ScreenAudioCaptureService

Captures audio from the screen using ScreenCaptureKit:
- Configures screen audio capture (16kHz mono)
- Streams audio from system display
- Converts audio buffers for VAD and transcription
- Handles screen recording permissions

#### TranscriptionService

SwiftFasterWhisper integration for local transcription:
- Loads Whisper models (medium, large-v2)
- Transcribes audio segments to text using faster-whisper backend
- **Adaptive speech detection** - Automatically detects speech vs silence using energy-based filtering
- Segments audio at natural speech boundaries
- Supports multiple languages
- Returns transcription results with timestamps
- Faster inference compared to traditional Whisper implementations

**Model Support:**
- ⚠️ **large-v3 is not supported** - SwiftFasterWhisper uses the 80-mel Whisper pipeline (v1–v2)
- Supported models: tiny, base, small, medium, large-v2

#### SubtitleFloatingWindow

Floating window for subtitle display controlled via menu bar:
- NSWindow-based floating window with click-through capability
- Floats above all applications (.floating window level)
- Works in fullscreen for most apps
- Semi-transparent background with white text
- Auto-positioning at bottom center of screen
- Controlled via "Subtitles → Show/Hide Subtitles" menu
- Opening window starts transcription, closing stops it

#### ModelDownloadService

Manages Whisper model downloads:
- Downloads large models on first launch (~3GB)
- Stores models in `~/Library/Application Support/EnglishSubtitles/models/`
- Provides download progress updates
- Manages multiple model versions (large-v2, large-v3, medium, etc.)

## Setup

### iOS Setup

1. Clone the repository
2. Open `EnglishSubtitles.xcodeproj` in Xcode
3. WhisperKit dependency should resolve automatically via Swift Package Manager
4. Build and run on your device

### macOS Setup

1. Clone the repository
2. Open `EnglishSubtitles.xcodeproj` in Xcode
3. Select the **EnglishSubtitlesMacOS** scheme
4. Dependencies (SwiftFasterWhisper) should resolve via Swift Package Manager
5. Build and run on your Mac
6. Grant **Screen Recording** permission when prompted
7. Use menu bar "Subtitles → Show Subtitles" (or **⌘⇧S**) to open floating window

## Usage

### iOS Usage

1. Launch the app on your iPhone
2. Tap "Start" to begin recording
3. Point your iPhone's microphone toward the audio source (TV, computer, etc.)
4. The app will:
   - Transcribe the audio in the original language (using `.transcribe` task)
   - Translate it to English (using `.translate` task)
   - Display both in real-time
5. Tap "Stop" to end the session

### macOS Usage

1. Launch the app on your Mac
2. Grant Screen Recording permission if prompted (first launch only)
3. Select **"Subtitles → Show Subtitles"** from the menu bar (or press **⌘⇧S**)
4. The floating subtitle window appears at the bottom of your screen
5. Transcription starts automatically
6. Play content with foreign language audio (YouTube, VLC, some streaming apps)
7. Subtitles appear in the floating window in real-time
8. To stop: Close the floating window or select **"Subtitles → Hide Subtitles"** from menu
9. The floating window works in fullscreen mode for most apps

**Menu Bar Controls:**
- **Show Subtitles** - Opens floating window and starts transcription
- **Hide Subtitles** - Closes floating window and stops transcription
- **Keyboard Shortcut** - ⌘⇧S (Command+Shift+S) toggles subtitles

**Floating Window Features:**
- Always-on-top and click-through
- Floats above all applications
- Works with YouTube, VLC, and most video players
- May not work with DRM-protected content (Netflix, Disney+, Apple TV+)
  - Audio capture may work but overlay rendering may fail
  - Sometimes both fail depending on macOS + DRM implementation

## Why On-Device Processing?

### WhisperKit (iOS)

- **100% Free** - No API costs, no subscriptions
- **Privacy** - Everything runs on-device, no data sent to servers
- **Offline** - Works without internet connection
- **Fast** - On-device processing means low latency
- **Accurate** - Based on OpenAI's Whisper model
- **iPhone-optimized** - Uses compact base model (~75MB) for real-time performance

### SwiftFasterWhisper (macOS)

- **100% Free** - No API costs, completely free
- **Privacy** - All processing happens locally on your Mac
- **Offline** - Works without internet (after model download)
- **High Accuracy** - Uses large Whisper models (large-v2, large-v3) for best results
- **Faster** - Faster inference using faster-whisper backend (CTranslate2)
- **macOS-optimized** - Takes advantage of Mac's processing power for larger models

## Model Sizes

### iOS Models (WhisperKit)

The app uses WhisperKit's **base model** (~75MB):
- Small enough for iPhone storage
- Fast enough for real-time subtitles
- Accurate enough for most languages

Available models:
- `tiny` (~40MB) - Fastest, lower accuracy
- `base` (~75MB) - **Default** - Best balance for iPhone
- `small` (~244MB) - Higher accuracy, slower
- `medium` (~769MB) - Very high accuracy, not recommended for mobile

### macOS Models (SwiftFasterWhisper)

The app uses **large-v2 model** (~3GB) by default:
- Highest accuracy for transcription
- Supports 99+ languages
- Optimized for Mac's processing power
- Faster inference using CTranslate2

Available models:
- `tiny` (~75MB) - Fastest, basic accuracy
- `base` (~150MB) - Fast, decent accuracy
- `small` (~500MB) - Good balance of speed and accuracy
- `medium` (~1.5GB) - High accuracy
- `large-v2` (~3GB) - **Default** - Best accuracy

⚠️ **large-v3 is not supported**
SwiftFasterWhisper uses the 80-mel Whisper pipeline (v1–v2). large-v3 requires 128 mel bands and cannot be used.

**Model Storage Location (macOS):**
`~/Library/Application Support/EnglishSubtitles/models/`

## License

See LICENSE file for details.

## Author

Created by Amr Aboelela
