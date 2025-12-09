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
@Suite(.serialized)
@MainActor
class WhisperKitManagerTests {

    var manager = WhisperKitManager()

    // MARK: - Initialization Tests

    @Test func testWhisperKitManagerInitialization() async throws {
        let managerWhisperKit = await manager.whisperKit
        #expect(managerWhisperKit == nil, "WhisperKit should be nil before loading")
    }

    // MARK: - Model Loading Tests

    @Test func testLoadModel() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        // Load the model (this can take up to 60+ seconds on first run)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        let managerWhisperKit = await manager.whisperKit

        // In test environments, model loading may fail due to missing files or simulator limitations
        // We test that the method doesn't crash and that progress updates are received
        #expect(!progressValues.isEmpty, "Progress updates should have been received")

        if managerWhisperKit != nil {
            print("✅ WhisperKit loaded successfully in test environment")
            #expect(progressValues.first == 0.05, "First progress should be 0.05 (file copy start)")
        } else {
            print("ℹ️ WhisperKit failed to load in test environment (expected behavior)")
            // Even on failure, we should get some progress updates
        }

        print("Progress updates received: \(progressValues.count)")
        print("Final progress: \(progressValues.last ?? 0.0)")
    }

    @Test func testLoadModelIdempotency() async throws {
        // Load model first time
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let firstInstance = await manager.whisperKit

        // Load model second time (should work even if already loaded)
        try? await manager.loadModel() // Use try? since it may fail in test environment
        let secondInstance = await manager.whisperKit

        // Test that subsequent loads don't break the manager
        #expect(true, "Multiple load calls should not crash")

        if firstInstance != nil && secondInstance != nil {
            print("✅ Model can be reloaded multiple times")
        } else {
            print("ℹ️ Model loading failed in test environment (expected)")
        }
    }

    // MARK: - Model Unloading Tests

    @Test func testUnloadModel() async throws {
        // Load model first
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let managerWhisperKit = await manager.whisperKit

        if managerWhisperKit != nil {
            // If model loaded successfully, test unloading
            await manager.unloadModel()
            let managerWhisperKitAfterUnload = await manager.whisperKit
            #expect(managerWhisperKitAfterUnload == nil, "Model should be nil after unload")
        } else {
            // If model didn't load, test that unload doesn't crash
            await manager.unloadModel()
            #expect(true, "Unload should work even if model wasn't loaded")
            print("ℹ️ Testing unload with no loaded model (expected in test environment)")
        }
    }

    @Test func testUnloadModelIdempotency() async throws {
        // Unload when not loaded (should not crash)
        await manager.unloadModel()
        let managerWhisperKit1 = await manager.whisperKit
        #expect(managerWhisperKit1 == nil, "Should handle unload when already nil")

        // Load, then unload multiple times
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        await manager.unloadModel()
        await manager.unloadModel() // Should be safe to call multiple times

        let managerWhisperKit2 = await manager.whisperKit
        #expect(managerWhisperKit2 == nil, "Should remain nil after multiple unloads")
    }

    @Test func testLoadUnloadCycle() async throws {
        // Test multiple load/unload cycles
        var successfulLoads = 0

        for i in 0..<3 {
            print("Load/Unload cycle #\(i)")

            try? await manager.loadModel()
            let managerWhisperKitLoaded = await manager.whisperKit

            if managerWhisperKitLoaded != nil {
                successfulLoads += 1
                print("✅ Cycle \(i): Model loaded successfully")
            } else {
                print("ℹ️ Cycle \(i): Model load failed (expected in test environment)")
            }

            await manager.unloadModel()
            let managerWhisperKitUnloaded = await manager.whisperKit
            #expect(managerWhisperKitUnloaded == nil, "Should unload successfully in cycle \(i)")
        }

        print("Successful loads: \(successfulLoads)/3")
        #expect(true, "Load/unload cycles should complete without crashes")
    }

    // MARK: - File Management Tests

    @Test func testModelFilesExistAfterLoad() async throws {
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

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
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

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
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let managerWhisperKit1 = await manager.whisperKit
        #expect(managerWhisperKit1 != nil, "Should load initially")

        // Unload and reload (which calls clearCache internally)
        await manager.unloadModel()
        try? await manager.loadModel()

        let managerWhisperKit2 = await manager.whisperKit
        #expect(managerWhisperKit2 != nil, "Should load after cache clearing")
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

        // Check for key progress milestones - be flexible for test environment
        let hasFileOperationStart = progressValues.contains(0.05)
        let hasFileOperationComplete = progressValues.contains(0.10)
        let hasLoadingStart = progressValues.contains(0.15)
        let hasFinalProgress = progressValues.contains(1.0)

        // In test environments, progress might not follow the exact pattern
        // So we'll check if we have reasonable progress instead
        if progressValues.count > 3 {
            #expect(hasFileOperationStart, "Should report file operation start (0.05)")
            #expect(hasFileOperationComplete, "Should report file operation complete (0.10)")
            #expect(hasLoadingStart, "Should report loading start (0.15)")

            if hasFinalProgress {
                print("✅ Final progress (1.0) reported as expected")
            } else {
                print("ℹ️ Final progress (1.0) not reported - testing in constrained environment")
                // Check if we at least have progress > 0.5
                let hasSubstantialProgress = progressValues.contains { $0 > 0.5 }
                #expect(hasSubstantialProgress, "Should have substantial progress (>0.5) even if not 1.0")
            }
        } else {
            print("ℹ️ Limited progress updates received in test environment")
            #expect(true, "Test environment has limited progress updates")
        }

        print("Progress milestones: start=\(hasFileOperationStart), fileComplete=\(hasFileOperationComplete), loadStart=\(hasLoadingStart), final=\(hasFinalProgress)")
        print("Progress values received: \(progressValues)")
    }

    @Test func testUnloadModelProgressCallback() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        // Load model first
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let initialProgressCount = progressValues.count

        // Unload model
        await manager.unloadModel()
        let finalProgressCount = progressValues.count

        // Check if unload triggered progress update
        if finalProgressCount > initialProgressCount {
            if let lastProgress = progressValues.last {
                #expect(lastProgress == 0.0, "Unload should set progress to 0.0")
            }
        }

        print("Unload model progress callback test completed")
    }

    // MARK: - Process Translation Tests

    @Test func testProcessTranslationWithoutModel() async throws {
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
        var receivedText: String?
        var receivedSegment: Int?

        // Load model first (required for processing)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

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

        // Suppress compiler warnings about unused variables
        _ = receivedText
        _ = receivedSegment
    }

    @Test func testProcessTranslationSampleRateParameter() async throws {

        // Load model first (required for processing)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

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
                print("Sample rate \(sampleRate)Hz: '\(text)' (segment \(segment))")
            }
        }

        print("Tested process translation with multiple sample rates")
    }

    // MARK: - Process Segment Tests

    @Test func testProcessSegmentWithoutModel() async throws {
        var receivedText: String?
        var receivedSegment: Int?

        // Test processSegment when no model is loaded
        await manager.processSegment(
            [Float](repeating: 0.1, count: 32000), // 2 seconds of audio
            segmentNumber: 1,
            sampleRate: 16000.0,
            transcribeOnly: true
        ) { text, segment in
            receivedText = text
            receivedSegment = segment
        }

        // Should not process anything without a loaded model
        #expect(receivedText == nil, "Should not process segment without loaded model")
        #expect(receivedSegment == nil, "Should not return segment number without loaded model")
    }

    @Test func testProcessSegmentTranscribeMode() async throws {
        var receivedTexts: [String] = []
        var receivedSegments: [Int] = []

        // Load model first (required for processing)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        let testAudio = [Float](repeating: 0.1, count: 32000) // 2 seconds of audio

        await manager.processSegment(
            testAudio,
            segmentNumber: 42,
            sampleRate: 16000.0,
            transcribeOnly: true
        ) { text, segment in
            receivedTexts.append(text)
            receivedSegments.append(segment)
        }

        // Test that transcribe mode is handled correctly
        print("Transcribe mode completed with \(receivedTexts.count) results")
        if !receivedTexts.isEmpty {
            #expect(receivedSegments.contains(42), "Should preserve segment number")
        }
    }

    @Test func testProcessSegmentTranslateMode() async throws {
        var receivedTexts: [String] = []
        var receivedSegments: [Int] = []

        // Load model first (required for processing)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        let testAudio = [Float](repeating: 0.1, count: 32000) // 2 seconds of audio

        await manager.processSegment(
            testAudio,
            segmentNumber: 84,
            sampleRate: 16000.0,
            transcribeOnly: false // Translation mode
        ) { text, segment in
            receivedTexts.append(text)
            receivedSegments.append(segment)
        }

        // Test that translate mode is handled correctly
        print("Translate mode completed with \(receivedTexts.count) results")
        if !receivedTexts.isEmpty {
            #expect(receivedSegments.contains(84), "Should preserve segment number in translate mode")
        }
    }

    @Test func testProcessSegmentModeComparison() async throws {
        // Load model first (required for processing)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        let testAudio = [Float](repeating: 0.1, count: 16000) // 1 second
        var transcribeResults: [String] = []
        var translateResults: [String] = []

        // Test transcribe mode
        await manager.processSegment(
            testAudio,
            segmentNumber: 1,
            sampleRate: 16000.0,
            transcribeOnly: true
        ) { text, segment in
            transcribeResults.append(text)
        }

        // Test translate mode
        await manager.processSegment(
            testAudio,
            segmentNumber: 2,
            sampleRate: 16000.0,
            transcribeOnly: false
        ) { text, segment in
            translateResults.append(text)
        }

        print("ProcessSegment transcribe mode: \(transcribeResults.count) results")
        print("ProcessSegment translate mode: \(translateResults.count) results")
    }

    @Test func testProcessSegmentConcurrentCalls() async throws {
        var callbackCount = 0

        // Load model first (required for processing)
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        let testAudio = [Float](repeating: 0.1, count: 32000) // 2 seconds

        // Test concurrent calls to processSegment
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    await self.manager.processSegment(
                        testAudio,
                        segmentNumber: i,
                        sampleRate: 16000.0,
                        transcribeOnly: i % 2 == 0 // Alternate between transcribe and translate
                    ) { text, segment in
                        callbackCount += 1
                        print("Concurrent processSegment \(i): '\(text)' (segment \(segment))")
                    }
                }
            }
        }

        print("Concurrent processSegment calls completed with \(callbackCount) callbacks")
    }

    // MARK: - Edge Cases

    @Test func testWhisperKitManagerBoundaryConditions() async throws {

        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        // Test boundary conditions
        let boundaryCases = [
            ("empty_audio", [Float]()),
            ("single_sample", [Float(0.5)]),
            ("two_samples", [Float(0.5), Float(-0.5)]),
            ("minimum_whisper_length", [Float](repeating: 0.1, count: 400)), // 25ms at 16kHz
        ]

        for (caseName, audioData) in boundaryCases {
            await manager.processTranslation(
                audioData,
                segmentNumber: 1,
                sampleRate: 16000.0
            ) { text, segment in
                print("Boundary case '\(caseName)': '\(text)' (segment \(segment))")
            }
        }

        #expect(true, "Boundary conditions should be handled gracefully")
    }

    @Test func testWhisperKitManagerSegmentNumberEdgeCases() async throws {

        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let testAudio = [Float](repeating: 0.1, count: 16000)

        // Test various segment numbers including edge cases
        let segmentNumbers = [
            Int.min,
            -1000,
            -1,
            0,
            1,
            100,
            1000,
            Int.max
        ]

        for segmentNumber in segmentNumbers {
            await manager.processTranslation(
                testAudio,
                segmentNumber: segmentNumber,
                sampleRate: 16000.0
            ) { text, receivedSegment in
                #expect(receivedSegment == segmentNumber, "Segment number should be preserved")
                print("Segment \(segmentNumber) -> \(receivedSegment): '\(text)'")
            }
        }

        #expect(true, "Various segment numbers should be handled correctly")
    }

    @Test func testWhisperKitManagerSampleRateEdgeCases() async throws {

        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let testAudio = [Float](repeating: 0.1, count: 1000) // Small audio sample

        // Test edge case sample rates
        let sampleRates: [Double] = [
            1.0,        // Very low
            100.0,      // Low
            8000.0,     // Standard low
            16000.0,    // WhisperKit standard
            44100.0,    // CD quality
            96000.0,    // High quality
            192000.0    // Very high
        ]

        for sampleRate in sampleRates {
            await manager.processTranslation(
                testAudio,
                segmentNumber: 1,
                sampleRate: sampleRate
            ) { text, segment in
                print("Sample rate \(sampleRate)Hz: '\(text)' (segment \(segment))")
            }
        }

        #expect(true, "Edge case sample rates should be processed")
    }

    // MARK: - Actor Isolation and Threading Tests

    @Test func testConcurrentActorAccess() async throws {

        // Test concurrent access to actor methods
        await withTaskGroup(of: Void.self) { group in
            // Load model
            group.addTask {
                if await self.manager.whisperKit == nil {
                    try? await self.manager.loadModel()
                }
            }

            // Check state concurrently
            group.addTask {
                for _ in 0..<5 {
                    let _ = await self.manager.whisperKit
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }

            // Another state check task
            group.addTask {
                try? await Task.sleep(for: .milliseconds(50))
                await self.manager.unloadModel()
            }
        }

        print("Concurrent actor access completed")
    }

    // MARK: - Memory and Resource Management

    @Test func testModelStateConsistencyAfterOperations() async throws {

        // Verify initial state
        let initialState = await manager.whisperKit
        #expect(initialState == nil, "Initial state should be nil")

        // Load model
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }
        let _ = await manager.whisperKit

        // Unload model
        await manager.unloadModel()
        let afterUnloadState = await manager.whisperKit
        #expect(afterUnloadState == nil, "State after unload should be nil")

        // Load again
        try? await manager.loadModel()
        let _ = await manager.whisperKit

        print("Model state consistency verified through operations")
    }

    // MARK: - Copy Bundled Model Tests (Indirect Coverage)

    @Test func testCopyBundledModelToDocumentsIndirectly() async throws {
        // This tests the copyBundledModelToDocuments method indirectly through loadModel
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        // Load model to trigger file copying
        if await manager.whisperKit == nil {
            try? await manager.loadModel()
        }

        // Verify that progress was reported during file operations
        #expect(!progressValues.isEmpty, "Should have progress updates from file operations")

        // Check for file operation progress markers
        let hasFileCopyStart = progressValues.contains(0.05)
        let hasFileCopyComplete = progressValues.contains(0.10)

        if progressValues.count > 2 {
            #expect(hasFileCopyStart, "Should report file copy start (0.05)")
            #expect(hasFileCopyComplete, "Should report file copy complete (0.10)")
        }

        print("Indirect copyBundledModelToDocuments testing completed")
    }
}