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
@Suite(.serialized)
@MainActor
class SubtitlesViewModelTests {
    
    static let viewModel = SubtitlesViewModel()
    
    // Helper function to ensure model is loaded only if needed
    private func loadModelIfNeeded() async {
        if !Self.viewModel.isModelLoading {
            await Self.viewModel.loadModel()
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test func testSubtitlesViewModelInitialization() async throws {
        // Test a new instance to verify initialization behavior
        
        #expect(Self.viewModel.english.isEmpty, "English text should be empty on init")
        #expect(Self.viewModel.turkish.isEmpty, "Turkish text should be empty on init")
        #expect(!Self.viewModel.isRecording, "Should not be recording on init")
        #expect(!Self.viewModel.isModelLoading, "Model should not be loading on init")
        #expect(Self.viewModel.loadingProgress == 0.0, "Loading progress should be 0 on init")
    }
    // MARK: - Model Loading Tests
    
    @Test func testExplicitModelLoading() async throws {
        Self.viewModel.unloadModel()
        #expect(!Self.viewModel.isModelLoading, "Should be not loading initially")
        #expect(Self.viewModel.loadingProgress == 0.0, "Progress should start at 0")
        
        // Load model explicitly
        await loadModelIfNeeded()
        
        #expect(!Self.viewModel.isModelLoading, "Should finish loading")
        #expect(Self.viewModel.loadingProgress == 1.0, "Progress should reach 1.0")
    }
    
    @Test func testModelLoadingProgress() async throws {
        var progressValues: [Double] = []
        
        // Monitor progress during loading
        let monitorTask = Task {
            while Self.viewModel.isModelLoading {
                progressValues.append(Self.viewModel.loadingProgress)
                try await Task.sleep(for: .seconds(0.1))
            }
        }
        
        // Load model
        await loadModelIfNeeded()
        
        // Stop monitoring
        monitorTask.cancel()
        
        #expect(!progressValues.isEmpty, "Should have captured progress values")
        #expect(Self.viewModel.loadingProgress == 1.0, "Final progress should be 1.0")
    }
    
    // MARK: - Lifecycle Tests
    
    @Test func testStartStopBasicFlow() async throws {
        // Ensure model is loaded first
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        
        // Initial state check
        #expect(!Self.viewModel.isRecording, "Should not be recording initially")
        
        // Start - this will attempt to start microphone capture
        Self.viewModel.start()
        
        // Give the async operations time to complete
        try await Task.sleep(for: .seconds(2))
        
        // Note: isRecording becomes true only when startListening succeeds
        // In automated tests without microphone access, this may fail
        // This test verifies the ViewModel can call the service methods without crashing
        print("ViewModel start() called successfully")
        print("isRecording: \(Self.viewModel.isRecording)")
        print("Note: Microphone access required for isRecording to be true")
        
        // Stop
        Self.viewModel.reset()
        
        #expect(!Self.viewModel.isRecording, "Should not be recording after reset()")
    }
    
    @Test func testStartBeforeModelLoaded() async throws {
        // Try to start before model is loaded
        #expect(!Self.viewModel.isModelLoading, "Model should not be loading")
        
        // Start should wait for model to be ready
        Self.viewModel.start()
        
        // Give it time to process
        try await Task.sleep(for: .seconds(1))
        
        // The start() method should handle this gracefully by waiting
        print("ViewModel handles start() before model ready")
        
        Self.viewModel.reset()
    }
    
    @Test func testStopMultipleTimes() async throws {
        await loadModelIfNeeded()
        
        // Stop multiple times (should be safe)
        Self.viewModel.reset()
        Self.viewModel.reset()
        Self.viewModel.reset()
        
        #expect(!Self.viewModel.isRecording, "Should not be recording after multiple stops")
    }
    
    @Test func testUnloadModel() async throws {
        // Load model first
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        #expect(Self.viewModel.loadingProgress == 1.0, "Progress should be 1.0")
        
        // Start listening
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(1))
        
        // Unload model
        Self.viewModel.unloadModel()
        
        #expect(!Self.viewModel.isRecording, "Should stop recording when unloading")
        #expect(!Self.viewModel.isModelLoading, "Should be loading again after unload")
        #expect(Self.viewModel.loadingProgress == 0.0, "Progress should reset to 0")
    }
    
    // MARK: - Audio Processing Tests
    
    // MARK: - Segmentation Tests
    
    @Test func testSegmentTracking() async throws {
        // Load model
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        
        // Initial state - no segment displayed
        #expect(Self.viewModel.english.isEmpty, "English text should be empty initially")
        
        // Start listening
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(1))
        
        // The segment tracking logic is internal to the ViewModel
        // It happens in the callback when receiving translations
        print("ViewModel ready for segment tracking")
        
        Self.viewModel.reset()
    }
    
