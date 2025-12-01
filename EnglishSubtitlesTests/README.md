# Unit Tests

This directory contains unit tests for the EnglishSubtitles app using a Turkish drama audio sample.

## Test Audio File

- **File**: `Resources/fateh-1.m4a` (137KB)
- **Language**: Turkish
- **Expected Translation**: "Come on. As you order my sultan"
- **Original Turkish**: "Haydi. Emret sultanım"

## Test Coverage

### 1. Audio File Tests
- ✅ `testAudioFileExists()` - Verifies test audio file can be located

### 2. SpeechRecognitionService Tests (Real WhisperKit Processing)
- ✅ `testSpeechRecognitionServiceInitialization()` - Tests WhisperKit model loading (waits up to 60s)
- ✅ `testTranscriptionWithTurkishAudio()` - **Real transcription** using `processAudioFile()` with `.transcribe` task
  - Processes actual audio file `fateh-1.m4a`
  - Expects Turkish text output
  - Verifies transcription is not empty
- ✅ `testTranslationWithTurkishAudio()` - **Real translation** using `processAudioFile()` with `.translate` task
  - Processes actual audio file `fateh-1.m4a`
  - Expects English translation output
  - Verifies translation contains key English words

### 3. SubtitlesViewModel Tests (Microphone Integration)
- ✅ `testSubtitlesViewModelInitialization()` - Tests initial state
- ⚠️ `testSubtitlesViewModelStartStop()` - Tests start/stop with microphone capture (may fail without mic access)
- ⚠️ `testSubtitlesViewModelTranscriptionAndTranslation()` - Tests full workflow (requires live mic input)

### 4. Model Tests
- ✅ `testSubtitleModelCreation()` - Tests Subtitle model initialization
- ✅ `testSubtitleEquality()` - Tests Subtitle UUID uniqueness

## Setup

### 1. Add WhisperKit Package (REQUIRED)
Before running tests, you **must** add WhisperKit to the project:

1. Open Xcode
2. Select **EnglishSubtitles** project
3. Go to **Package Dependencies** tab
4. Click **+** button
5. Add: `https://github.com/argmaxinc/WhisperKit.git`
6. Choose version: main branch or "Up to Next Major: 0.7.0"
7. Wait for package to resolve

### 2. Add Test Audio to Xcode
The audio file has been copied to `EnglishSubtitlesTests/Resources/`, but you need to add it to Xcode:

1. In Xcode, right-click **EnglishSubtitlesTests** folder
2. Select **Add Files to "EnglishSubtitles"...**
3. Navigate to `EnglishSubtitlesTests/Resources/`
4. Select `fateh-1.m4a`
5. Make sure **"EnglishSubtitlesTests" target is checked**
6. Click **Add**

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

When tests run successfully, you should see:

```
✅ testAudioFileExists - Audio file found
✅ testSpeechRecognitionServiceInitialization - WhisperKit loaded (may take 60s on first run)
✅ testTranscriptionWithTurkishAudio - REAL transcription processed
   Output: Turkish text (e.g., "Haydi. Emret sultanım" or similar)
✅ testTranslationWithTurkishAudio - REAL translation to English
   Output: English text (e.g., "Come on. As you order my sultan" or similar)
✅ testSubtitlesViewModelInitialization - ViewModel initialized correctly
⚠️  testSubtitlesViewModelStartStop - May show isRecording=false (no mic in tests)
⚠️  testSubtitlesViewModelTranscriptionAndTranslation - Empty text (no mic input)
✅ testSubtitleModelCreation - Model creation works
✅ testSubtitleEquality - Model equality works
```

## Notes

### Real Audio Processing ✅
- **`testTranscriptionWithTurkishAudio`** and **`testTranslationWithTurkishAudio`** now perform REAL WhisperKit processing
- These tests use `SpeechRecognitionService.processAudioFile()` to process the actual audio file
- WhisperKit's `.transcribe` task transcribes in the original language (Turkish)
- WhisperKit's `.translate` task translates directly to English
- **First run takes up to 60 seconds** for WhisperKit to download the base model (~75MB)
- **Subsequent runs are faster** as the model is cached

### Microphone Tests ⚠️
- ViewModel tests attempt real-time microphone capture but won't have audio in automated tests
- These tests verify the interface works without crashing
- For full testing, run the app on a device or simulator and speak into the microphone

### Accuracy
- **Transcription**: WhisperKit may transcribe slight variations of "Haydi. Emret sultanım"
- **Translation**: We check for keywords ("come", "sultan", "order", "command") rather than exact match
- Results may vary slightly between runs due to model behavior

## Troubleshooting

### "No such module 'WhisperKit'"
- Solution: Add WhisperKit package dependency (see Setup #1 above)

### "Audio file not found"
- Solution: Add `fateh-1.m4a` to test target (see Setup #2 above)

### Tests timeout
- WhisperKit base model loading takes ~5 seconds
- First download of base model is only ~75MB (fast!)
- Increase timeout in test if needed

### Memory issues
- Base model uses minimal memory (~200MB)
- Should work fine on iPhone 12 and newer
- If issues persist, try `.tiny` variant (~40MB) in SpeechRecognitionService.swift
