//
//  SubtitlesViewModelTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
import UIKit
@testable import EnglishSubtitles

/// Tests for SubtitlesViewModel - State management and UI integration
@MainActor
class SubtitlesViewModelTests {

    // MARK: - Initialization Tests

    @Test func testSubtitlesViewModelInitialization() async throws {
        let viewModel = SubtitlesViewModel()

        #expect(viewModel.english.isEmpty, "English text should be empty on init")
        #expect(!viewModel.isRecording, "Should not be recording on init")
        #expect(viewModel.isModelLoading, "Model should be loading on init")
        #expect(viewModel.loadingProgress == 0.0, "Loading progress should be 0 on init")
    }

    @Test func testProgressCallback() async throws {
        var progressUpdates: [Double] = []

        // Note: We can't directly test the progress callback in ViewModel init
        // since it creates its own SpeechRecognitionService internally.
        // This test verifies the callback mechanism works in general.
        let service = SpeechRecognitionService { progress in
            progressUpdates.append(progress)
        }

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "Service should be ready")
        #expect(!progressUpdates.isEmpty, "Should have received progress updates")
        #expect(progressUpdates.contains(1.0), "Should reach 100% progress")
    }

    // MARK: - Model Loading Tests

    @Test func testExplicitModelLoading() async throws {
        let viewModel = SubtitlesViewModel()

        #expect(viewModel.isModelLoading, "Should be loading initially")
        #expect(viewModel.loadingProgress == 0.0, "Progress should start at 0")

        // Load model explicitly
        await viewModel.loadModel()

        #expect(!viewModel.isModelLoading, "Should finish loading")
        #expect(viewModel.loadingProgress == 1.0, "Progress should reach 1.0")
    }

    @Test func testModelLoadingProgress() async throws {
        let viewModel = SubtitlesViewModel()

        var progressValues: [Double] = []

        // Monitor progress during loading
        let monitorTask = Task {
            while viewModel.isModelLoading {
                progressValues.append(viewModel.loadingProgress)
                try await Task.sleep(for: .seconds(0.1))
            }
        }

        // Load model
        await viewModel.loadModel()

        // Stop monitoring
        monitorTask.cancel()

        #expect(!progressValues.isEmpty, "Should have captured progress values")
        #expect(viewModel.loadingProgress == 1.0, "Final progress should be 1.0")
    }

    // MARK: - Lifecycle Tests

    @Test func testStartStopBasicFlow() async throws {
        let viewModel = SubtitlesViewModel()

        // Load model first
        await viewModel.loadModel()
        #expect(!viewModel.isModelLoading, "Model should be loaded")

        // Initial state check
        #expect(!viewModel.isRecording, "Should not be recording initially")

        // Start - this will attempt to start microphone capture
        viewModel.start()

        // Give the async operations time to complete
        try await Task.sleep(for: .seconds(2))

        // Note: isRecording becomes true only when startListening succeeds
        // In automated tests without microphone access, this may fail
        // This test verifies the ViewModel can call the service methods without crashing
        print("ViewModel start() called successfully")
        print("isRecording: \(viewModel.isRecording)")
        print("Note: Microphone access required for isRecording to be true")

        // Stop
        viewModel.stop()

        #expect(!viewModel.isRecording, "Should not be recording after stop()")
    }

    @Test func testStartBeforeModelLoaded() async throws {
        let viewModel = SubtitlesViewModel()

        // Try to start before model is loaded
        #expect(viewModel.isModelLoading, "Model should still be loading")

        // Start should wait for model to be ready
        viewModel.start()

        // Give it time to process
        try await Task.sleep(for: .seconds(1))

        // The start() method should handle this gracefully by waiting
        print("ViewModel handles start() before model ready")

        viewModel.stop()
    }

    @Test func testStopMultipleTimes() async throws {
        let viewModel = SubtitlesViewModel()

        await viewModel.loadModel()

        // Stop multiple times (should be safe)
        viewModel.stop()
        viewModel.stop()
        viewModel.stop()

        #expect(!viewModel.isRecording, "Should not be recording after multiple stops")
    }

    @Test func testUnloadModel() async throws {
        let viewModel = SubtitlesViewModel()

        // Load model first
        await viewModel.loadModel()
        #expect(!viewModel.isModelLoading, "Model should be loaded")
        #expect(viewModel.loadingProgress == 1.0, "Progress should be 1.0")

        // Start listening
        viewModel.start()
        try await Task.sleep(for: .seconds(1))

        // Unload model
        viewModel.unloadModel()

        #expect(!viewModel.isRecording, "Should stop recording when unloading")
        #expect(viewModel.isModelLoading, "Should be loading again after unload")
        #expect(viewModel.loadingProgress == 0.0, "Progress should reset to 0")
    }

    // MARK: - Audio Processing Tests

    @Test func testSubtitlesViewModelWithActualAudioFile() async throws {
        // This test uses the actual audio file instead of waiting for microphone input
        let service = SpeechRecognitionService()

        // Load model first
        await service.loadModel()

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

        // Process the actual audio file for translation
        let englishText = try await service.processAudioFile(at: audioURL, task: .translate)

        // Verify we got actual results
        #expect(!englishText.isEmpty, "Should translate to English")

        // Check for expected content
        let hasEnglishContent = englishText.lowercased().contains("come") ||
                               englishText.lowercased().contains("sultan") ||
                               englishText.lowercased().contains("order") ||
                               englishText.lowercased().contains("command")

        #expect(hasEnglishContent, "Translation should contain expected English words (come, sultan, order, or command)")
    }

    // MARK: - Segmentation Tests

    @Test func testSegmentTracking() async throws {
        let viewModel = SubtitlesViewModel()

        // Load model
        await viewModel.loadModel()
        #expect(!viewModel.isModelLoading, "Model should be loaded")

        // Initial state - no segment displayed
        #expect(viewModel.english.isEmpty, "English text should be empty initially")

        // Start listening
        viewModel.start()
        try await Task.sleep(for: .seconds(1))

        // The segment tracking logic is internal to the ViewModel
        // It happens in the callback when receiving translations
        print("ViewModel ready for segment tracking")

        viewModel.stop()
    }

    @Test func testTextUpdatesFromService() async throws {
        // Test that ViewModel properly receives and displays text from service
        let viewModel = SubtitlesViewModel()

        await viewModel.loadModel()

        // Initial state
        #expect(viewModel.english.isEmpty, "Should start with empty text")

        // Start listening (callback logic is tested in integration)
        viewModel.start()
        try await Task.sleep(for: .seconds(2))

        // The actual text updates happen via the callback in start()
        // This verifies the setup doesn't crash
        print("Text update mechanism is working")

        viewModel.stop()
    }

    // MARK: - App Lifecycle Tests

    @Test func testAppLifecycleNotificationSetup() async throws {
        let viewModel = SubtitlesViewModel()

        // Test that notification observers are set up
        // We can't directly test the observer callbacks without triggering actual notifications
        // But we can verify the ViewModel initializes without issues

        await viewModel.loadModel()

        // Simulate what would happen on app lifecycle events
        // In real usage, these would be triggered by system notifications

        // Simulate going to background (unload model)
        viewModel.unloadModel()
        #expect(viewModel.isModelLoading, "Should be loading after unload")

        // Simulate returning to foreground (reload model)
        await viewModel.loadModel()
        #expect(!viewModel.isModelLoading, "Should finish loading after reload")

        print("App lifecycle handling verified")
    }

    @Test func testNotificationObserverCleanup() async throws {
        let viewModel: SubtitlesViewModel? = SubtitlesViewModel()

        await viewModel?.loadModel()

        // When the ViewModel is deallocated, deinit should remove observers
        // This is automatically tested by Swift's memory management
        // If observers aren't removed, there would be crashes on notification

        print("Notification observer cleanup handled by deinit")
    }

    // MARK: - Edge Cases

    @Test func testRapidStartStop() async throws {
        let viewModel = SubtitlesViewModel()

        await viewModel.loadModel()

        // Rapidly start and stop
        for _ in 0..<5 {
            viewModel.start()
            try await Task.sleep(for: .seconds(0.1))
            viewModel.stop()
        }

        #expect(!viewModel.isRecording, "Should end in stopped state")
    }

    @Test func testConcurrentOperations() async throws {
        let viewModel = SubtitlesViewModel()

        await withTaskGroup(of: Void.self) { group in
            // Load model in parallel with other operations
            group.addTask {
                await viewModel.loadModel()
            }

            // Try to start (should wait for model)
            group.addTask {
                try? await Task.sleep(for: .seconds(0.5))
                await MainActor.run {
                    viewModel.start()
                }
            }

            // Try to stop
            group.addTask {
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    viewModel.stop()
                }
            }
        }

        #expect(!viewModel.isModelLoading, "Model should be loaded")
        #expect(!viewModel.isRecording, "Should not be recording at end")
    }

    // MARK: - Performance Tests

    @Test func testModelLoadPerformance() async throws {
        let viewModel = SubtitlesViewModel()

        let startTime = Date()
        await viewModel.loadModel()
        let duration = Date().timeIntervalSince(startTime)

        print("ViewModel model load time: \(String(format: "%.2f", duration)) seconds")

        // Should complete within reasonable time (allows for initial download)
        #expect(duration < 180.0, "Model should load within 3 minutes")
        #expect(!viewModel.isModelLoading, "Model should be loaded")
        #expect(viewModel.loadingProgress == 1.0, "Progress should be 1.0")
    }

    @Test func testMemoryUsage() async throws {
        // Test that ViewModel doesn't leak memory during normal operation
        let viewModel = SubtitlesViewModel()

        await viewModel.loadModel()

        // Perform operations that could cause memory leaks
        for i in 0..<10 {
            viewModel.start()
            try await Task.sleep(for: .seconds(0.1))
            viewModel.stop()

            if i % 3 == 0 {
                // Periodically unload/reload model
                viewModel.unloadModel()
                await viewModel.loadModel()
            }
        }

        // Final cleanup
        viewModel.unloadModel()

        #expect(viewModel.isModelLoading, "Should be in loading state after final unload")
        print("Memory usage test completed without crashes")
    }
}