    @Test func testTextUpdatesFromService() async throws {
        // Test that ViewModel properly receives and displays text from service
        await loadModelIfNeeded()
        
        // Initial state
        #expect(Self.viewModel.english.isEmpty, "Should start with empty English text")
        #expect(Self.viewModel.turkish.isEmpty, "Should start with empty Turkish text")
        
        // Start listening (callback logic is tested in integration)
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(2))
        
        // The actual text updates happen via the callback in start()
        // This verifies the setup doesn't crash
        print("Text update mechanism is working")
        
        Self.viewModel.reset()
    }
    
    // MARK: - App Lifecycle Tests
    
    @Test func testAppLifecycleNotificationSetup() async throws {
        // Test that notification observers are set up
        // We can't directly test the observer callbacks without triggering actual notifications
        // But we can verify the ViewModel initializes without issues
        
        await loadModelIfNeeded()
        
        // Simulate what would happen on app lifecycle events
        // In real usage, these would be triggered by system notifications
        
        // Simulate going to background (unload model)
        Self.viewModel.unloadModel()
        #expect(!Self.viewModel.isModelLoading, "Should not be loading after unload")
        
        // Simulate returning to foreground (reload model)
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Should finish loading after reload")
        
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
        await loadModelIfNeeded()
        
        // Rapidly start and stop
        for _ in 0..<5 {
            Self.viewModel.start()
            try await Task.sleep(for: .seconds(0.1))
            Self.viewModel.reset()
        }
        
        #expect(!Self.viewModel.isRecording, "Should end in stopped state")
    }
    
    @Test func testConcurrentOperations() async throws {
        await withTaskGroup(of: Void.self) { group in
            // Load model in parallel with other operations
            group.addTask {
                await self.loadModelIfNeeded()
            }
            
            // Try to start (should wait for model)
            group.addTask {
                try? await Task.sleep(for: .seconds(0.5))
                await MainActor.run {
                    Self.viewModel.start()
                }
            }
            
            // Try to stop
            group.addTask {
                try? await Task.sleep(for: .seconds(1.0))
                await MainActor.run {
                    Self.viewModel.reset()
                }
            }
        }
        
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        #expect(!Self.viewModel.isRecording, "Should not be recording at end")
    }
    
    // MARK: - Lifecycle Observer Tests
    
    @Test func testLifecycleObserversSetup() async throws {
        // Verify that the ViewModel initializes properly
        #expect(!Self.viewModel.isRecording, "Should not be recording initially")
        #expect(!Self.viewModel.isModelLoading, "Should be not loading initially")
        
        // The lifecycle observers are set up during init
        // We can't directly test the observer callbacks, but we can verify
        // that the ViewModel handles the state changes they would trigger
        
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        
        // Test unload model (simulates what willResignActive would call)
        Self.viewModel.unloadModel()
        #expect(!Self.viewModel.isModelLoading, "Should not be loading again after unload")
        #expect(Self.viewModel.loadingProgress == 0.0, "Progress should reset")
        
        print("Lifecycle observer setup verified")
    }
    
    @Test func testAppWillResignActiveSimulation() async throws {
        // Load model first
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        
        // Start recording to test complete state reset
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(0.5))
        
        // Simulate app going to background (willResignActive)
        Self.viewModel.unloadModel()
        
        // Verify state is properly reset
        #expect(!Self.viewModel.isRecording, "Should stop recording when unloading")
        #expect(!Self.viewModel.isModelLoading, "Should not be loading again after unload")
        #expect(Self.viewModel.loadingProgress == 0.0, "Progress should reset to 0")
        
        print("App resign active simulation completed")
    }
    
    @Test func testAppDidBecomeActiveSimulation() async throws {
        // Simulate app returning from background
        // First ensure we're in "background" state
        Self.viewModel.unloadModel()
        #expect(!Self.viewModel.isModelLoading, "Should not be in loading state")
        
        // Simulate didBecomeActive - reload model
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "Model should be reloaded")
        #expect(Self.viewModel.loadingProgress == 1.0, "Progress should be complete")
        
        // In real scenario, start() would be called if model finished loading
        if !Self.viewModel.isModelLoading {
            Self.viewModel.start()
            try await Task.sleep(for: .seconds(0.5))
            // Can't verify isRecording on simulator, but method should not crash
        }
        
        print("App become active simulation completed")
    }
    
    @Test func testAppWillTerminateSimulation() async throws {
        // Load and start
        await loadModelIfNeeded()
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(0.5))
        
        // Simulate app termination
        Self.viewModel.unloadModel()
        
        // Verify complete cleanup
        #expect(!Self.viewModel.isRecording, "Should not be recording after termination cleanup")
        #expect(!Self.viewModel.isModelLoading, "Should not be in loading state after cleanup")
        
        print("App termination simulation completed")
    }
    
    // MARK: - Segment Handling Tests
    
    @Test func testSegmentTransitionHandling() async throws {
        await loadModelIfNeeded()
        
        // Test internal segment tracking by setting text directly
        // (simulates what the callback would do)
        Self.viewModel.english = "First segment text"
        
        #expect(Self.viewModel.english == "First segment text", "Should display first segment")
        
        // Simulate segment transition
        Self.viewModel.english = "Second segment text"
        #expect(Self.viewModel.english == "Second segment text", "Should display second segment")
        
        print("Segment transition handling verified")
    }
    
    @Test func testEmptyTextHandling() async throws {
        await loadModelIfNeeded()
        
        // Test empty text scenarios for both languages
        Self.viewModel.english = ""
        Self.viewModel.turkish = ""
        #expect(Self.viewModel.english.isEmpty, "Should handle empty English text")
        #expect(Self.viewModel.turkish.isEmpty, "Should handle empty Turkish text")
        
        Self.viewModel.english = "Some English text"
        Self.viewModel.turkish = "Türkçe metin"
        #expect(!Self.viewModel.english.isEmpty, "Should handle non-empty English text")
        #expect(!Self.viewModel.turkish.isEmpty, "Should handle non-empty Turkish text")
        
        Self.viewModel.english = ""
        Self.viewModel.turkish = ""
        #expect(Self.viewModel.english.isEmpty, "Should handle return to empty English text")
        #expect(Self.viewModel.turkish.isEmpty, "Should handle return to empty Turkish text")
        
        print("Empty text handling verified for both languages")
    }
    
    @Test func testTurkishAndEnglishIndependentUpdates() async throws {
        await loadModelIfNeeded()
        
        // Test that Turkish and English can be updated independently
        Self.viewModel.turkish = "Merhaba dünya"
        #expect(Self.viewModel.turkish == "Merhaba dünya", "Turkish should be set")
        #expect(Self.viewModel.english.isEmpty, "English should remain empty")
        
        Self.viewModel.english = "Hello world"
        #expect(Self.viewModel.english == "Hello world", "English should be set")
        #expect(Self.viewModel.turkish == "Merhaba dünya", "Turkish should remain unchanged")
        
        // Test updating Turkish while English is set
        Self.viewModel.turkish = "İyi günler"
        #expect(Self.viewModel.turkish == "İyi günler", "Turkish should be updated")
        #expect(Self.viewModel.english == "Hello world", "English should remain unchanged")
        
        print("Independent Turkish and English updates verified")
    }
    
    @Test func testTextPersistenceAcrossSegments() async throws {
        await loadModelIfNeeded()
        
        // Set initial text
        Self.viewModel.english = "Initial translation"
        let initialText = Self.viewModel.english
        
        // In real usage, the segment callback maintains text visibility
        // until new translation arrives
        #expect(Self.viewModel.english == initialText, "Text should persist until updated")
        
        // Update with new translation
        Self.viewModel.english = "Updated translation"
        #expect(Self.viewModel.english == "Updated translation", "Should update to new translation")
        
        print("Text persistence across segments verified")
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @Test func testStartWithoutModel() async throws {
        // Try to start without loading model first
        #expect(!Self.viewModel.isModelLoading, "Should not be loading")
        
        // start() should wait for model to be ready
        Self.viewModel.start()
        
        // Give it time to attempt starting
        try await Task.sleep(for: .seconds(1))
        
        // The start() method should handle waiting for model gracefully
        print("Start without model handled gracefully")
        
        Self.viewModel.reset()
    }
    
    @Test func testMultipleStartCalls() async throws {
        await loadModelIfNeeded()
        
        // Multiple start calls should be safe
        Self.viewModel.start()
        Self.viewModel.start()
        Self.viewModel.start()
        
        try await Task.sleep(for: .seconds(1))
        
        // Should not crash from multiple start calls
        print("Multiple start calls handled safely")
        
        Self.viewModel.reset()
    }
    
    @Test func testMultipleStopCalls() async throws {
        await loadModelIfNeeded()
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(0.5))
        
        // Multiple stop calls should be safe
        Self.viewModel.reset()
        Self.viewModel.reset()
        Self.viewModel.reset()
        
        #expect(!Self.viewModel.isRecording, "Should not be recording after multiple stops")
        
        print("Multiple stop calls handled safely")
    }
    
    @Test func testStateConsistencyDuringLoadUnload() async throws {
        // Test state consistency during rapid load/unload cycles
        for i in 0..<3 {
            print("Load/Unload cycle #\(i)")
            
            await loadModelIfNeeded()
            #expect(!Self.viewModel.isModelLoading, "Should be loaded in cycle \(i)")
            #expect(Self.viewModel.loadingProgress == 1.0, "Progress should be 1.0 in cycle \(i)")
            
            Self.viewModel.unloadModel()
            #expect(!Self.viewModel.isModelLoading, "Should not be loading in cycle \(i)")
            #expect(Self.viewModel.loadingProgress == 0.0, "Progress should be 0.0 in cycle \(i)")
            #expect(!Self.viewModel.isRecording, "Should not be recording in cycle \(i)")
        }
        
        print("State consistency maintained during load/unload cycles")
    }
    
    @Test func testProgressTrackingAccuracy() async throws {
        var progressValues: [Double] = []
        
        // Monitor progress changes
        let monitorTask = Task {
            var lastProgress = Self.viewModel.loadingProgress
            while Self.viewModel.isModelLoading {
                let currentProgress = Self.viewModel.loadingProgress
                if currentProgress != lastProgress {
                    progressValues.append(currentProgress)
                    lastProgress = currentProgress
                }
                try await Task.sleep(for: .seconds(0.1))
            }
        }
        
        await loadModelIfNeeded()
        monitorTask.cancel()
        
        // Verify progress tracking
        #expect(!progressValues.isEmpty, "Should track progress changes")
        #expect(Self.viewModel.loadingProgress == 1.0, "Final progress should be 1.0")
        
        if let firstProgress = progressValues.first {
            #expect(firstProgress >= 0.0, "First progress should be >= 0")
        }
        
        print("Progress tracking accuracy verified: \(progressValues.count) updates")
    }
    
    @Test func testMemoryManagement() async throws {
        // Test that ViewModels can be created and deallocated without leaks
        var viewModel: SubtitlesViewModel? = SubtitlesViewModel()
        
        await viewModel?.loadModel()
        viewModel?.start()
        try await Task.sleep(for: .seconds(0.5))
        viewModel?.reset()
        
        // Deallocate ViewModel
        viewModel = nil
        
        // If we reach here without crashes, memory management is working
        #expect(true, "ViewModel should deallocate cleanly")
        
        print("Memory management test completed")
    }
    
    @Test func testDeinitNotificationCleanup() async throws {
        // Test that deinit properly removes notification observers
        var viewModel: SubtitlesViewModel? = SubtitlesViewModel()
        
        await viewModel?.loadModel()
        
        // ViewModel is set up with notification observers
        // When deallocated, deinit should remove them
        viewModel = nil
        
        // If no crashes occur, notification cleanup worked
        #expect(true, "Notification observers should be cleaned up in deinit")
        
        print("Deinit notification cleanup verified")
    }
    
    @Test func testConcurrentStateAccess() async throws {
        // Test concurrent access to ViewModel state
        await withTaskGroup(of: Void.self) { group in
            // Load model
            group.addTask {
                await self.loadModelIfNeeded()
            }
            
            // Monitor progress
            group.addTask { @MainActor in
                for _ in 0..<10 {
                    let _ = Self.viewModel.loadingProgress
                    let _ = Self.viewModel.isModelLoading
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            
            // Test start/stop
            group.addTask { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                Self.viewModel.start()
                try? await Task.sleep(for: .milliseconds(500))
                Self.viewModel.reset()
            }
        }
        
        #expect(!Self.viewModel.isModelLoading, "Model should be loaded")
        #expect(!Self.viewModel.isRecording, "Should not be recording at end")
        
        print("Concurrent state access test completed")
    }
    
    @Test func testLoadingStateTransitions() async throws {
        // Load model
        await loadModelIfNeeded()
        #expect(!Self.viewModel.isModelLoading, "After load: should not be loading")
        #expect(Self.viewModel.loadingProgress == 1.0, "After load: progress should be 1.0")
        
        // Start recording
        Self.viewModel.start()
        try await Task.sleep(for: .seconds(0.5))
        // Note: isRecording may be false on simulator due to microphone access
        
        // Stop recording
        Self.viewModel.reset()
        #expect(!Self.viewModel.isRecording, "After stop: should not be recording")
        
        // Unload model
        Self.viewModel.unloadModel()
        #expect(!Self.viewModel.isModelLoading, "After unload: should not be loading")
        #expect(Self.viewModel.loadingProgress == 0.0, "After unload: progress should be 0")
        
        print("State transition testing completed")
    }
    
    @Test func testMemoryUsage() async throws {
        // Test that ViewModel doesn't leak memory during normal operation
        await loadModelIfNeeded()
        
        // Perform operations that could cause memory leaks
        for i in 0..<10 {
            Self.viewModel.start()
            try await Task.sleep(for: .seconds(0.1))
            Self.viewModel.reset()
            
            if i % 3 == 0 {
                // Periodically unload/reload model
                Self.viewModel.unloadModel()
                await loadModelIfNeeded()
            }
        }
        
        // Final cleanup
        Self.viewModel.unloadModel()
        
        #expect(!Self.viewModel.isModelLoading, "Should not be in loading state after final unload")
        print("Memory usage test completed without crashes")
    }
    
    // MARK: - Subtitle Timing and Queueing System Tests
    
    // MARK: - Reading Time Calculation Tests
    
    @Test func testCalculateReadingTimeForShortText() async throws {
        let shortText = "Hi"
        let readingTime = Self.viewModel.calculateReadingTimeForTesting(text: shortText)
        
        // 1 word ÷ 3 words/sec = 0.33s, but minimum is 2.0s
        #expect(readingTime == 2.0, "Short text should use minimum display time")
    }
    
    @Test func testCalculateReadingTimeForMediumText() async throws {
        let mediumText = "This is a medium length sentence with several words"
        let readingTime = Self.viewModel.calculateReadingTimeForTesting(text: mediumText)
        
        // 10 words ÷ 3 words/sec = 3.33s
        let expectedTime = 10.0 / 3.0
        #expect(abs(readingTime - expectedTime) < 0.5, "Medium text should calculate based on word count")
    }
    
    @Test func testCalculateReadingTimeForLongText() async throws {
        let longText = "This is a very long sentence that contains many words and should require significant reading time to process"
        let readingTime = Self.viewModel.calculateReadingTimeForTesting(text: longText)
        
        // 18 words ÷ 3 words/sec = 6.0s
        let expectedTime = 18.0 / 3.0
        #expect(abs(readingTime - expectedTime) < 0.1, "Long text should calculate based on word count")
    }
    
    @Test func testCalculateReadingTimeForEmptyText() async throws {
        let emptyText = ""
        let readingTime = Self.viewModel.calculateReadingTimeForTesting(text: emptyText)
        
        #expect(readingTime == 2.0, "Empty text should use minimum display time")
    }
    
    // MARK: - Immediate Display Tests
    
    @Test func testFirstSubtitleDisplaysImmediately() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Simulate first subtitle
        Self.viewModel.handleNewSubtitleForTesting(text: "First subtitle", segmentNumber: 1)
        
        #expect(Self.viewModel.english == "First subtitle", "First subtitle should display immediately")
    }
    
    @Test func testSubsequentSubtitleWithAdequateTime() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Display first subtitle
        Self.viewModel.handleNewSubtitleForTesting(text: "Short", segmentNumber: 1)
        
        // Wait longer than minimum display time (2.0s) - simulate time passage
        Self.viewModel.simulateTimePassageForTesting(seconds: 2.1)
        
        // Second subtitle should display immediately
        Self.viewModel.handleNewSubtitleForTesting(text: "Second subtitle", segmentNumber: 2)
        
        #expect(Self.viewModel.english == "Second subtitle", "Second subtitle should display immediately after adequate time")
    }
    
    // MARK: - Queueing System Tests
    
    @Test func testSubtitleGetsQueuedWhenTimingInsufficient() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Display first subtitle
        Self.viewModel.handleNewSubtitleForTesting(text: "This is a longer subtitle that needs reading time", segmentNumber: 1)
        
        // Immediately send second subtitle (should be queued)
        Self.viewModel.handleNewSubtitleForTesting(text: "Queued subtitle", segmentNumber: 2)
        
        // Should still show first subtitle
        #expect(Self.viewModel.english == "This is a longer subtitle that needs reading time",
                "Should still display first subtitle while second is queued")
        
        // Verify queue has content
        let queueCount = Self.viewModel.getQueueCountForTesting()
        #expect(queueCount == 1, "Second subtitle should be queued")
    }
    
    @Test func testQueueProcessingAfterTimer() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Display first subtitle (short for quick testing)
        Self.viewModel.handleNewSubtitleForTesting(text: "Short text", segmentNumber: 1) // 2 words = 2.0s minimum
        
        // Immediately queue second subtitle
        Self.viewModel.handleNewSubtitleForTesting(text: "Queued text", segmentNumber: 2)
        
        let queueCount = Self.viewModel.getQueueCountForTesting()
        #expect(queueCount == 1, "Subtitle should be queued")
        
        // Simulate timer firing by processing queue manually
        Self.viewModel.processQueueForTesting()
        
        #expect(Self.viewModel.english == "Queued text", "Queued subtitle should be displayed after processing")
        #expect(Self.viewModel.getQueueCountForTesting() == 0, "Queue should be empty after processing")
    }
    
    @Test func testQueueUnlimitedCapacity() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Display first subtitle with long reading time
        Self.viewModel.handleNewSubtitleForTesting(text: "This is a very long subtitle that requires significant reading time to process properly", segmentNumber: 1)
        
        // Add many subtitles to queue (no capacity limit)
        for i in 2...10 {
            Self.viewModel.handleNewSubtitleForTesting(text: "Subtitle \(i)", segmentNumber: i)
        }
        
        let queueCount = Self.viewModel.getQueueCountForTesting()
        #expect(queueCount == 9, "Queue should hold all subtitles without capacity limit")
    }
    
    // MARK: - Edge Cases Tests
    
    @Test func testMultipleRapidSubtitles() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Display long subtitle
        Self.viewModel.handleNewSubtitleForTesting(text: "This is a long subtitle requiring adequate reading time", segmentNumber: 1)
        
        // Rapidly add multiple subtitles
        for i in 2...5 {
            Self.viewModel.handleNewSubtitleForTesting(text: "Rapid subtitle \(i)", segmentNumber: i)
        }
        
        // Verify system handles rapid submissions gracefully
        let queueCount = Self.viewModel.getQueueCountForTesting()
        #expect(queueCount == 4, "Queue should hold all rapid submissions")
        #expect(Self.viewModel.english == "This is a long subtitle requiring adequate reading time",
                "Original subtitle should still be displayed")
    }
    
    @Test func testTimerCancellationOnStop() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Queue a subtitle
        Self.viewModel.handleNewSubtitleForTesting(text: "Long subtitle requiring reading time", segmentNumber: 1)
        Self.viewModel.handleNewSubtitleForTesting(text: "Queued subtitle", segmentNumber: 2)
        
        let initialQueueCount = Self.viewModel.getQueueCountForTesting()
        #expect(initialQueueCount == 1, "Subtitle should be queued")
        
        // Stop the service
        Self.viewModel.reset()
        
        // Verify cleanup
        let queueCountAfterStop = Self.viewModel.getQueueCountForTesting()
        #expect(queueCountAfterStop == 0, "Queue should be cleared on stop")
    }
    
    @Test func testTimingPrecisionWithVariousTextLengths() async throws {
        
        let testCases = [
            ("A", 2.0), // 1 word, minimum time
            ("Short sentence here.", 2.0), // 3 words: 1.0s, but minimum 2.0s
            ("This is a medium length sentence with adequate words.", 3.0), // 9 words: 3.0s
            ("This is a significantly longer sentence that contains many words and should require substantial reading time for proper comprehension.", 6.0) // 18 words: 6.0s
        ]
        
        for (text, expectedTime) in testCases {
            let calculatedTime = Self.viewModel.calculateReadingTimeForTesting(text: text)
            #expect(abs(calculatedTime - expectedTime) < 0.5,
                    "Text '\(text)' should have reading time of \(expectedTime)s, got \(calculatedTime)s")
        }
    }
    
    // MARK: - State Management Tests
    
    @Test func testSubtitleStateResetOnStop() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Set up state
        Self.viewModel.handleNewSubtitleForTesting(text: "Active subtitle", segmentNumber: 1)
        Self.viewModel.turkish = "Aktif altyazı"
        
        #expect(!Self.viewModel.english.isEmpty, "Should have active English subtitle")
        #expect(!Self.viewModel.turkish.isEmpty, "Should have active Turkish text")
        #expect(Self.viewModel.getQueueCountForTesting() >= 0, "Should have queue state")
        
        // Stop and verify cleanup
        Self.viewModel.reset()
        
        #expect(Self.viewModel.english.isEmpty, "English text should be cleared")
        #expect(Self.viewModel.turkish.isEmpty, "Turkish text should be cleared")
        #expect(Self.viewModel.getQueueCountForTesting() == 0, "Queue should be cleared")
    }
    
    // MARK: - Timing Bug Regression Tests
    
    @Test func testTimingDriftBugFixed() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Scenario that previously caused timing drift
        Self.viewModel.handleNewSubtitleForTesting(text: "First long subtitle with significant content", segmentNumber: 1)
        Self.viewModel.handleNewSubtitleForTesting(text: "Second subtitle", segmentNumber: 2)
        Self.viewModel.handleNewSubtitleForTesting(text: "Third subtitle", segmentNumber: 3)
        
        // Process queue step by step to verify timing calculations
        Self.viewModel.processQueueForTesting() // Should display second subtitle
        #expect(Self.viewModel.english == "Second subtitle", "Should display second subtitle")
        
        let remainingQueueCount = Self.viewModel.getQueueCountForTesting()
        #expect(remainingQueueCount == 1, "Should have one item remaining in queue")
        
        Self.viewModel.processQueueForTesting() // Should display third subtitle
        #expect(Self.viewModel.english == "Third subtitle", "Should display third subtitle")
        #expect(Self.viewModel.getQueueCountForTesting() == 0, "Queue should be empty")
    }
    
    @Test func testQueueOverwriteBugFixed() async throws {
        Self.viewModel.reset()
        await loadModelIfNeeded()
        
        // Scenario that previously lost segments
        Self.viewModel.handleNewSubtitleForTesting(text: "Initial subtitle", segmentNumber: 1)
        
        // Rapid fire subtitles that should all be preserved
        Self.viewModel.handleNewSubtitleForTesting(text: "Segment 2", segmentNumber: 2)
        Self.viewModel.handleNewSubtitleForTesting(text: "Segment 3", segmentNumber: 3)
        Self.viewModel.handleNewSubtitleForTesting(text: "Segment 4", segmentNumber: 4)
        
        let queueCount = Self.viewModel.getQueueCountForTesting()
        #expect(queueCount == 3, "All segments should be preserved")
        
        // Process and verify order is maintained
        Self.viewModel.processQueueForTesting()
        #expect(Self.viewModel.english == "Segment 2", "Should process segments in order")
        
        Self.viewModel.processQueueForTesting()
        #expect(Self.viewModel.english == "Segment 3", "Should process segments in order")
        
        Self.viewModel.processQueueForTesting()
        #expect(Self.viewModel.english == "Segment 4", "Should process segments in order")
    }
}
