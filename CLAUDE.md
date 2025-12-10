# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EnglishSubtitles is an iOS application that displays English subtitles in real-time while watching foreign language content (e.g., Turkish drama) on iPhone. The app uses WhisperKit for on-device multilingual speech recognition and translation to English - completely free and private.

## Project Structure

This is a Swift/iOS project built with SwiftUI and follows the MVVM (Model-View-ViewModel) architecture pattern.

```
EnglishSubtitles/
├── Models/
│   └── Subtitle.swift                    # Subtitle data model with timestamp
├── ViewModels/
│   └── SubtitlesViewModel.swift          # Single ViewModel for the subtitle screen
├── Views/
│   ├── ContentView.swift                 # Root view wrapper
│   └── SubtitleView.swift                # Main subtitle display UI
├── Services/
│   └── SpeechRecognitionService.swift    # WhisperKit integration
└── EnglishSubtitlesApp.swift             # App entry point
```

## Architecture

### Single Screen Architecture
- **One ViewModel**: `SubtitlesViewModel` - manages the entire subtitle screen state
- **One Service**: `SpeechRecognitionService` - handles WhisperKit integration
- **One Model**: `Subtitle` - represents subtitle entries with timestamps

### WhisperKit Tasks

WhisperKit supports two tasks:
1. **`.transcribe`** - Converts speech to text in the original language
2. **`.translate`** - Converts speech directly to English

### Data Flow
1. App launches → `SubtitleView` appears with "Listening..." text
2. `SubtitleView.onAppear` automatically calls `SubtitlesViewModel.start()`
3. `SpeechRecognitionService.startTranscribing()` begins real-time audio capture with `.transcribe` task
4. `SpeechRecognitionService.startTranslating()` begins real-time audio capture with `.translate` task
5. Both tasks process the same audio stream from the device microphone
6. Transcribed text (original language) updates `SubtitlesViewModel.original`
7. Translated text (English) updates `SubtitlesViewModel.english`
8. UI displays English translation in fullscreen (60pt bold white text on black background)

### Implementation Details
- **Audio Capture**: Uses `AVAudioEngine` to capture microphone input in real-time
- **Audio Processing**: Converts `AVAudioPCMBuffer` to Float arrays for WhisperKit
- **Real-time Transcription**: Processes audio buffers as they arrive from the microphone
- **Permissions**: Requires microphone access (NSMicrophoneUsageDescription in Info.plist)
- **Auto-start**: App automatically begins listening when launched

## Development Setup

### Requirements
- Xcode 16.0+
- iOS 16.0+ deployment target
- Swift 5.9+

### Dependencies (Swift Package Manager)
- **WhisperKit** (main branch or 0.7.0+) - On-device speech recognition and translation
  - URL: `https://github.com/argmaxinc/WhisperKit.git`

No other dependencies needed - everything runs on-device!

## Common Commands

```bash
# Build the project
xcodebuild -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitles build

# Run tests
xcodebuild test -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitles -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Code Conventions

- Use `if let handler {` instead of `if let handler = handler {`
- Main actor annotation on ViewModels: `@MainActor`
- Services are plain classes (not ObservableObject)
- Views use SwiftUI and follow declarative patterns
- Fullscreen subtitle display

## Key Files

- `EnglishSubtitlesApp.swift:11` - App entry point
- `SubtitleView.swift:26` - Auto-starts listening with `.onAppear { vm.start() }`
- `SubtitlesViewModel.swift:19` - Starts both transcribe and translate tasks simultaneously
- `SpeechRecognitionService.swift:40` - Real-time transcription with audio capture
- `SpeechRecognitionService.swift:70` - Real-time translation to English with audio capture
- `SpeechRecognitionService.swift:97` - Audio buffer processing for transcription
- `SpeechRecognitionService.swift:118` - Audio buffer processing for translation
- `SpeechRecognitionService.swift:166` - AudioStreamManager for microphone input
- `SpeechRecognitionService.swift:170` - `processAudioFile()` method for testing with audio files
- `project.pbxproj` - Contains INFOPLIST_KEY_NSMicrophoneUsageDescription for microphone permissions

## Notes

- This is a single-screen app focused on real-time subtitle display
- WhisperKit transcribes audio in ANY language (multilingual support)
- WhisperKit translates directly to English (no intermediate translation service needed)
- Uses **base model** (~75MB) - optimized for iPhone performance
- 100% free - no API costs
- Everything runs on-device for privacy and offline support
- Fullscreen display for maximum readability
- Auto-starts listening when app launches
- Black background with huge white text for viewing while watching content

## Model Configuration

The app uses WhisperKit's `base` model by default in `SpeechRecognitionService.swift:30`:
```swift
whisperKit = try await WhisperKit(model: "base")
```

Available models:
- `tiny` (~40MB) - Fastest, use if base is too slow
- `base` (~75MB) - **Default** - Best for iPhone
- `small` (~244MB) - Higher accuracy
- `medium` (~769MB) - Not recommended for mobile

## Permissions

The app requires microphone access for real-time audio capture. This is configured in `project.pbxproj`:
```
INFOPLIST_KEY_NSMicrophoneUsageDescription = "EnglishSubtitles needs access to your microphone to transcribe and translate speech in real-time.";
```

This setting is added to both Debug and Release build configurations.
- do not run tests by youself
- replace if let inputNode = inputNode with if let inputNod