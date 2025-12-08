# EnglishSubtitles

An iOS application that displays English subtitles in real-time while watching foreign language content (e.g., Turkish drama) on iPhone. The app uses WhisperKit for on-device speech recognition and translation with a 7-day free trial, then requires a one-time purchase for unlimited access.

## Features

### Core Translation Features
- **Real-time speech-to-text** using WhisperKit (works with any language)
- **On-device translation to English** using WhisperKit
- **Dual mode support**: Transcription (original language) + Translation (English)
- **Privacy-focused** - everything runs on-device
- **Fullscreen subtitle display** for easy reading while watching content
- **Works offline** - no internet required after initial setup

### Business Model
- **7-day free trial** - Full access to all features
- **One-time purchase** - Unlimited translation access after trial expires
- **Never blocks the app** - Core features remain accessible
- **Transparent trial tracking** - Clear indication of remaining days

### UI/UX Features
- **Animated splash screen** with app branding
- **Auto-start listening** when app launches
- **Real-time progress indicators** during model loading
- **Elegant error handling** and user feedback
- **App lifecycle management** - handles background/foreground transitions

## Trial & Purchase System

### Free Trial (7 Days)
- ✅ Full translation access
- ✅ All languages supported
- ✅ Unlimited usage during trial
- ✅ No feature restrictions

### After Trial Expires
- ❌ Translation features disabled
- ✅ App remains functional for other uses
- 💰 One-time purchase required for continued translation access

### Purchase Benefits
- 🔓 **Unlimited translation access**
- 🌍 **All languages supported**
- 🚫 **No recurring subscriptions**
- 💾 **One-time payment**

## Requirements

- iOS 16.0+
- Xcode 16.0+
- Swift 5.9+
- ~100MB storage for WhisperKit model

## Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition and translation
- StoreKit - In-app purchase management

## How It Works

WhisperKit supports two tasks that the app uses strategically:

1. **Transcription** (`.transcribe`) - Converts speech to text in the original language
2. **Translation** (`.translate`) - Converts speech directly to English

**During Trial Period:**
- Both transcription and translation available
- Real-time switching between modes
- Full feature access

**After Trial:**
- Translation requires purchase
- Transcription may remain available (app-dependent)
- Graceful degradation of features

## Project Structure

```
EnglishSubtitles/
├── Models/
│   └── Subtitle.swift                           # Subtitle data model with timestamp
├── ViewModels/
│   └── SubtitlesViewModel.swift                 # Main ViewModel with lifecycle management
├── Views/
│   ├── SplashScreenView.swift                   # Animated splash screen
│   ├── ContentView.swift                        # Root view wrapper with trial logic
│   └── SubtitleView.swift                       # Main subtitle display UI
├── Services/
│   ├── SpeechRecognitionService.swift           # Main translation service with hallucination filtering
│   ├── WhisperKitManager.swift                  # WhisperKit model loading and lifecycle management
│   ├── AudioStreamManager.swift                 # Real-time audio capture and processing
│   └── TranslationPurchaseManager.swift         # Trial and purchase logic
├── Tests/
│   ├── TranslationPurchaseManagerTests.swift    # Trial logic and purchase flow tests
│   ├── WhisperKitManagerTests.swift             # Model management and audio processing tests
│   ├── SubtitlesViewModelTests.swift            # UI state and lifecycle tests
│   ├── EnglishSubtitlesAppTests.swift           # App initialization and integration tests
│   └── Mocks/                                   # Mock StoreKit classes for testing
│       ├── MockStoreKit.swift                   # Mock purchase and transaction classes
│       └── TestableTranslationPurchaseManager.swift  # Testable purchase manager
└── EnglishSubtitlesApp.swift                    # App entry point with trial initialization
```

## Core Services

### TranslationPurchaseManager

Manages the trial and purchase system:

**Trial Logic:**
- **7-day trial period** from first app launch
- **UserDefaults persistence** for trial tracking
- **Graceful expiration** with clear user feedback

**Purchase Integration:**
- **StoreKit integration** for one-time purchases
- **Transaction validation** and receipt verification
- **Restore purchases** functionality

**Feature Gates:**
- `canUseTranslation` - Checks trial status and purchase state
- `shouldShowTranslationUpgrade` - Determines when to show upgrade prompts
- `trialDaysRemaining` - Real-time trial countdown

### SpeechRecognitionService

The main service handling real-time speech translation with advanced filtering:

