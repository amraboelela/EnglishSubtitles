//
//  WhisperKitManagerTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/1/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for WhisperKitManager - Model loading and initialization
@MainActor
class WhisperKitManagerTests {

    var manager = WhisperKitManager()

    // MARK: - Initialization Tests

    @Test func testWhisperKitManagerInitialization() async throws {
        //let manager = WhisperKitManager()

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
        //#expect(progressValues.last == 1.0, "Last progress should be 1.0 (complete)")

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
        //#expect(progressValues.contains(1.0), "Should contain 1.0 (complete)")
    }

    @Test func testLoadModelIdempotency() async throws {
        //let manager = WhisperKitManager()

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

    // MARK: - File Management Tests

    @Test func testModelFilesExistAfterLoad() async throws {
        //let manager = WhisperKitManager()

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
        //let manager = WhisperKitManager()

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

    // MARK: - Performance Tests

    @Test func testLoadModelPerformance() async throws {
        //let manager = WhisperKitManager()

        let startTime = Date()
        try? await manager.loadModel()
        let duration = Date().timeIntervalSince(startTime)

        print("Model load time: \(String(format: "%.2f", duration)) seconds")

        // On first run (downloading), this can take 60+ seconds
        // On subsequent runs (files cached), this should be faster
        #expect(duration < 180.0, "Model should load within 3 minutes (allows for slow download)")

        #expect(manager.whisperKit != nil, "Model should be loaded")
    }

    // MARK: - Integration Tests

    @Test func testWhisperKitManagerInSpeechRecognitionService() async throws {
        // Verify that WhisperKitManager integrates correctly with SpeechRecognitionService
        let service = SpeechRecognitionService()

        // Wait for model to load
        let isReady = await TestHelpers.waitForWhisperKit(service)

        #expect(isReady, "SpeechRecognitionService should be ready after WhisperKitManager loads model")
    }
}
