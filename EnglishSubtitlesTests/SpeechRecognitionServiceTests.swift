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

        // Transcribe the audio file with Turkish language specified
        let transcribedText = try await service.processAudioFile(at: audioURL, task: .transcribe, language: "tr")

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

        // Translate the audio file to English (source: Turkish)
        let translatedText = try await service.processAudioFile(at: audioURL, task: .translate, language: "tr")

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
}
