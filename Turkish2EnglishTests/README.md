# Unit Tests

This directory contains unit tests for the EnglishSubtitles app using the new TurkishSpeechService and AppleTranslationService architecture.

## Test Architecture

The app now uses a two-step translation process:
1. **Turkish Speech Recognition** - Uses `SFSpeechRecognizer` to convert Turkish speech to text
2. **Turkish-to-English Translation** - Uses Apple's `Translation` framework to translate text to English

## Test Coverage

### 1. SubtitlesViewModelTests
- ✅ `testSubtitlesViewModelInitialization()` - Tests initial state (both turkish and english properties)
- ✅ `testExplicitModelLoading()` - Tests simplified model loading (no heavy WhisperKit anymore)
- ✅ `testStartStopBasicFlow()` - Tests start/stop with new TurkishSpeechService
- ✅ `testTurkishAndEnglishIndependentUpdates()` - Tests independent Turkish/English text updates
- ✅ Subtitle timing and queueing system tests
- ✅ App lifecycle management tests
- ✅ Memory management tests

### 2. TurkishSpeechServiceTests
- ✅ `testSpeechServiceInitialization()` - Tests service initialization
- ✅ `testRequestAuthorization()` - Tests speech recognition authorization
- ✅ `testStartListeningBasicFlow()` - Tests Turkish speech recognition with callbacks
- ✅ `testStopListening()` - Tests service cleanup
- ✅ `testStartStopCycle()` - Tests multiple start/stop cycles
- ✅ Callback parameter validation
- ✅ Error handling and edge cases
- ✅ Audio engine management
- ✅ Memory management tests

### 3. AppleTranslationServiceTests
- ✅ `testBasicTurkishToEnglishTranslation()` - Tests Turkish→English translation
- ✅ `testTranslationWithLongerText()` - Tests with sentences
- ✅ `testEmptyTextTranslation()` - Tests edge cases
- ✅ `testMultipleTranslationsInSequence()` - Tests sequential translations
- ✅ `testConcurrentTranslations()` - Tests concurrent translation calls
- ✅ `testSpecialCharacterTranslation()` - Tests Turkish characters (ğüşıöç)
- ✅ Performance and memory management tests

## Setup

### 1. Required iOS Version
The new architecture requires:
- **iOS 17.4+** for Apple's `Translation` framework
- **iOS 10.0+** for `SFSpeechRecognizer`

### 2. Permissions Required
The app requires the following permissions (already configured in `project.pbxproj`):
- `NSMicrophoneUsageDescription` - For microphone access
- `NSSpeechRecognitionUsageDescription` - For speech recognition

### 3. No External Dependencies
The new architecture uses only Apple's built-in frameworks:
- `Speech` framework (SFSpeechRecognizer)
- `Translation` framework (Apple's on-device translation)
- `AVFoundation` for audio processing

## Running Tests

### In Xcode:
```
Cmd + U
```

### Command Line:
```bash
xcodebuild test -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitles -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Expected Results

### ✅ Simulator Tests (No Microphone)
Most tests will pass on simulator as they test initialization, state management, and API calls:
```
✅ SubtitlesViewModelTests - ViewModel state management
✅ AppleTranslationServiceTests - Translation API calls
✅ TurkishSpeechServiceTests - Service initialization and API setup
```

### ⚠️ Device Tests (With Microphone)
On a real device with microphone access, you can test:
- Live Turkish speech recognition
- Real-time translation to English
- Full audio pipeline functionality

## Architecture Benefits

### Compared to Previous WhisperKit Implementation:

#### Advantages ✅
- **Faster startup** - No heavy model download (~75MB+ WhisperKit model)
- **Smaller app size** - No bundled ML models
- **Better accuracy** - Uses Apple's latest speech recognition and translation
- **Native iOS integration** - Uses system frameworks
- **Always up-to-date** - Apple updates translation models automatically
- **Privacy focused** - All processing happens on-device
- **Language support** - Apple Translation supports many language pairs

#### Trade-offs ⚠️
- **iOS version requirement** - Requires iOS 17.4+ for Translation framework
- **Language limitation** - Specialized for Turkish→English (vs WhisperKit's multi-language support)
- **Apple dependency** - Relies on Apple's framework availability

## Testing Notes

### Translation Framework Limitations
- Translation may not work in iOS Simulator for some language pairs
- Turkish→English translation requires language models to be downloaded automatically
- First translation attempt may trigger model download (handled automatically by iOS)

### Speech Recognition Testing
- `SFSpeechRecognizer` requires microphone permission
- Tests verify API setup and error handling without requiring actual audio input
- Full functionality testing requires running on physical device with microphone

### Memory and Performance
- New architecture uses significantly less memory (no heavy ML models)
- Startup time is much faster (no model loading wait)
- Real-time performance should be excellent on iOS 17.4+ devices

## Troubleshooting

### "Translation not available"
- Ensure device is iOS 17.4 or later
- Check that Turkish and English language packs are available
- Try running on physical device instead of simulator

### "Speech recognition denied"
- Grant microphone and speech recognition permissions in iOS Settings
- Ensure app has proper usage descriptions in Info.plist

### Tests timeout
- Speech recognition tests may timeout on simulator without microphone access
- This is expected behavior - tests verify API setup, not actual functionality

## Migration from WhisperKit

The following files were removed in the migration:
- `SpeechRecognitionServiceTests.swift` (old WhisperKit service)
- `WhisperKitManagerTests.swift` (old model management)
- WhisperKit package dependency
- Bundle audio test files (no longer needed for model testing)

New test files added:
- `TurkishSpeechServiceTests.swift` - Tests Turkish speech recognition
- `AppleTranslationServiceTests.swift` - Tests Apple's translation framework
- Updated `SubtitlesViewModelTests.swift` - Tests new dual-text architecture