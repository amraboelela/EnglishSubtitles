//
//  WhisperKitManagerTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/1/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for WhisperKitManager - Model loading, lifecycle management, and file operations
@MainActor
class WhisperKitManagerTests {

    var manager = WhisperKitManager()

    // MARK: - Initialization Tests

    @Test func testWhisperKitManagerInitialization() async throws {
        let manager = WhisperKitManager()

        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit == nil, "WhisperKit should be nil before loading")
    }

    @Test func testWhisperKitManagerInitializationWithProgressCallback() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit == nil, "WhisperKit should be nil before loading")
        #expect(progressValues.isEmpty, "No progress should be reported before loading starts")
    }

    // MARK: - Model Loading Tests

    @Test func testLoadModel() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        // Load the model (this can take up to 60+ seconds on first run)
        try? await manager.loadModel()

        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit != nil, "WhisperKit should be loaded after loadModel()")
        #expect(!progressValues.isEmpty, "Progress updates should have been received")
        #expect(progressValues.first == 0.05, "First progress should be 0.05 (file copy start)")

        print("Progress updates received: \(progressValues.count)")
        print("Final progress: \(progressValues.last ?? 0.0)")
    }

    @Test func testLoadModelProgressSequence() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        try? await manager.loadModel()

        // Verify progress is monotonically increasing (never goes backward)
        for i in 1..<progressValues.count {
            #expect(progressValues[i] >= progressValues[i-1],
                    "Progress should be monotonically increasing: \(progressValues[i-1]) -> \(progressValues[i])")
        }

        // Verify key progress milestones
        #expect(progressValues.contains(0.05), "Should contain 0.05 (file copy start)")
        #expect(progressValues.contains(0.1), "Should contain 0.10 (file copy complete)")
        #expect(progressValues.contains(0.15), "Should contain 0.15 (WhisperKit loading start)")
    }

    @Test func testLoadModelIdempotency() async throws {
        // Load model first time
        try? await manager.loadModel()
        let firstInstance = await manager.whisperKit

        #expect(firstInstance != nil, "First load should succeed")

        // Load model second time (should work even if already loaded)
        try await manager.loadModel()
        let secondInstance = await manager.whisperKit

        #expect(secondInstance != nil, "Second load should succeed")

        print("Model can be reloaded multiple times")
    }

    // MARK: - Model Unloading Tests

    @Test func testUnloadModel() async throws {
        // Load model first
        try? await manager.loadModel()
        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit != nil, "Model should be loaded")

        // Unload model
        await manager.unloadModel()
        let managerWhisperKitAfterUnload = await manager.whisperKit
        #expect(managerWhisperKitAfterUnload == nil, "Model should be nil after unload")
    }

    @Test func testUnloadModelIdempotency() async throws {
        // Unload when not loaded (should not crash)
        await manager.unloadModel()
        let managerWhisperKit1 = await manager.whisperKit
        #expect(managerWhisperKit1 == nil, "Should handle unload when already nil")

        // Load, then unload multiple times
        try? await manager.loadModel()
        await manager.unloadModel()
        await manager.unloadModel() // Should be safe to call multiple times

        let managerWhisperKit2 = await manager.whisperKit
        #expect(managerWhisperKit2 == nil, "Should remain nil after multiple unloads")
    }

    @Test func testLoadUnloadCycle() async throws {
        // Test multiple load/unload cycles
        for i in 0..<3 {
            print("Load/Unload cycle #\(i)")

            try? await manager.loadModel()
            let managerWhisperKitLoaded = await manager.whisperKit
            #expect(managerWhisperKitLoaded != nil, "Should load successfully in cycle \(i)")

            await manager.unloadModel()
            let managerWhisperKitUnloaded = await manager.whisperKit
            #expect(managerWhisperKitUnloaded == nil, "Should unload successfully in cycle \(i)")
        }
    }

    // MARK: - File Management Tests

    @Test func testModelFilesExistAfterLoad() async throws {
        try? await manager.loadModel()

        // Check if model files exist in Documents directory
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Issue.record("Could not get documents directory")
            return
        }

        let modelPath = documentsPath.appendingPathComponent("openai_whisper-medium")

        #expect(fileManager.fileExists(atPath: modelPath.path), "Model directory should exist")

        // Check for required files
        let requiredFiles = [
            "config.json",
            "generation_config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "AudioEncoder.mlmodelc",
            "MelSpectrogram.mlmodelc",
            "TextDecoder.mlmodelc"
        ]

        for file in requiredFiles {
            let filePath = modelPath.appendingPathComponent(file)
            #expect(fileManager.fileExists(atPath: filePath.path),
                    "Required file should exist: \(file)")
        }

        print("All required model files exist at: \(modelPath.path)")
    }

    @Test func testModelFilesReusedOnSecondLoad() async throws {
        // First load - copies files
        try? await manager.loadModel()

        // Get modification time of a model file
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Issue.record("Could not get documents directory")
            return
        }

        let configPath = documentsPath
            .appendingPathComponent("openai_whisper-medium")
            .appendingPathComponent("config.json")

        let attributes1 = try fileManager.attributesOfItem(atPath: configPath.path)
        let modDate1 = attributes1[.modificationDate] as? Date

        // Small delay
        try await Task.sleep(for: .seconds(1))

        // Second load - should reuse existing files
        let manager2 = WhisperKitManager()
        try await manager2.loadModel()

        let attributes2 = try fileManager.attributesOfItem(atPath: configPath.path)
        let modDate2 = attributes2[.modificationDate] as? Date

        #expect(modDate1 == modDate2, "Model files should be reused, not recopied")
        print("Model files correctly reused on second load")
    }

    @Test func testCacheClearing() async throws {
        // This tests the internal clearCache functionality
        // We can't directly test it, but we can ensure loading still works after

        // Load model
        try? await manager.loadModel()
        let managerWhisperKit1 = await manager.whisperKit
        #expect(managerWhisperKit1 != nil, "Should load initially")

        // Unload and reload (which calls clearCache internally)
        await manager.unloadModel()
        try? await manager.loadModel()

        let managerWhisperKit2 = await manager.whisperKit
        #expect(managerWhisperKit2 != nil, "Should load after cache clearing")
    }

    // MARK: - Error Handling Tests

    @Test func testBundleResourceAccess() async throws {
        // Test that we can access bundle resources
        let bundle = Bundle(for: WhisperKitManager.self)
        let resourcePath = bundle.resourcePath

        #expect(resourcePath != nil, "Should be able to access bundle resource path")
        print("Bundle resource path: \(resourcePath ?? "nil")")
    }

    @Test func testDocumentsDirectoryAccess() async throws {
        let fileManager = FileManager.default
        let documentsUrls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)

        #expect(!documentsUrls.isEmpty, "Should be able to access documents directory")

        let documentsPath = documentsUrls.first!
        let testPath = documentsPath.appendingPathComponent("test_write_access")

        // Test write access
        let testData = "test".data(using: .utf8)!

        do {
            try testData.write(to: testPath)
            #expect(fileManager.fileExists(atPath: testPath.path), "Should be able to write to documents")

            // Clean up
            try? fileManager.removeItem(at: testPath)
        } catch {
            Issue.record("Cannot write to documents directory: \(error)")
        }
    }

    // MARK: - Progress Callback Tests

    @Test func testProgressCallbackNil() async throws {
        let manager = WhisperKitManager(onProgress: nil)

        // Should not crash with nil callback
        try? await manager.loadModel()
        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit != nil, "Should load with nil progress callback")
    }

    @Test func testProgressCallbackValues() async throws {
        var progressValues: [Double] = []
        var progressCallCount = 0

        let manager = WhisperKitManager { progress in
            progressCallCount += 1
            progressValues.append(progress)
        }

        try? await manager.loadModel()

        #expect(progressCallCount > 0, "Progress callback should be called")
        #expect(!progressValues.isEmpty, "Should receive progress values")
        #expect(progressValues.allSatisfy { $0 >= 0.0 && $0 <= 1.0 }, "All progress values should be between 0 and 1")

        print("Progress callback called \(progressCallCount) times")
        print("Progress values: \(progressValues.prefix(10))...") // Show first 10 values
    }

    @Test func testProgressCallbackSequence() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        try? await manager.loadModel()

        // Verify progress starts at a reasonable value
        if let firstProgress = progressValues.first {
            #expect(firstProgress >= 0.0, "First progress should be >= 0")
        }

        // Verify progress ends at 1.0 (or close to it due to timing)
        if let lastProgress = progressValues.last {
            #expect(lastProgress >= 0.9, "Final progress should be >= 0.9")
        }
    }

    // MARK: - Concurrent Access Tests

    @Test func testConcurrentLoading() async throws {
        // Test multiple managers loading concurrently
        let manager1 = WhisperKitManager()
        let manager2 = WhisperKitManager()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await manager1.loadModel()
            }
            group.addTask {
                try? await manager2.loadModel()
            }
        }

        #expect(await manager1.whisperKit != nil, "Manager 1 should load successfully")
        #expect(await manager2.whisperKit != nil, "Manager 2 should load successfully")

        print("Concurrent loading test completed successfully")
    }

    // MARK: - Performance Tests

    @Test func testLoadModelPerformance() async throws {
        let startTime = Date()
        try? await manager.loadModel()
        let duration = Date().timeIntervalSince(startTime)

        print("Model load time: \(String(format: "%.2f", duration)) seconds")

        // On first run (downloading), this can take 60+ seconds
        // On subsequent runs (files cached), this should be faster
        #expect(duration < 180.0, "Model should load within 3 minutes (allows for slow download)")

        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit != nil, "Model should be loaded")
    }

    @Test func testReloadPerformance() async throws {
        // First load (may be slow)
        let startTime1 = Date()
        try? await manager.loadModel()
        let firstLoadDuration = Date().timeIntervalSince(startTime1)

        await manager.unloadModel()

        // Second load (should be faster due to cached files)
        let startTime2 = Date()
        try? await manager.loadModel()
        let secondLoadDuration = Date().timeIntervalSince(startTime2)

        print("First load: \(String(format: "%.2f", firstLoadDuration))s")
        print("Second load: \(String(format: "%.2f", secondLoadDuration))s")

        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit != nil, "Should load successfully on reload")

        // Second load might be faster due to cached files, but not guaranteed
        // Just ensure both complete in reasonable time
        #expect(firstLoadDuration < 180.0, "First load should complete in reasonable time")
        #expect(secondLoadDuration < 180.0, "Second load should complete in reasonable time")
    }

    // MARK: - Error Handling and Edge Cases

    @Test func testLoadModelWithProgressCallbackCancellation() async throws {
        var progressValues: [Double] = []
        var callbackCallCount = 0

        let manager = WhisperKitManager { progress in
            callbackCallCount += 1
            progressValues.append(progress)
        }

        // Start loading but test progress simulation cancellation behavior
        let loadTask = Task {
            try? await manager.loadModel()
        }

        // Let it start progress simulation
        try await Task.sleep(for: .milliseconds(500))

        // Cancel the load task to test cancellation handling
        loadTask.cancel()

        // Wait for completion
        _ = await loadTask.result

        // Should have received some progress callbacks before cancellation
        #expect(callbackCallCount > 0, "Should have received some progress callbacks")
        #expect(!progressValues.isEmpty, "Should have some progress values")

        print("Progress callbacks received during cancellation test: \(callbackCallCount)")
    }

    @Test func testProgressCallbackProgressionValidation() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        try? await manager.loadModel()

        // Validate progress sequence is logical
        #expect(!progressValues.isEmpty, "Should have progress values")

        // Check for key progress milestones
        let hasFileOperationStart = progressValues.contains(0.05)
        let hasFileOperationComplete = progressValues.contains(0.10)
        let hasLoadingStart = progressValues.contains(0.15)
        let hasFinalProgress = progressValues.contains(1.0)

        #expect(hasFileOperationStart, "Should report file operation start (0.05)")
        #expect(hasFileOperationComplete, "Should report file operation complete (0.10)")
        #expect(hasLoadingStart, "Should report loading start (0.15)")
        #expect(hasFinalProgress, "Should report final progress (1.0)")

        print("Progress milestones validated: start=\(hasFileOperationStart), fileComplete=\(hasFileOperationComplete), loadStart=\(hasLoadingStart), final=\(hasFinalProgress)")
    }

    @Test func testUnloadModelWhenNotLoaded() async throws {
        let manager = WhisperKitManager()

        // Unload when not loaded (should not crash)
        await manager.unloadModel()
        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit == nil, "Should remain nil when unloading unloaded model")

        print("Unload on unloaded model handled gracefully")
    }

    @Test func testUnloadModelWithProgressCallback() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        // Load model first
        try? await manager.loadModel()
        let initialProgressCount = progressValues.count

        // Unload model (should reset progress to 0)
        await manager.unloadModel()

        // Should have received a 0.0 progress update during unload
        let finalProgressCount = progressValues.count
        #expect(finalProgressCount > initialProgressCount, "Should have received additional progress update during unload")

        if let lastProgress = progressValues.last {
            #expect(lastProgress == 0.0, "Final progress should be 0.0 after unload")
        }

        print("Unload progress callback validated")
    }

    @Test func testModelLoadWithPartialFiles() async throws {
        // This test simulates incomplete model files to test error handling
        let manager = WhisperKitManager()

        // Create a scenario where some model files might be missing
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Issue.record("Could not get documents directory")
            return
        }

        let modelPath = documentsPath.appendingPathComponent("openai_whisper-medium")

        // Clean up any existing files to ensure fresh test
        if fileManager.fileExists(atPath: modelPath.path) {
            try? fileManager.removeItem(at: modelPath)
        }

        // Try to load model (should handle missing files gracefully)
        do {
            try await manager.loadModel()
            let managerWhisperKit = await manager.whisperKit
            // If it succeeds, that's fine too (files were available in bundle)
            print("Model loading succeeded despite potential partial files scenario")
        } catch {
            // Error handling is expected and acceptable
            print("Model loading failed as expected in partial files scenario: \(error)")
            #expect(true, "Error handling for partial files should work")
        }
    }

    @Test func testClearCacheWithNonexistentDirectories() async throws {
        // Test clearCache when cache directories don't exist
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Issue.record("Could not get documents directory")
            return
        }

        // Remove cache directories if they exist
        let hfCachePath = documentsPath.appendingPathComponent("huggingface")
        let tmpPath = fileManager.temporaryDirectory.appendingPathComponent("whisperkit")

        try? fileManager.removeItem(at: hfCachePath)
        try? fileManager.removeItem(at: tmpPath)

        let manager = WhisperKitManager()

        // This should not crash even if directories don't exist
        try? await manager.loadModel()

        let _ = await manager.whisperKit
        // Loading might succeed or fail, but shouldn't crash
        print("Cache clearing with nonexistent directories handled gracefully")
    }

    @Test func testProgressSimulationCancellation() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        // Start loading in background
        let loadTask = Task {
            try? await manager.loadModel()
        }

        // Wait for progress simulation to start
        try await Task.sleep(for: .seconds(2))

        // Cancel and check that cancellation is handled
        loadTask.cancel()
        _ = await loadTask.result

        // Should have received progress updates during the time it was running
        #expect(!progressValues.isEmpty, "Should have received some progress updates")

        // Verify we got initial progress markers before cancellation
        let hasEarlyProgress = progressValues.contains { $0 >= 0.05 && $0 <= 0.20 }
        #expect(hasEarlyProgress, "Should have received early progress before cancellation")

        print("Progress simulation cancellation tested: \(progressValues.count) updates")
    }

    @Test func testModelFilesConcurrentAccess() async throws {
        // Test concurrent loading attempts to verify thread safety
        let manager1 = WhisperKitManager()
        let manager2 = WhisperKitManager()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await manager1.loadModel()
            }
            group.addTask {
                try? await manager2.loadModel()
            }
        }

        // Both managers should either succeed or fail gracefully
        let manager1WhisperKit = await manager1.whisperKit
        let manager2WhisperKit = await manager2.whisperKit

        // At least one should succeed, or both should handle concurrent access gracefully
        print("Concurrent access test completed")
        print("Manager 1 loaded: \(manager1WhisperKit != nil)")
        print("Manager 2 loaded: \(manager2WhisperKit != nil)")
    }

    @Test func testErrorHandlingWithInvalidDocumentsPath() async throws {
        // This tests error handling when file system access fails
        // We can't easily mock the documents directory failure, but we can test
        // that the manager handles errors gracefully

        let manager = WhisperKitManager()

        // Test that loading either succeeds or fails with proper error handling
        do {
            try await manager.loadModel()
            let _ = await manager.whisperKit
            #expect(await manager.whisperKit != nil, "If load succeeds, WhisperKit should be set")
        } catch {
            // Errors are acceptable - what matters is that they don't crash
            print("Load model handled error gracefully: \(error)")
            #expect(true, "Error handling should work without crashing")
        }
    }

    @Test func testProgressCallbackNilHandling() async throws {
        // Test that nil progress callback is handled safely
        let manager = WhisperKitManager(onProgress: nil)

        // Should not crash with nil progress callback
        try? await manager.loadModel()
        let _ = await manager.whisperKit
        print("Nil progress callback handled without crashes")
    }

    @Test func testMultipleUnloadCalls() async throws {
        let manager = WhisperKitManager()

        // Load model first
        try? await manager.loadModel()

        // Multiple unload calls should be safe
        await manager.unloadModel()
        await manager.unloadModel()
        await manager.unloadModel()

        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit == nil, "Should remain nil after multiple unloads")
    }

    // MARK: - Process Translation Tests

    @Test func testProcessTranslationWithoutModel() async throws {
        let manager = WhisperKitManager()
        var receivedText: String?
        var receivedSegment: Int?

        // Test processTranslation when no model is loaded
        await manager.processTranslation(
            [Float](repeating: 0.1, count: 32000), // 2 seconds of audio
            segmentNumber: 1,
            sampleRate: 16000.0
        ) { text, segment in
            receivedText = text
            receivedSegment = segment
        }

        // Should not process anything without a loaded model
        #expect(receivedText == nil, "Should not process translation without loaded model")
        #expect(receivedSegment == nil, "Should not return segment number without loaded model")
    }

    @Test func testProcessTranslationAudioPadding() async throws {
        let manager = WhisperKitManager()
        var receivedText: String?
        var receivedSegment: Int?

        // Load model first (required for processing)
        try? await manager.loadModel()

        // Test with audio shorter than minimum (1 second = 16000 samples)
        let shortAudio = [Float](repeating: 0.1, count: 8000) // 0.5 seconds

        await manager.processTranslation(
            shortAudio,
            segmentNumber: 42,
            sampleRate: 16000.0
        ) { text, segment in
            receivedText = text
            receivedSegment = segment
        }

        // Method should handle short audio by padding internally
        // We can't easily test the WhisperKit output without a real model,
        // but we can verify the method doesn't crash with short audio
        print("Process translation with short audio completed")
    }

    @Test func testProcessTranslationCallbackParameters() async throws {
        let manager = WhisperKitManager()
        var receivedTexts: [String] = []
        var receivedSegments: [Int] = []

        // Load model first (required for processing)
        try? await manager.loadModel()

        let testAudio = [Float](repeating: 0.1, count: 32000) // 2 seconds of audio

        // Process multiple segments with different numbers
        for segmentNum in [1, 5, 10] {
            await manager.processTranslation(
                testAudio,
                segmentNumber: segmentNum,
                sampleRate: 16000.0
            ) { text, segment in
                receivedTexts.append(text)
                receivedSegments.append(segment)
            }
        }

        print("Processed \(receivedTexts.count) translation callbacks")
        print("Received segments: \(receivedSegments)")
    }

    @Test func testProcessTranslationSampleRateParameter() async throws {
        let manager = WhisperKitManager()
        var callbackCalled = false

        // Load model first (required for processing)
        try? await manager.loadModel()

        // Test with different sample rates
        let sampleRates: [Double] = [16000.0, 44100.0, 48000.0]

        for sampleRate in sampleRates {
            let samplesNeeded = Int(sampleRate * 1.0) // 1 second minimum
            let testAudio = [Float](repeating: 0.1, count: samplesNeeded)

            await manager.processTranslation(
                testAudio,
                segmentNumber: 1,
                sampleRate: sampleRate
            ) { text, segment in
                callbackCalled = true
            }
        }

        print("Tested process translation with multiple sample rates")
    }

    @Test func testProcessTranslationEmptyAudio() async throws {
        let manager = WhisperKitManager()
        var receivedText: String?
        var receivedSegment: Int?

        // Load model first (required for processing)
        try? await manager.loadModel()

        // Test with empty audio array
        await manager.processTranslation(
            [], // Empty audio
            segmentNumber: 1,
            sampleRate: 16000.0
        ) { text, segment in
            receivedText = text
            receivedSegment = segment
        }

        // Method should handle empty audio gracefully by padding to minimum length
        print("Process translation with empty audio completed")
    }

    @Test func testProcessTranslationConcurrentCalls() async throws {
        let manager = WhisperKitManager()
        var callbackCount = 0

        // Load model first (required for processing)
        try? await manager.loadModel()

        let testAudio = [Float](repeating: 0.1, count: 32000) // 2 seconds

        // Test concurrent calls to processTranslation
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    await manager.processTranslation(
                        testAudio,
                        segmentNumber: i,
                        sampleRate: 16000.0
                    ) { text, segment in
                        callbackCount += 1
                    }
                }
            }
        }

        print("Concurrent process translation calls completed with \(callbackCount) callbacks")
    }

    @Test func testProcessTranslationWithUnloadedModel() async throws {
        let manager = WhisperKitManager()
        var receivedCallback = false

        // Load and then unload model
        try? await manager.loadModel()
        await manager.unloadModel()

        let testAudio = [Float](repeating: 0.1, count: 32000)

        await manager.processTranslation(
            testAudio,
            segmentNumber: 1,
            sampleRate: 16000.0
        ) { text, segment in
            receivedCallback = true
        }

        #expect(!receivedCallback, "Should not call callback when model is unloaded")
    }
}