**Key Features:**
- **Natural Segments**: Processes audio until natural silence breaks (1.0s silence threshold)
- **WhisperKit Limit**: Only forces processing at 29 seconds (respects model's 30s limit)
- **Memory Optimized**: Uses async queue operations to prevent iOS memory kills
- **Smart Filtering**: Comprehensive hallucination detection and blocking
- **Purchase Integration**: Respects trial/purchase state for translation access

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

### WhisperKitManager

Handles model loading and lifecycle with enhanced progress tracking:

**Features:**
- **Progress callbacks** for UI feedback during model loading
- **Bundle to Documents** model copying for persistence
- **Concurrent-safe** file operations for tests
- **Background/foreground** model management
- **Memory cleanup** and cache clearing
- **Actor-based** thread-safe operations

**Model Management:**
- Copies medium model (~769MB) from bundle to Documents directory
- Validates all required model files before proceeding
- Handles concurrent test scenarios gracefully
- Provides real-time loading progress (0-100%)

### AudioStreamManager

Real-time audio processing with enhanced reliability:

**Features:**
- **AVAudioEngine integration** for microphone capture
- **16kHz mono PCM resampling** (WhisperKit requirement)
- **RMS calculation** for silence detection
- **Float array conversion** for WhisperKit
- **Buffer management** for optimal memory usage

## Testing Architecture

### Comprehensive Test Suite
- **48 essential tests** (reduced from 149 redundant tests)
- **65% code reduction** while maintaining full coverage
- **Mock StoreKit integration** for purchase flow testing
- **Real WhisperKit testing** with actual audio files

### Test Coverage Areas

**TranslationPurchaseManager (18 tests):**
- ✅ Trial logic and expiration
- ✅ Purchase flow simulation
- ✅ UserDefaults persistence
- ✅ Feature access control
- ✅ Integration with app lifecycle

**WhisperKitManager (30 tests):**
- ✅ Model loading and unloading
- ✅ Progress callback validation
- ✅ Audio processing with real files
- ✅ Concurrent access safety
- ✅ Memory management

**Mock StoreKit Testing:**
- ✅ Successful purchase flows
- ✅ Failed purchase scenarios
- ✅ User cancellation handling
- ✅ Transaction verification
- ✅ Restore purchases functionality

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/EnglishSubtitles.git
   cd EnglishSubtitles
   ```

2. **Open in Xcode**
   ```bash
   open EnglishSubtitles.xcodeproj
   ```

3. **Dependencies** - WhisperKit should resolve automatically via Swift Package Manager

4. **Build and run** on your device (Simulator won't have microphone access)

## Usage

### Initial Launch
1. **Splash screen** appears with app branding
2. **Model loading** begins automatically with progress indicator
3. **Trial starts** automatically on first launch

### Real-time Translation
1. **Auto-start listening** when app is ready
2. **Point microphone** toward audio source (TV, computer, etc.)
3. **Real-time processing**:
   - Transcribes audio in original language (using `.transcribe` task)
   - Translates to English (using `.translate` task) *[Trial/Purchase required]*
   - Displays subtitles in fullscreen format
4. **Natural segmentation** - processes at natural speech breaks
5. **Automatic filtering** - blocks hallucinations and false positives

### Trial Management
- **Trial tracking** - See remaining days in app
- **Graceful expiration** - Clear messaging when trial ends
- **Purchase flow** - One-time purchase for unlimited access
- **Restore purchases** - Reinstall or new device support

## Why This Approach?

### WhisperKit Benefits
- **100% Private** - No data sent to servers
- **Works Offline** - No internet required after setup
- **Fast Processing** - On-device means low latency
- **High Accuracy** - Based on OpenAI's Whisper model
- **iPhone-optimized** - Uses medium model for best balance

### Business Model Benefits
- **Try before buy** - 7 days to evaluate the app
- **One-time purchase** - No recurring subscriptions
- **Fair pricing** - Pay once, use forever
- **No feature removal** - Core app remains functional

### Technical Benefits
- **Comprehensive testing** - High-quality codebase with 48 essential tests
- **Mock testing** - Full StoreKit testing without real purchases
- **Memory optimized** - Handles background/foreground transitions
- **Professional UI** - Splash screen and progress indicators

## Model Configuration

The app uses WhisperKit's **medium model** (~769MB) for optimal accuracy:

**Available Models:**
- `tiny` (~40MB) - Fastest, lower accuracy
- `base` (~75MB) - Good balance, faster loading
- `small` (~244MB) - Better accuracy, moderate speed
- `medium` (~769MB) - **Default** - Best accuracy for mobile
- `large` (~1.5GB) - Highest accuracy, not recommended for mobile

**Model Selection Reasoning:**
- Medium model provides excellent translation accuracy
- Acceptable loading time (~30-60 seconds on first launch)
- Good balance between accuracy and device storage
- Optimized for real-time subtitle generation

## Performance Characteristics

### Model Loading
- **First launch**: 30-60 seconds (copies from bundle)
- **Subsequent launches**: 15-30 seconds (loads from Documents)
- **Background handling**: Unloads model to save memory
- **Foreground restore**: Reloads model automatically

### Real-time Processing
- **Latency**: 1-3 seconds for natural speech segments
- **Accuracy**: Very high for clear audio sources
- **Memory usage**: Optimized for continuous operation
- **Battery impact**: Moderate (on-device processing)

## Troubleshooting

### Common Issues

**Model fails to load:**
- Ensure 1GB+ free storage space
- Check network connection for initial download
- Restart app if loading stalls

**Poor translation accuracy:**
- Ensure clear audio source
- Minimize background noise
- Position microphone closer to audio source
- Check if source language is supported

**Trial not working:**
- Check device date/time settings
- Verify app has been launched (trial starts on first launch)
- Clear app data and reinstall if issues persist

**Purchase issues:**
- Verify App Store account is active
- Check payment method
- Use "Restore Purchases" if switching devices

## License

See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`xcodebuild test -project EnglishSubtitles.xcodeproj -scheme EnglishSubtitles -destination 'platform=iOS Simulator,name=iPhone 15'`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open Pull Request

## Author

Created by Amr Aboelela

---

**Note**: This app prioritizes user privacy and works entirely offline after initial setup. No audio data is transmitted to external servers, and all processing happens locally on your device.
