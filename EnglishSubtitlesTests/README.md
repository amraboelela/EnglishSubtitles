# Unit Tests

This directory contains unit tests for the EnglishSubtitles app using a Turkish drama audio sample.

## Test Audio File

- **File**: `Resources/fateh-1.m4a` (137KB)
- **Language**: Turkish
- **Expected Translation**: "Come on. As you order my sultan"
- **Original Turkish**: "Haydi. Emret sultanım"

## Test Coverage

### 1. Audio File Tests
- ✅ `testAudioFileExists()` - Verifies test audio file is in bundle

### 2. SpeechRecognitionService Tests
- ✅ `testSpeechRecognitionServiceInitialization()` - Tests WhisperKit model loading
- ✅ `testTranscriptionWithTurkishAudio()` - Tests `.transcribe` task (Turkish → Turkish text)
- ✅ `testTranslationWithTurkishAudio()` - Tests `.translate` task (Turkish → English)

### 3. SubtitlesViewModel Tests
- ✅ `testSubtitlesViewModelInitialization()` - Tests initial state
- ✅ `testSubtitlesViewModelStartStop()` - Tests start/stop recording
- ✅ `testSubtitlesViewModelTranscriptionAndTranslation()` - Tests full workflow

### 4. Model Tests
- ✅ `testSubtitleModelCreation()` - Tests Subtitle model initialization
- ✅ `testSubtitleEquality()` - Tests Subtitle equality

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
✅ testAudioFileExists - Audio file found in bundle
✅ testSpeechRecognitionServiceInitialization - WhisperKit loaded
✅ testTranscriptionWithTurkishAudio - Turkish text transcribed
   Output: "Haydi. Emret sultanım" (or similar)
✅ testTranslationWithTurkishAudio - English translation verified
   Output: "Come on. As you order my sultan" (or similar)
✅ testSubtitlesViewModelInitialization - ViewModel initialized
✅ testSubtitlesViewModelStartStop - Start/stop works
✅ testSubtitlesViewModelTranscriptionAndTranslation - Full workflow works
✅ testSubtitleModelCreation - Model creation works
✅ testSubtitleEquality - Model equality works
```

## Notes

- **First run takes ~5 seconds**: WhisperKit downloads base model (~75MB) on first run
- **Model size**: Base model is optimized for iPhone - only 75MB
- **Transcription accuracy**: WhisperKit may not transcribe exactly "Haydi. Emret sultanım" but should be close
- **Translation accuracy**: We check for keywords ("come", "sultan", "order") rather than exact match
- **Real audio processing**: Some tests are placeholders because they require actual audio stream processing

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
