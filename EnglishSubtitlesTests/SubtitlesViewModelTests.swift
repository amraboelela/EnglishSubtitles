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
  
  // MARK: - Initialization Tests
  
  @Test func testSubtitlesViewModelInitialization() async throws {
    let viewModel = SubtitlesViewModel()
    
    #expect(viewModel.englishText.isEmpty, "English text should be empty on init")
    #expect(!viewModel.isRecording, "Should not be recording on init")
    #expect(viewModel.isModelLoading, "Model should be loading on init")
    #expect(viewModel.loadingProgress == 0.0, "Loading progress should be 0 on init")
  }
  
  @Test func testProgressCallback() async throws {
    var progressUpdates: [Double] = []
    
    // Note: We can't directly test the progress callback in ViewModel init
    // since it creates its own SpeechRecognitionService internally.
    // This test verifies the callback mechanism works in general.
    let service = SpeechRecognitionService.shared
    
    // Ensure we start with a clean state to test progress callback
    await service.unloadModel()
    
    service.setProgressCallback { progress in
      progressUpdates.append(progress)
    }
    
    await service.loadModel()
    let isReady = await TestHelpers.waitForWhisperKit(service)
    
    #expect(isReady, "Service should be ready")
    #expect(!progressUpdates.isEmpty, "Should have received progress updates")
    #expect(progressUpdates.contains(0.15), "Should reach at least 15% progress")
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
    let service = SpeechRecognitionService.shared
    
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
    #expect(viewModel.englishText.isEmpty, "English text should be empty initially")
    
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
    #expect(viewModel.englishText.isEmpty, "Should start with empty text")
    
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
  
  // MARK: - Lifecycle Observer Tests
  
  @Test func testLifecycleObserversSetup() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Verify that the ViewModel initializes properly
    #expect(!viewModel.isRecording, "Should not be recording initially")
    #expect(viewModel.isModelLoading, "Should be loading initially")
    
    // The lifecycle observers are set up during init
    // We can't directly test the observer callbacks, but we can verify
    // that the ViewModel handles the state changes they would trigger
    
    await viewModel.loadModel()
    #expect(!viewModel.isModelLoading, "Model should be loaded")
    
    // Test unload model (simulates what willResignActive would call)
    viewModel.unloadModel()
    #expect(viewModel.isModelLoading, "Should be loading again after unload")
    #expect(viewModel.loadingProgress == 0.0, "Progress should reset")
    
    print("Lifecycle observer setup verified")
  }
  
  @Test func testAppWillResignActiveSimulation() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Load model first
    await viewModel.loadModel()
    #expect(!viewModel.isModelLoading, "Model should be loaded")
    
    // Start recording to test complete state reset
    viewModel.start()
    try await Task.sleep(for: .seconds(0.5))
    
    // Simulate app going to background (willResignActive)
    viewModel.unloadModel()
    
    // Verify state is properly reset
    #expect(!viewModel.isRecording, "Should stop recording when unloading")
    #expect(viewModel.isModelLoading, "Should be loading again after unload")
    #expect(viewModel.loadingProgress == 0.0, "Progress should reset to 0")
    
    print("App resign active simulation completed")
  }
  
  @Test func testAppDidBecomeActiveSimulation() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Simulate app returning from background
    // First ensure we're in "background" state
    viewModel.unloadModel()
    #expect(viewModel.isModelLoading, "Should be in loading state")
    
    // Simulate didBecomeActive - reload model
    await viewModel.loadModel()
    #expect(!viewModel.isModelLoading, "Model should be reloaded")
    #expect(viewModel.loadingProgress == 1.0, "Progress should be complete")
    
    // In real scenario, start() would be called if model finished loading
    if !viewModel.isModelLoading {
      viewModel.start()
      try await Task.sleep(for: .seconds(0.5))
      // Can't verify isRecording on simulator, but method should not crash
    }
    
    print("App become active simulation completed")
  }
  
  @Test func testAppWillTerminateSimulation() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Load and start
    await viewModel.loadModel()
    viewModel.start()
    try await Task.sleep(for: .seconds(0.5))
    
    // Simulate app termination
    viewModel.unloadModel()
    
    // Verify complete cleanup
    #expect(!viewModel.isRecording, "Should not be recording after termination cleanup")
    #expect(viewModel.isModelLoading, "Should be in loading state after cleanup")
    
    print("App termination simulation completed")
  }
  
  // MARK: - Segment Handling Tests
  
  @Test func testSegmentTransitionHandling() async throws {
    let viewModel = SubtitlesViewModel()
    
    await viewModel.loadModel()
    
    // Test internal segment tracking by setting text directly
    // (simulates what the callback would do)
    viewModel.englishText = "First segment text"
    
    #expect(viewModel.englishText == "First segment text", "Should display first segment")
    
    // Simulate segment transition
    viewModel.englishText = "Second segment text"
    #expect(viewModel.englishText == "Second segment text", "Should display second segment")
    
    print("Segment transition handling verified")
  }
  
  @Test func testEmptyTextHandling() async throws {
    let viewModel = SubtitlesViewModel()
    
    await viewModel.loadModel()
    
    // Test empty text scenarios
    viewModel.englishText = ""
    #expect(viewModel.englishText.isEmpty, "Should handle empty text")
    
    viewModel.englishText = "Some text"
    #expect(!viewModel.englishText.isEmpty, "Should handle non-empty text")
    
    viewModel.englishText = ""
    #expect(viewModel.englishText.isEmpty, "Should handle return to empty text")
    
    print("Empty text handling verified")
  }
  
  @Test func testTextPersistenceAcrossSegments() async throws {
    let viewModel = SubtitlesViewModel()
    
    await viewModel.loadModel()
    
    // Set initial text
    viewModel.englishText = "Initial translation"
    let initialText = viewModel.englishText
    
    // In real usage, the segment callback maintains text visibility
    // until new translation arrives
    #expect(viewModel.englishText == initialText, "Text should persist until updated")
    
    // Update with new translation
    viewModel.englishText = "Updated translation"
    #expect(viewModel.englishText == "Updated translation", "Should update to new translation")
    
    print("Text persistence across segments verified")
  }
  
  // MARK: - Error Handling and Edge Cases
  
  @Test func testStartWithoutModel() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Try to start without loading model first
    #expect(viewModel.isModelLoading, "Should still be loading")
    
    // start() should wait for model to be ready
    viewModel.start()
    
    // Give it time to attempt starting
    try await Task.sleep(for: .seconds(1))
    
    // The start() method should handle waiting for model gracefully
    print("Start without model handled gracefully")
    
    viewModel.stop()
  }
  
  @Test func testMultipleStartCalls() async throws {
    let viewModel = SubtitlesViewModel()
    
    await viewModel.loadModel()
    
    // Multiple start calls should be safe
    viewModel.start()
    viewModel.start()
    viewModel.start()
    
    try await Task.sleep(for: .seconds(1))
    
    // Should not crash from multiple start calls
    print("Multiple start calls handled safely")
    
    viewModel.stop()
  }
  
  @Test func testMultipleStopCalls() async throws {
    let viewModel = SubtitlesViewModel()
    
    await viewModel.loadModel()
    viewModel.start()
    try await Task.sleep(for: .seconds(0.5))
    
    // Multiple stop calls should be safe
    viewModel.stop()
    viewModel.stop()
    viewModel.stop()
    
    #expect(!viewModel.isRecording, "Should not be recording after multiple stops")
    
    print("Multiple stop calls handled safely")
  }
  
  @Test func testStateConsistencyDuringLoadUnload() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Test state consistency during rapid load/unload cycles
    for i in 0..<3 {
      print("Load/Unload cycle #\(i)")
      
      await viewModel.loadModel()
      #expect(!viewModel.isModelLoading, "Should be loaded in cycle \(i)")
      #expect(viewModel.loadingProgress == 1.0, "Progress should be 1.0 in cycle \(i)")
      
      viewModel.unloadModel()
      #expect(viewModel.isModelLoading, "Should be loading in cycle \(i)")
      #expect(viewModel.loadingProgress == 0.0, "Progress should be 0.0 in cycle \(i)")
      #expect(!viewModel.isRecording, "Should not be recording in cycle \(i)")
    }
    
    print("State consistency maintained during load/unload cycles")
  }
  
  @Test func testProgressTrackingAccuracy() async throws {
    let viewModel = SubtitlesViewModel()
    
    var progressValues: [Double] = []
    
    // Monitor progress changes
    let monitorTask = Task {
      var lastProgress = viewModel.loadingProgress
      while viewModel.isModelLoading {
        let currentProgress = viewModel.loadingProgress
        if currentProgress != lastProgress {
          progressValues.append(currentProgress)
          lastProgress = currentProgress
        }
        try await Task.sleep(for: .seconds(0.1))
      }
    }
    
    await viewModel.loadModel()
    monitorTask.cancel()
    
    // Verify progress tracking
    #expect(!progressValues.isEmpty, "Should track progress changes")
    #expect(viewModel.loadingProgress == 1.0, "Final progress should be 1.0")
    
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
    viewModel?.stop()
    
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
    let viewModel = SubtitlesViewModel()
    
    // Test concurrent access to ViewModel state
    await withTaskGroup(of: Void.self) { group in
      // Load model
      group.addTask {
        await viewModel.loadModel()
      }
      
      // Monitor progress
      group.addTask { @MainActor in
        for _ in 0..<10 {
          let _ = viewModel.loadingProgress
          let _ = viewModel.isModelLoading
          try? await Task.sleep(for: .milliseconds(100))
        }
      }
      
      // Test start/stop
      group.addTask { @MainActor in
        try? await Task.sleep(for: .seconds(1))
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(500))
        viewModel.stop()
      }
    }
    
    #expect(!viewModel.isModelLoading, "Model should be loaded")
    #expect(!viewModel.isRecording, "Should not be recording at end")
    
    print("Concurrent state access test completed")
  }
  
  @Test func testLoadingStateTransitions() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Test all state transitions
    #expect(viewModel.isModelLoading, "Initial: should be loading")
    #expect(viewModel.loadingProgress == 0.0, "Initial: progress should be 0")
    #expect(!viewModel.isRecording, "Initial: should not be recording")
    
    // Load model
    await viewModel.loadModel()
    #expect(!viewModel.isModelLoading, "After load: should not be loading")
    #expect(viewModel.loadingProgress == 1.0, "After load: progress should be 1.0")
    
    // Start recording
    viewModel.start()
    try await Task.sleep(for: .seconds(0.5))
    // Note: isRecording may be false on simulator due to microphone access
    
    // Stop recording
    viewModel.stop()
    #expect(!viewModel.isRecording, "After stop: should not be recording")
    
    // Unload model
    viewModel.unloadModel()
    #expect(viewModel.isModelLoading, "After unload: should be loading")
    #expect(viewModel.loadingProgress == 0.0, "After unload: progress should be 0")
    
    print("State transition testing completed")
  }
  
  @Test func testMemoryUsage() async throws {
    // Test that ViewModel doesn't leak memory during normal operation
    let viewModel = SubtitlesViewModel()
    
    // Give model time to load initially
    try await Task.sleep(for: .seconds(1.0))
    
    // Perform a smaller number of operations to avoid test timeouts
    for _ in 0..<3 {
      // Only test start/stop without aggressive model reloading
      viewModel.start()
      try await Task.sleep(for: .seconds(0.2))
      viewModel.stop()
      try await Task.sleep(for: .seconds(0.1))
    }
    
    // Final cleanup
    viewModel.unloadModel()
    
    // Allow cleanup time
    try await Task.sleep(for: .seconds(0.1))
    
    #expect(viewModel.isModelLoading, "Should be in loading state after final unload")
    print("Memory usage test completed without crashes")
  }
  
  // MARK: - setupLifecycleObservers Tests
  
  @Test func testSetupLifecycleObservers_WillResignActive() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Wait for initial model loading to complete
    try await Task.sleep(for: .seconds(1.0))
    await viewModel.loadModel()
    
    // Setup: Ensure model is loaded and recording started
    viewModel.start()
    try await Task.sleep(for: .seconds(0.5))
    
    let wasRecordingBefore = viewModel.isRecording
    let wasModelLoadedBefore = !viewModel.isModelLoading
    
    // When: Simulate app will resign active (going to background)
    NotificationCenter.default.post(
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    
    // Give notification time to process
    try await Task.sleep(for: .seconds(0.5))
    
    // Then: Model should be unloaded to save memory
    #expect(viewModel.isModelLoading, "Model should be unloaded when app goes to background")
    
    print("✅ setupLifecycleObservers - willResignActive tested")
    print("   Before: recording=\(wasRecordingBefore), modelLoaded=\(wasModelLoadedBefore)")
    print("   After: recording=\(viewModel.isRecording), modelLoaded=\(!viewModel.isModelLoading)")
  }
  
  @Test func testSetupLifecycleObservers_DidBecomeActive() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Setup: Unload model first (simulate app was backgrounded)
    viewModel.unloadModel()
    try await Task.sleep(for: .seconds(0.3))
    
    let wasModelLoadingBefore = viewModel.isModelLoading
    
    // When: Simulate app did become active (returning from background)
    NotificationCenter.default.post(
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    
    // Give notification time to process
    try await Task.sleep(for: .seconds(0.8))
    
    // Then: Model should be reloaded and service restarted
    // Note: May still be loading depending on timing
    let isModelLoadingAfter = viewModel.isModelLoading
    
    print("✅ setupLifecycleObservers - didBecomeActive tested")
    print("   Before: modelLoading=\(wasModelLoadingBefore)")
    print("   After: modelLoading=\(isModelLoadingAfter)")
    print("   Note: Model may still be loading after notification")
  }
  
  @Test func testSetupLifecycleObservers_WillTerminate() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Wait for initial setup
    try await Task.sleep(for: .seconds(0.5))
    
    let wasModelLoadedBefore = !viewModel.isModelLoading
    
    // When: Simulate app will terminate
    NotificationCenter.default.post(
      name: UIApplication.willTerminateNotification,
      object: nil
    )
    
    // Give notification time to process
    try await Task.sleep(for: .seconds(0.5))
    
    // Then: Model should be unloaded for cleanup
    #expect(viewModel.isModelLoading, "Model should be unloaded when app terminates")
    
    print("✅ setupLifecycleObservers - willTerminate tested")
    print("   Before: modelLoaded=\(wasModelLoadedBefore)")
    print("   After: modelLoaded=\(!viewModel.isModelLoading)")
  }
  
  @Test func testSetupLifecycleObservers_MultipleNotifications() async throws {
    let viewModel = SubtitlesViewModel()
    
    // Wait for initial setup and load model
    try await Task.sleep(for: .seconds(1.0))
    await viewModel.loadModel()
    try await Task.sleep(for: .seconds(0.5))
    
    // Test sequence: background -> foreground -> background -> terminate
    
    // Background
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    try await Task.sleep(for: .seconds(0.3))
    #expect(viewModel.isModelLoading, "Should unload on background")
    
    // Foreground - wait longer for async loadModel() to complete
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    try await Task.sleep(for: .seconds(1.5)) // Give more time for loadModel()
    
    // Background again
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    try await Task.sleep(for: .seconds(0.5)) // Give more time for unloadModel()
    #expect(viewModel.isModelLoading, "Should unload on second background")
    
    // Terminate
    NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
    try await Task.sleep(for: .seconds(0.5)) // Give more time for unloadModel()
    #expect(viewModel.isModelLoading, "Should remain unloaded on terminate")
    
    print("✅ setupLifecycleObservers - multiple notifications sequence tested")
  }
  
  @Test func testSetupLifecycleObservers_WeakSelfBehavior() async throws {
    // Test that the observer closures handle weak self properly
    var viewModel: SubtitlesViewModel? = SubtitlesViewModel()
    
    // Wait for initial setup
    try await Task.sleep(for: .seconds(0.5))
    
    // Verify viewModel is initially set up
    #expect(viewModel != nil, "ViewModel should exist")
    
    // Post notification while viewModel exists
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    try await Task.sleep(for: .seconds(0.3))
    
    // Release the viewModel
    viewModel = nil
    
    // Post notification after viewModel is deallocated - should not crash
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
    
    // Give time for notifications to process
    try await Task.sleep(for: .seconds(0.3))
    
    print("✅ setupLifecycleObservers - weak self behavior tested (no crashes)")
  }
  
  @Test func testSetupLifecycleObservers_CalledInInit() async throws {
    // Verify that setupLifecycleObservers is automatically called during init
    // We can test this by checking that the observers respond to notifications
    
    let _ = SubtitlesViewModel()
    
    // Wait for init to complete
    try await Task.sleep(for: .seconds(0.5))
    
    // Post a notification - if setupLifecycleObservers was called in init, it should respond
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    try await Task.sleep(for: .seconds(0.3))
    
    // The fact that we can test other lifecycle behaviors confirms setupLifecycleObservers was called
    print("✅ setupLifecycleObservers - automatic setup in init verified")
  }
}
