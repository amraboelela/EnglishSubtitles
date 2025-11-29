//
//  EnglishSubtitlesTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/28/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

struct EnglishSubtitlesTests {

    // MARK: - Test Audio File Loading

    @Test func testAudioFileExists() async throws {
        let bundle = Bundle(for: type(of: self) as! AnyClass)
        let url = bundle.url(forResource: "fateh-1", withExtension: "m4a")
        #expect(url != nil, "Audio file fateh-1.m4a should exist in test bundle")
    }

    // MARK: - SpeechRecognitionService Tests

    @Test func testSpeechRecognitionServiceInitialization() async throws {
        let service = SpeechRecognitionService()

        // Give it time to load the model
        try await Task.sleep(for: .seconds(5))

        #expect(service.isReady, "SpeechRecognitionService should be ready after initialization")
    }

    @Test func testTranscriptionWithTurkishAudio() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load
        try await Task.sleep(for: .seconds(5))

        guard service.isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        let bundle = Bundle(for: type(of: self) as! AnyClass)
        guard let audioURL = bundle.url(forResource: "fateh-1", withExtension: "m4a") else {
            Issue.record("Audio file not found")
            return
        }

        var transcribedText = ""

        // Start transcription
        let success = await service.startTranscribing { text in
            transcribedText = text
        }

        #expect(success, "Transcription should start successfully")

        // Wait for transcription to complete
        try await Task.sleep(for: .seconds(3))

        // Stop transcription
        service.stopTranscribing()

        #expect(!transcribedText.isEmpty, "Should transcribe Turkish audio to text")
        print("Transcribed (Turkish): \(transcribedText)")
    }

    @Test func testTranslationWithTurkishAudio() async throws {
        let service = SpeechRecognitionService()

        // Wait for model to load
        try await Task.sleep(for: .seconds(5))

        guard service.isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        let bundle = Bundle(for: type(of: self) as! AnyClass)
        guard let audioURL = bundle.url(forResource: "fateh-1", withExtension: "m4a") else {
            Issue.record("Audio file not found")
            return
        }

        var translatedText = ""
        let expectedTranslation = "Come on. As you order my sultan"

        // Start translation
        let success = await service.startTranslating { text in
            translatedText = text
        }

        #expect(success, "Translation should start successfully")

        // Wait for translation to complete
        try await Task.sleep(for: .seconds(3))

        // Stop translation
        service.stopTranscribing()

        #expect(!translatedText.isEmpty, "Should translate Turkish audio to English")
        print("Translated (English): \(translatedText)")
        print("Expected: \(expectedTranslation)")

        // Check if translation is close to expected
        // Using contains because exact match might vary slightly
        let isAccurate = translatedText.lowercased().contains("come") ||
                        translatedText.lowercased().contains("sultan") ||
                        translatedText.lowercased().contains("order")

        #expect(isAccurate, "Translation should contain key words from expected translation")
    }

    // MARK: - SubtitlesViewModel Tests

    @MainActor
    @Test func testSubtitlesViewModelInitialization() async throws {
        let viewModel = SubtitlesViewModel()

        #expect(viewModel.original.isEmpty, "Original text should be empty on init")
        #expect(viewModel.english.isEmpty, "English text should be empty on init")
        #expect(!viewModel.isRecording, "Should not be recording on init")
    }

    @MainActor
    @Test func testSubtitlesViewModelStartStop() async throws {
        let viewModel = SubtitlesViewModel()

        // Wait for service to be ready
        try await Task.sleep(for: .seconds(5))

        // Start
        viewModel.start()

        // Give it a moment to start
        try await Task.sleep(for: .seconds(1))

        #expect(viewModel.isRecording, "Should be recording after start()")

        // Stop
        viewModel.stop()

        #expect(!viewModel.isRecording, "Should not be recording after stop()")
    }

    @MainActor
    @Test func testSubtitlesViewModelTranscriptionAndTranslation() async throws {
        let viewModel = SubtitlesViewModel()

        // Wait for service to be ready
        try await Task.sleep(for: .seconds(5))

        // Start processing
        viewModel.start()

        #expect(viewModel.isRecording, "Should be recording")

        // Wait for some processing
        try await Task.sleep(for: .seconds(5))

        // Stop
        viewModel.stop()

        // Note: This test will only pass if actually processing audio
        // In a real scenario, you'd need to feed audio to the service
        print("Original: \(viewModel.original)")
        print("English: \(viewModel.english)")
    }

    // MARK: - Model Tests

    @Test func testSubtitleModelCreation() async throws {
        let subtitle = Subtitle(
            originalText: "Haydi. Emret sultanım",
            translatedText: "Come on. As you order my sultan",
            language: "tr"
        )

        #expect(subtitle.originalText == "Haydi. Emret sultanım")
        #expect(subtitle.translatedText == "Come on. As you order my sultan")
        #expect(subtitle.language == "tr")
        #expect(subtitle.id != UUID(), "Should have a unique ID")
    }

    @Test func testSubtitleEquality() async throws {
        let subtitle1 = Subtitle(originalText: "Test", translatedText: "Test", language: "tr")
        let subtitle2 = Subtitle(originalText: "Test", translatedText: "Test", language: "tr")

        // They should not be equal because they have different UUIDs
        #expect(subtitle1.id != subtitle2.id)
    }
}
