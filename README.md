# EnglishSubtitles

An iOS application that displays English subtitles in real-time while watching foreign language content (e.g., Turkish drama) on iPhone. The app uses WhisperKit for on-device speech recognition and translation - completely free and private.

## Features

- Real-time speech-to-text using WhisperKit (works with any language)
- On-device translation to English using WhisperKit
- Completely FREE - no API costs
- Privacy-focused - everything runs on-device
- Fullscreen subtitle display for easy reading
- Works offline

## Requirements

- iOS 16.0+
- Xcode 16.0+
- Swift 5.9+

## Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition and translation

## How It Works

WhisperKit supports two tasks:
1. **Transcription** (`.transcribe`) - Converts speech to text in the original language
2. **Translation** (`.translate`) - Converts speech directly to English

The app uses both tasks simultaneously to show:
- Original language text
- English translation

## Project Structure

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
│   └── SpeechRecognitionService.swift    # WhisperKit integration
└── EnglishSubtitlesApp.swift             # App entry point
```

## Setup

1. Clone the repository
2. Open `EnglishSubtitles.xcodeproj` in Xcode
3. WhisperKit dependency should resolve automatically via Swift Package Manager
4. Build and run on your device

## Usage

1. Launch the app on your iPhone
2. Tap "Start" to begin recording
3. Point your iPhone's microphone toward the audio source (TV, computer, etc.)
4. The app will:
   - Transcribe the audio in the original language (using `.transcribe` task)
   - Translate it to English (using `.translate` task)
   - Display both in real-time
5. Tap "Stop" to end the session

## Why WhisperKit?

- **100% Free** - No API costs, no subscriptions
- **Privacy** - Everything runs on-device, no data sent to servers
- **Offline** - Works without internet connection
- **Fast** - On-device processing means low latency
- **Accurate** - Based on OpenAI's Whisper model
- **iPhone-optimized** - Uses compact base model (~75MB) for real-time performance

## Model Size

The app uses WhisperKit's **base model** (~75MB):
- Small enough for iPhone storage
- Fast enough for real-time subtitles
- Accurate enough for most languages

Available models:
- `tiny` (~40MB) - Fastest, lower accuracy
- `base` (~75MB) - **Default** - Best balance for iPhone
- `small` (~244MB) - Higher accuracy, slower
- `medium` (~769MB) - Very high accuracy, not recommended for mobile

## License

See LICENSE file for details.

## Author

Created by Amr Aboelela
