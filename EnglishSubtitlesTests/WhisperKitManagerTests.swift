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

        #expect(manager.whisperKit == nil, "WhisperKit should be nil before loading")
    }

    @Test func testWhisperKitManagerInitializationWithProgressCallback() async throws {
        var progressValues: [Double] = []

        let manager = WhisperKitManager { progress in
            progressValues.append(progress)
        }

        #expect(manager.whisperKit == nil, "WhisperKit should be nil before loading")
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

        #expect(manager.whisperKit != nil, "WhisperKit should be loaded after loadModel()")
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
        let firstInstance = manager.whisperKit

        #expect(firstInstance != nil, "First load should succeed")

        // Load model second time (should work even if already loaded)
        try await manager.loadModel()
        let secondInstance = manager.whisperKit

        #expect(secondInstance != nil, "Second load should succeed")

        print("Model can be reloaded multiple times")
    }

    // MARK: - Model Unloading Tests

    @Test func testUnloadModel() async throws {
        // Load model first
        try? await manager.loadModel()
        #expect(manager.whisperKit != nil, "Model should be loaded")

        // Unload model
        manager.unloadModel()
        #expect(manager.whisperKit == nil, "Model should be nil after unload")
    }

    @Test func testUnloadModelIdempotency() async throws {
        // Unload when not loaded (should not crash)
        manager.unloadModel()
        #expect(manager.whisperKit == nil, "Should handle unload when already nil")

        // Load, then unload multiple times
        try? await manager.loadModel()
        manager.unloadModel()
        manager.unloadModel() // Should be safe to call multiple times

        #expect(manager.whisperKit == nil, "Should remain nil after multiple unloads")
    }

    @Test func testLoadUnloadCycle() async throws {
        // Test multiple load/unload cycles
        for i in 0..<3 {
            print("Load/Unload cycle #\(i)")

            try? await manager.loadModel()
            #expect(manager.whisperKit != nil, "Should load successfully in cycle \(i)")

            manager.unloadModel()
            #expect(manager.whisperKit == nil, "Should unload successfully in cycle \(i)")
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
        #expect(manager.whisperKit != nil, "Should load initially")

        // Unload and reload (which calls clearCache internally)
        manager.unloadModel()
        try? await manager.loadModel()

        #expect(manager.whisperKit != nil, "Should load after cache clearing")
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
        #expect(manager.whisperKit != nil, "Should load with nil progress callback")
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

        #expect(manager1.whisperKit != nil, "Manager 1 should load successfully")
        #expect(manager2.whisperKit != nil, "Manager 2 should load successfully")

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

        #expect(manager.whisperKit != nil, "Model should be loaded")
    }

    @Test func testReloadPerformance() async throws {
        // First load (may be slow)
        let startTime1 = Date()
        try? await manager.loadModel()
        let firstLoadDuration = Date().timeIntervalSince(startTime1)

        manager.unloadModel()

        // Second load (should be faster due to cached files)
        let startTime2 = Date()
        try? await manager.loadModel()
        let secondLoadDuration = Date().timeIntervalSince(startTime2)

        print("First load: \(String(format: "%.2f", firstLoadDuration))s")
        print("Second load: \(String(format: "%.2f", secondLoadDuration))s")

        #expect(manager.whisperKit != nil, "Should load successfully on reload")

        // Second load might be faster due to cached files, but not guaranteed
        // Just ensure both complete in reasonable time
        #expect(firstLoadDuration < 180.0, "First load should complete in reasonable time")
        #expect(secondLoadDuration < 180.0, "Second load should complete in reasonable time")
    }

    // MARK: - Integration Tests

    @Test func testWhisperKitManagerInSpeechRecognitionService() async throws {
        // Verify that WhisperKitManager integrates correctly with SpeechRecognitionService
        let service = SpeechRecognitionService()

        // Load the model first
        await service.loadModel()

        // Wait for model to load
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "SpeechRecognitionService should be ready after WhisperKitManager loads model")
    }

    @Test func testMultipleServicesUsingSameManager() async throws {
        // Test that multiple services can use WhisperKitManager
        let service1 = SpeechRecognitionService()
        let service2 = SpeechRecognitionService()

        await service1.loadModel()
        await service2.loadModel()

        let ready1 = await TestHelpers.waitForWhisperKit(service1, maxWait: 5.0)
        let ready2 = await TestHelpers.waitForWhisperKit(service2, maxWait: 5.0)

        #expect(ready1, "Service 1 should be ready")
        #expect(ready2, "Service 2 should be ready")
    }
}
