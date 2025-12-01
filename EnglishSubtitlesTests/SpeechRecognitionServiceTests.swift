//
//  SpeechRecognitionServiceTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for SpeechRecognitionService - WhisperKit integration
struct SpeechRecognitionServiceTests {

    // MARK: - Initialization Tests

    @Test func testSpeechRecognitionServiceInitialization() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load (can take up to 60 seconds on first run)
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "SpeechRecognitionService should be ready after initialization")
    }

    // MARK: - Audio File Processing Tests

    @Test func testTranscriptionWithTurkishAudio() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load
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

    // MARK: - Segmentation Tests

    @Test func testSegmentationWith001Audio() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load
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
        var currentSegment = 0

        // We'll split the audio into chunks to simulate real-time processing
        // and detect natural pauses between verses

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
}
