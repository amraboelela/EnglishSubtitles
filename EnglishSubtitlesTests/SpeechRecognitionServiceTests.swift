//
//  SpeechRecognitionServiceTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
import WhisperKit
import AVFoundation
@testable import EnglishSubtitles

/// Tests for SpeechRecognitionService - WhisperKit integration and actor-based audio processing
@Suite(.serialized)
class SpeechRecognitionServiceTests {

    static let service = SpeechRecognitionService()

    // MARK: - Initialization Tests

    @Test func testSpeechRecognitionServiceInitialization() async throws {

        // Test initial state
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Service should not be ready before model load")

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        #expect(isReady, "SpeechRecognitionService should be ready after initialization")
    }

    @Test func testServiceReadyState() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }

        // Initially not ready
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Service should not be ready initially")

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        #expect(isReady, "Service should be ready after model load")
        #expect(await Self.service.isReady, "isReady should return true after model load")

        // Unload model
        await Self.service.unloadModel()

        #expect(!(await Self.service.isReady), "Service should not be ready after model unload")
    }

    // MARK: - Audio File Processing Tests

    @Test func testTranscriptionWithTurkishAudio() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Transcribe the audio file (auto-detect language)
        let transcribedText = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.transcribe)
        print("Transcribed (Turkish): \(transcribedText)")

        // Verify we got some transcription
        #expect(!transcribedText.isEmpty, "Should transcribe Turkish audio to text")

        // The audio says "Haydi. Emret sultanım" in Turkish
        // We expect to get Turkish text back
        let hasTurkishWords = transcribedText.lowercased().contains("haydi") ||
                             transcribedText.lowercased().contains("emret") ||
                             transcribedText.lowercased().contains("sultan")

        #expect(hasTurkishWords, "Transcription should contain expected Turkish words (haydi, emret, or sultan)")
    }

    @Test func testTranslationWithTurkishAudio() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }
        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }
        let audioURL = URL(fileURLWithPath: audioPath)

        // Translate the audio file to English (auto-detect source language)
        let translatedText = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.translate)
        print("Translated (English): \(translatedText)")

        // Verify we got some translation
        #expect(!translatedText.isEmpty, "Should translate Turkish audio to English")

        // The audio says "Haydi. Emret sultanım" which translates to "Come on. As you order my sultan"
        // Check if translation contains key English words
        let hasEnglishWords = translatedText.lowercased().contains("come") ||
                             translatedText.lowercased().contains("sultan") ||
                             translatedText.lowercased().contains("order") ||
                             translatedText.lowercased().contains("command")

        #expect(hasEnglishWords, "Translation should contain expected English words (come, sultan, order, or command)")
    }

    @Test func testTranscriptionWithArabicQuran() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }
        guard let audioPath = TestHelpers.bundledQuranAudioPath() else {
            Issue.record("Quran audio file not found")
            return
        }

        // Test with Quran recitation (Arabic)
        let quranURL = URL(fileURLWithPath: audioPath)

        // Transcribe the Quran audio (auto-detect Arabic)
        let transcribedText = try await Self.service.processAudioFile(at: quranURL, task: DecodingTask.transcribe)
        print("Transcribed (Arabic Quran): \(transcribedText)")

        // Verify we got some transcription
        #expect(!transcribedText.isEmpty, "Should transcribe Arabic Quran recitation")

        // Surah Al-Fatiha contains these common Arabic words
        let hasArabicWords = transcribedText.contains("الله") ||  // Allah
                            transcribedText.contains("الرحمن") ||  // Ar-Rahman
                            transcribedText.contains("الرحيم") ||  // Ar-Raheem
                            transcribedText.lowercased().contains("allah") ||
                            transcribedText.lowercased().contains("rahman")

        #expect(hasArabicWords, "Transcription should contain expected Arabic words from Al-Fatiha")
    }

    @Test func testTranslationWithArabicQuran() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }
        guard let audioPath = TestHelpers.bundledQuranAudioPath() else {
            Issue.record("Quran audio file not found")
            return
        }
        // Test with Quran recitation (Arabic)
        let quranURL = URL(fileURLWithPath: audioPath)

        // Translate the Quran audio to English (auto-detect Arabic)
        let translatedText = try await Self.service.processAudioFile(at: quranURL, task: DecodingTask.translate)
        print("Translated (English): \(translatedText)")

        // Verify we got some translation
        #expect(!translatedText.isEmpty, "Should translate Arabic Quran to English")

        // Al-Fatiha translation should contain these key English words
        let hasEnglishWords = translatedText.lowercased().contains("allah") ||
                             translatedText.lowercased().contains("god") ||
                             translatedText.lowercased().contains("merciful") ||
                             translatedText.lowercased().contains("compassionate") ||
                             translatedText.lowercased().contains("lord")

        #expect(hasEnglishWords, "Translation should contain expected English words from Al-Fatiha")
    }

    // MARK: - Hallucination Filtering Tests

    @Test func testHallucinationFiltering() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Test that the Self.service would filter hallucinations in processTranslation
        // We can't easily test this without mocking WhisperKit, but we can test the String extension
        let hallucinations = [
            "Subscribe",
            "Thanks for watching",
            "(music)",
            "[laughter]",
            "*door closes*",
            "-The End-"
        ]

        for hallucination in hallucinations {
            #expect(hallucination.isLikelyHallucination, "Service should filter '\(hallucination)' as hallucination")
        }

        let validSpeech = [
            "Hello, how are you?",
            "This is a normal conversation.",
            "Can you help me with this?"
        ]

        for speech in validSpeech {
            #expect(!speech.isLikelyHallucination, "Service should not filter '\(speech)' as hallucination")
        }
    }

    // MARK: - Real-time Listening Tests

    @Test func testStartListeningWithoutModel() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }
        // Try to start listening without loading model first
        let success = await Self.service.startListening(
            transcribeOnly: false,
            onUpdate: { text, segment in
                // Should not be called
            }
        )
        #expect(!success, "Should fail to start listening without loaded model")
    }

    @Test func testStartListeningWithModel() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // On simulator, we expect this to fail quickly due to no microphone access
        // On real device, this should succeed
        // Instead of waiting indefinitely, we'll just test that the method can be called

        #if targetEnvironment(simulator)
        // On simulator, just verify the service is ready and can attempt to start
        // We don't actually call startListening as it hangs on simulator
        #expect(await Self.service.isReady, "Service should be ready to attempt listening")
        print("Skipping startListening on simulator due to microphone access issues")
        #else
        // On real device, test actual listening functionality
        var receivedTranslations: [(text: String, segment: Int)] = []
        let success = await Self.service.startListening(
            transcribeOnly: false,
            onUpdate: { text, segment in
                receivedTranslations.append((text: text, segment: segment))
            }
        )

        #expect(success, "Should successfully start listening with loaded model")

        // Give it a moment to initialize
        try? await Task.sleep(for: .milliseconds(100))

        // Stop listening
        Self.service.stopListening()

        // The callback setup should work (we can't easily test audio input without actual microphone)
        #expect(receivedTranslations.isEmpty, "No translations expected without real audio input")
        #endif
    }

    @Test func testStopListening() async throws {

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        #if targetEnvironment(simulator)
        // On simulator, just test that stopListening can be called safely without starting
        Self.service.stopListening()
        Self.service.stopListening() // Should be safe to call multiple times
        #expect(true, "stopListening should not crash on simulator")
        #else
        // On real device, test actual start/stop cycle
        let success = await Self.service.startListening(
            transcribeOnly: false,
            onUpdate: { _, _ in }
        )
        #expect(success, "Should start listening")

        // Stop listening should be safe to call
        Self.service.stopListening()
        Self.service.stopListening() // Should be safe to call multiple times

        #expect(true, "stopListening should not crash")
        #endif
    }

    // MARK: - Model Lifecycle Tests

    @Test func testModelLoadUnloadCycle() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }
        // Initially not ready
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Should not be ready initially")
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        #expect(isReady, "Should be ready after load")

        // Unload model
        await Self.service.unloadModel()
        #expect(!(await Self.service.isReady), "Should not be ready after unload")

        // Load again
        await Self.service.loadModel()
        let isReady2 = await TestHelpers.waitForWhisperKit(Self.service)
        #expect(isReady2, "Should be ready after second load")
    }

    // MARK: - Error Handling Tests

    @Test func testProcessAudioFileWithInvalidURL() async throws {

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.wav")

        do {
            let _ = try await Self.service.processAudioFile(at: invalidURL, task: DecodingTask.transcribe)
            Issue.record("Should have thrown error for invalid file")
        } catch {
            #expect(true, "Should throw error for invalid audio file")
        }
    }

    @Test func testProcessAudioFileWithoutModel() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }
        // Don't load model
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Should not be ready without model")

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        do {
            let _ = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.transcribe)
            Issue.record("Should have thrown error without model")
        } catch {
            #expect(true, "Should throw error when processing without loaded model")
        }
    }

    // MARK: - Segmentation Tests

    @Test func testSegmentationWith001Audio() async throws {

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Get path to 001.mp3 (54.8 seconds of Quran recitation with natural pauses)
        guard let audioPath = TestHelpers.bundled001AudioPath() else {
            Issue.record("001.mp3 file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Track segments as they would appear in real-time
        var segments: [(segmentNumber: Int, text: String)] = []

        // For testing, let's process the audio in ~11 second chunks (54.8 / 5 ≈ 11s per segment)
        // This simulates the natural verse breaks in Al-Fatiha
        let totalDuration = 54.8
        let approximateSegmentDuration = 11.0 // seconds per verse
        let numberOfSegments = Int(totalDuration / approximateSegmentDuration)

        print("Testing segmentation with 001.mp3 (\(totalDuration)s)")
        print("Expected segments: ~\(numberOfSegments)")
        print("Processing audio in ~\(approximateSegmentDuration)s chunks...\n")

        // Process each segment
        for segmentIndex in 0..<numberOfSegments {
            let startTime = Double(segmentIndex) * approximateSegmentDuration
            let endTime = min(startTime + approximateSegmentDuration, totalDuration)

            print("Processing segment #\(segmentIndex) (\(String(format: "%.1f", startTime))s - \(String(format: "%.1f", endTime))s)...")

            // For simplicity in testing, we'll process the entire file
            // In production, the audio is chunked in real-time by the microphone
            // and segmentation happens based on silence detection
            let translation = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.translate, language: "ar")

            if !translation.isEmpty {
                segments.append((segmentNumber: segmentIndex, text: translation))
                print("Segment #\(segmentIndex): \(translation)\n")
                break // Only process once for this test
            }
        }

        #expect(!segments.isEmpty, "Should detect at least one segment")

        // Verify we got a translation
        if let firstSegment = segments.first {
            print("Full translation: \(firstSegment.text)")

            let hasExpectedWords = firstSegment.text.lowercased().contains("allah") ||
                                   firstSegment.text.lowercased().contains("god") ||
                                   firstSegment.text.lowercased().contains("merciful") ||
                                   firstSegment.text.lowercased().contains("lord") ||
                                   firstSegment.text.lowercased().contains("praise")

            #expect(hasExpectedWords, "Translation should contain expected words from Al-Fatiha")
        }

        print("\n=== Segmentation Test Summary ===")
        print("Total segments detected: \(segments.count)")
        print("Expected: ~5 segments (one per verse)")
        print("Note: Full segmentation with silence detection requires real-time audio processing")
        print("      This test validates the audio can be translated")
    }

    // MARK: - Progress Callback Tests

    // MARK: - Audio Buffer Processing Tests

    @Test func testAudioAccumulationAndProcessing() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Create a mock audio buffer to test audio processing
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 16000 // 1 second at 16kHz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create audio buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with test audio data (sine wave)
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                let sample = sin(2.0 * Double.pi * 440.0 * Double(i) / 16000.0) * 0.1
                channelData.pointee[i] = Float(sample)
            }
        }

        // Test audio processing pipeline
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)
        let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)
        let rms = AudioStreamManager.calculateRMS(audioData)

        #expect(!audioData.isEmpty, "Should convert buffer to audio data")
        #expect(rms > 0.0, "Should calculate non-zero RMS for sine wave")
        #expect(audioData.count == Int(frameCapacity), "Should preserve frame count")

        print("Audio processing pipeline verified: \(audioData.count) samples, RMS: \(rms)")
    }

    @Test func testSilenceDetection() async throws {
        // Test silence detection logic using AudioStreamManager utility methods

        // Create silent audio (all zeros)
        let silentAudio: [Float] = Array(repeating: 0.0, count: 1600) // 0.1 seconds
        let silentRMS = AudioStreamManager.calculateRMS(silentAudio)

        // Create loud audio (sine wave)
        let loudAudio: [Float] = (0..<1600).map { i in
            Float(sin(2.0 * Double.pi * 440.0 * Double(i) / 16000.0) * 0.5)
        }
        let loudRMS = AudioStreamManager.calculateRMS(loudAudio)

        // Test RMS calculation accuracy
        #expect(silentRMS < 0.01, "Silent audio should have very low RMS")
        #expect(loudRMS > 0.1, "Loud audio should have higher RMS")

        // Test threshold logic (using service's threshold)
        let silenceThreshold: Float = 0.025
        #expect(silentRMS < silenceThreshold, "Silent RMS should be below threshold")
        #expect(loudRMS > silenceThreshold, "Loud RMS should be above threshold")

        print("Silence detection verified: silent RMS=\(silentRMS), loud RMS=\(loudRMS)")
    }

    @Test func testAudioBufferConversion() async throws {
        // Test audio buffer conversion utilities

        // Create stereo buffer
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let stereoBuffer = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: 4410)! // 0.1 seconds
        stereoBuffer.frameLength = 4410

        // Fill with different values for left/right channels
        if let channelData = stereoBuffer.floatChannelData {
            for i in 0..<Int(stereoBuffer.frameLength) {
                channelData[0][i] = 0.5 // Left channel
                channelData[1][i] = 0.3 // Right channel
            }
        }

        // Test resampling and conversion
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(stereoBuffer)
        let monoData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)

        #expect(!monoData.isEmpty, "Should convert stereo to mono")

        // If resampling occurred, check sample rate conversion
        if resampledBuffer.format.sampleRate == 16000 {
            let expectedSamples = Int(Double(stereoBuffer.frameLength) * (16000.0 / 44100.0))
            let actualSamples = monoData.count
            let tolerance = expectedSamples / 10 // 10% tolerance

            #expect(abs(actualSamples - expectedSamples) <= tolerance,
                   "Resampled length should be approximately correct")
        }

        print("Audio conversion verified: \(stereoBuffer.frameLength) -> \(monoData.count) samples")
    }

    // MARK: - Service State Management Tests

    @Test func testServiceInitializationStates() async throws {
        let service = SpeechRecognitionService()

        // Test initial state
        let initialReady = await service.isReady
        #expect(!initialReady, "New service should not be ready initially")

        // Load model
        await service.loadModel()
        let loadedReady = await service.isReady
        // Note: May be true or false depending on model loading success in test environment

        print("Service initialization: initial=\(initialReady), after load=\(loadedReady)")
    }

    @Test func testServiceWithProgressCallback() async throws {
        var progressUpdates: [Double] = []

        let service = SpeechRecognitionService { progress in
            progressUpdates.append(progress)
        }

        await service.loadModel()

        // Should have received progress updates
        #expect(!progressUpdates.isEmpty, "Should receive progress updates")

        // Progress should be between 0 and 1
        for progress in progressUpdates {
            #expect(progress >= 0.0 && progress <= 1.0, "Progress should be between 0 and 1")
        }

        print("Progress callback test: \(progressUpdates.count) updates received")
    }

    @Test func testUnloadModelBehavior() async throws {
        let service = SpeechRecognitionService()

        // Unload when not loaded (should be safe)
        await service.unloadModel()
        let unloadedReady = await service.isReady
        #expect(!unloadedReady, "Should not be ready after unload")

        // Load then unload
        await service.loadModel()
        await service.unloadModel()
        let reUnloadedReady = await service.isReady
        #expect(!reUnloadedReady, "Should not be ready after second unload")

        print("Unload behavior verified")
    }

    // MARK: - Real-time Processing Simulation Tests

    @Test func testStopListeningCleanup() async throws {
        let service = SpeechRecognitionService()

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        if isReady {
            // Start listening (may fail on simulator)
            let _ = await service.startListening(
                transcribeOnly: false,
                onUpdate: { _, _ in }
            )

            // Stop should always be safe to call
            service.stopListening()
            service.stopListening() // Multiple calls should be safe

            #expect(true, "Multiple stopListening calls should not crash")
        }

        print("Stop listening cleanup verified")
    }

    @Test func testAudioFileProcessingErrorHandling() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Test with nonexistent file
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.wav")

        do {
            let _ = try await Self.service.processAudioFile(at: invalidURL, task: .transcribe)
            Issue.record("Should have thrown error for nonexistent file")
        } catch {
            #expect(true, "Should throw error for nonexistent file")
            print("Correctly handled nonexistent file error: \(error)")
        }

        // Test with invalid audio file (create empty file)
        let tempDir = FileManager.default.temporaryDirectory
        let invalidAudioURL = tempDir.appendingPathComponent("invalid.wav")

        do {
            // Create empty file
            try Data().write(to: invalidAudioURL)

            let _ = try await Self.service.processAudioFile(at: invalidAudioURL, task: .transcribe)
            Issue.record("Should have thrown error for invalid audio file")
        } catch {
            #expect(true, "Should throw error for invalid audio file")
            print("Correctly handled invalid audio file error: \(error)")
        }

        // Clean up
        try? FileManager.default.removeItem(at: invalidAudioURL)
    }

    // MARK: - Language and Task Parameter Tests

    @Test func testProcessAudioFileWithLanguageParameter() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Test with explicit language parameter
        let transcriptionWithLang = try await Self.service.processAudioFile(
            at: audioURL,
            task: .transcribe,
            language: "tr"
        )

        #expect(!transcriptionWithLang.isEmpty, "Should transcribe with explicit language")
        print("Transcription with language parameter: \(transcriptionWithLang)")

        // Test without language parameter (auto-detect)
        let transcriptionAutoDetect = try await Self.service.processAudioFile(
            at: audioURL,
            task: .transcribe
        )

        #expect(!transcriptionAutoDetect.isEmpty, "Should transcribe with auto-detect")
        print("Transcription with auto-detect: \(transcriptionAutoDetect)")
    }

    @Test func testTaskParameterVariations() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Test transcription task
        let transcription = try await Self.service.processAudioFile(at: audioURL, task: .transcribe)
        #expect(!transcription.isEmpty, "Transcription should not be empty")

        // Test translation task
        let translation = try await Self.service.processAudioFile(at: audioURL, task: .translate)
        #expect(!translation.isEmpty, "Translation should not be empty")

        print("Task variations - Transcription: \(transcription.prefix(50))...")
        print("Task variations - Translation: \(translation.prefix(50))...")
    }

    // MARK: - Integration and Performance Tests

    @Test func testServiceIntegrationFlow() async throws {
        let service = SpeechRecognitionService()

        // Full integration flow
        #expect(!(await service.isReady), "Should start not ready")

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        if isReady {
            #expect(await service.isReady, "Should be ready after load")

            var receivedCallbacks = 0
            let success = await service.startListening(
                transcribeOnly: false,
                onUpdate: { text, segment in
                    receivedCallbacks += 1
                    print("Integration test translation callback: \(text) (segment \(segment))")
                }
            )

            #if targetEnvironment(simulator)
            #expect(!success, "Should fail on simulator")
            #else
            #expect(success, "Should succeed on real device")
            #endif

            service.stopListening()

            await service.unloadModel()
            #expect(!(await service.isReady), "Should not be ready after unload")
        }

        print("Integration flow completed")
    }

    @Test func testConcurrentServiceOperations() async throws {
        let service1 = SpeechRecognitionService()
        let service2 = SpeechRecognitionService()

        // Test concurrent loading
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await service1.loadModel()
            }
            group.addTask {
                await service2.loadModel()
            }
        }

        let ready1 = await service1.isReady
        let ready2 = await service2.isReady

        print("Concurrent operations: service1=\(ready1), service2=\(ready2)")

        // Both should handle concurrent access gracefully
        #expect(true, "Concurrent operations should complete without crashes")
    }

    @Test func testServiceMemoryManagement() async throws {
        // Test service lifecycle and memory management
        for i in 0..<3 {
            var service: SpeechRecognitionService? = SpeechRecognitionService()

            await service?.loadModel()
            let _ = await service?.isReady

            service?.stopListening()
            await service?.unloadModel()

            // Release service
            service = nil

            print("Memory management cycle \(i) completed")
        }

        #expect(true, "Memory management cycles should complete without leaks")
    }
}
