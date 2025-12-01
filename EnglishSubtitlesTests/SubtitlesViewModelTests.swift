//
//  SubtitlesViewModelTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for SubtitlesViewModel - State management and UI integration
struct SubtitlesViewModelTests {

    // MARK: - Initialization Tests

    @MainActor
    @Test func testSubtitlesViewModelInitialization() async throws {
        let viewModel = SubtitlesViewModel()

        #expect(viewModel.original.isEmpty, "Original text should be empty on init")
        #expect(viewModel.english.isEmpty, "English text should be empty on init")
        #expect(!viewModel.isRecording, "Should not be recording on init")
        #expect(viewModel.isModelLoading, "Model should be loading on init")
    }

    // MARK: - Lifecycle Tests

    @MainActor
    @Test func testSubtitlesViewModelStartStop() async throws {
        let viewModel = SubtitlesViewModel()

        // Initial state check
        #expect(!viewModel.isRecording, "Should not be recording initially")

        // Wait for WhisperKit to initialize (up to 180 seconds for initial download)
        var waited = 0.0
        let maxWait = 180.0
        print("Waiting for WhisperKit initialization...")
        while viewModel.isModelLoading && waited < maxWait {
            try await Task.sleep(for: .seconds(1))
            waited += 1.0
            if Int(waited) % 10 == 0 {
                print("Waited \(Int(waited))s for WhisperKit...")
            }
        }

        #expect(!viewModel.isModelLoading, "Model should finish loading")

        // Start - this will attempt to start microphone capture
        viewModel.start()

        // Give the async operations time to complete
        try await Task.sleep(for: .seconds(2))

        // Note: isRecording becomes true only when BOTH startTranscribing AND startTranslating succeed
        // In automated tests without microphone access, this may fail
        // This test verifies the ViewModel can call the service methods without crashing
        print("ViewModel start() called successfully")
        print("isRecording: \(viewModel.isRecording)")
        print("Note: Microphone access required for isRecording to be true")

        // Stop
        viewModel.stop()

        #expect(!viewModel.isRecording, "Should not be recording after stop()")
    }

    // MARK: - Audio Processing Tests

    @MainActor
    @Test func testSubtitlesViewModelWithActualAudioFile() async throws {
        // This test uses the actual audio file instead of waiting for microphone input
        let service = SpeechRecognitionService()

        // Wait for WhisperKit to initialize
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

        // Process the actual audio file for both transcription and translation
        async let transcriptionTask = service.processAudioFile(at: audioURL, task: .transcribe)
        async let translationTask = service.processAudioFile(at: audioURL, task: .translate)

        let (originalText, englishText) = await (try transcriptionTask, try translationTask)

        // Verify we got actual results
        #expect(!originalText.isEmpty, "Should transcribe Turkish audio")
        #expect(!englishText.isEmpty, "Should translate to English")

        // Check for expected content
        let hasOriginalContent = originalText.lowercased().contains("haydi") ||
                                originalText.lowercased().contains("emret") ||
                                originalText.lowercased().contains("sultan")

        let hasEnglishContent = englishText.lowercased().contains("come") ||
                               englishText.lowercased().contains("sultan") ||
                               englishText.lowercased().contains("order") ||
                               englishText.lowercased().contains("command")

        #expect(hasOriginalContent, "Transcription should contain expected Turkish words (haydi, emret, or sultan)")
        #expect(hasEnglishContent, "Translation should contain expected English words (come, sultan, order, or command)")
    }
}
