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
1. User taps "Start" → `SubtitlesViewModel.start()`
2. `SpeechRecognitionService.startTranscribing()` begins listening with `.transcribe` task
3. `SpeechRecognitionService.startTranslating()` begins listening with `.translate` task
4. Both tasks run simultaneously on the same audio stream
5. Transcribed text (original language) updates `SubtitlesViewModel.original`
6. Translated text (English) updates `SubtitlesViewModel.english`
7. UI displays both original and English translation in fullscreen

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

- `EnglishSubtitlesApp.swift:11` - App entry point (no Firebase)
- `SubtitlesViewModel.swift:19` - Starts both transcribe and translate tasks
- `SpeechRecognitionService.swift:32` - `.transcribe` task implementation
- `SpeechRecognitionService.swift:49` - `.translate` task implementation
- `SubtitleView.swift:10` - Main UI entry point

## Notes

- This is a single-screen app focused on real-time subtitle display
- WhisperKit transcribes audio in ANY language (multilingual support)
- WhisperKit translates directly to English (no intermediate translation service needed)
- Uses **base model** (~75MB) - optimized for iPhone performance
- 100% free - no API costs
- Everything runs on-device for privacy and offline support
- Fullscreen display for maximum readability

## Model Configuration

The app uses WhisperKit's `base` model by default in `SpeechRecognitionService.swift:25`:
```swift
whisperKit = try await WhisperKit(variant: .base)
```

Available variants:
- `.tiny` (~40MB) - Fastest, use if base is too slow
- `.base` (~75MB) - **Default** - Best for iPhone
- `.small` (~244MB) - Higher accuracy
- `.medium` (~769MB) - Not recommended for mobile
