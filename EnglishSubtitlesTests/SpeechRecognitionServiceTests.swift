//
//  SpeechRecognitionServiceTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for SpeechRecognitionService - WhisperKit integration and actor-based audio processing
struct SpeechRecognitionServiceTests {

    // MARK: - Initialization Tests

    @Test func testSpeechRecognitionServiceInitialization() async throws {
        let service = SpeechRecognitionService()

        // Test initial state
        #expect(!service.isReady, "Service should not be ready before model load")

        // Load model and wait for completion
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "SpeechRecognitionService should be ready after initialization")
    }

    @Test func testServiceReadyState() async throws {
        let service = SpeechRecognitionService()

        // Initially not ready
        #expect(!service.isReady, "Service should not be ready initially")

        // Load model
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "Service should be ready after model load")
        #expect(service.isReady, "isReady should return true after model load")

        // Unload model
        service.unloadModel()

        #expect(!service.isReady, "Service should not be ready after model unload")
    }

    // MARK: - Audio File Processing Tests

    @Test func testTranscriptionWithTurkishAudio() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

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
        let transcribedText = try await service.processAudioFile(at: audioURL, task: .transcribe)
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
        let service = SpeechRecognitionService()

        // Wait for model to load
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

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
        let translatedText = try await service.processAudioFile(at: audioURL, task: .translate)
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
        let service = SpeechRecognitionService()

        // Wait for model to load
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

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
        let transcribedText = try await service.processAudioFile(at: quranURL, task: .transcribe)
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
        let service = SpeechRecognitionService()

        // Wait for model to load
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

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
        let translatedText = try await service.processAudioFile(at: quranURL, task: .translate)
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
        let service = SpeechRecognitionService()
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Test that the service would filter hallucinations in processTranslation
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
        let service = SpeechRecognitionService()

        // Try to start listening without loading model first
        let success = await service.startListening { text, segment in
            // Should not be called
        }

        #expect(!success, "Should fail to start listening without loaded model")
    }

    @Test func testStartListeningWithModel() async throws {
        let service = SpeechRecognitionService()

        // Load model first
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        var receivedTranslations: [(text: String, segment: Int)] = []

        let success = await service.startListening { text, segment in
            receivedTranslations.append((text: text, segment: segment))
        }

        // On simulator, audio recording fails due to no microphone access
        // On real device, this should succeed
        #if targetEnvironment(simulator)
        #expect(!success, "Audio recording should fail on simulator (no microphone)")
        #else
        #expect(success, "Should successfully start listening with loaded model")
        #endif

        // Give it a moment to initialize
        try? await Task.sleep(for: .milliseconds(100))

        // Stop listening
        service.stopListening()

        // The callback setup should work (we can't easily test audio input without actual microphone)
        #expect(receivedTranslations.isEmpty, "No translations expected without real audio input")
    }

    @Test func testStopListening() async throws {
        let service = SpeechRecognitionService()

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        let success = await service.startListening { _, _ in }

        // On simulator, audio recording fails due to no microphone access
        #if targetEnvironment(simulator)
        #expect(!success, "Audio recording should fail on simulator (no microphone)")
        #else
        #expect(success, "Should start listening")
        #endif

        // Stop listening should be safe to call
        service.stopListening()
        service.stopListening() // Should be safe to call multiple times

        #expect(true, "stopListening should not crash")
    }

    // MARK: - Model Lifecycle Tests

    @Test func testModelLoadUnloadCycle() async throws {
        let service = SpeechRecognitionService()

        // Initially not ready
        #expect(!service.isReady, "Should not be ready initially")

        // Load model
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)
        #expect(isReady, "Should be ready after load")

        // Unload model
        service.unloadModel()
        #expect(!service.isReady, "Should not be ready after unload")

        // Load again
        await service.loadModel()
        let isReady2 = await TestHelpers.waitForWhisperKit(service)
        #expect(isReady2, "Should be ready after second load")
    }

    // MARK: - Error Handling Tests

    @Test func testProcessAudioFileWithInvalidURL() async throws {
        let service = SpeechRecognitionService()

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.wav")

        do {
            let _ = try await service.processAudioFile(at: invalidURL, task: .transcribe)
            Issue.record("Should have thrown error for invalid file")
        } catch {
            #expect(true, "Should throw error for invalid audio file")
        }
    }

    @Test func testProcessAudioFileWithoutModel() async throws {
        let service = SpeechRecognitionService()

        // Don't load model
        #expect(!service.isReady, "Should not be ready without model")

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        do {
            let _ = try await service.processAudioFile(at: audioURL, task: .transcribe)
            Issue.record("Should have thrown error without model")
        } catch {
            #expect(true, "Should throw error when processing without loaded model")
        }
    }

    // MARK: - Segmentation Tests

    @Test func testSegmentationWith001Audio() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load
        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

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
            let translation = try await service.processAudioFile(at: audioURL, task: .translate, language: "ar")

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

    @Test func testProgressCallback() async throws {
        var progressUpdates: [Double] = []

        let service = SpeechRecognitionService { progress in
            progressUpdates.append(progress)
        }

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "Service should be ready")
        #expect(!progressUpdates.isEmpty, "Should have received progress updates")
        #expect(progressUpdates.contains(1.0), "Should reach 100% progress")
    }
}
