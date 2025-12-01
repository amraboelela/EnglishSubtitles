//
//  WhisperKitManager.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/1/25.
//

import Foundation
import WhisperKit

/// Manages WhisperKit model loading and initialization
class WhisperKitManager {
    private var progressCallback: ((Double) -> Void)?
    private(set) var whisperKit: WhisperKit?

    init(onProgress: ((Double) -> Void)? = nil) {
        progressCallback = onProgress
    }

    /// Load WhisperKit model with progress updates
    func loadModel() async throws {
        print("Starting model load...")

        // Step 1: Copy files (10% of progress)
        progressCallback?(0.05)
        let modelPath = try await copyBundledModelToDocuments()
        print("Model path: \(modelPath)")
        progressCallback?(0.10)

        // Step 2: Load WhisperKit (90% of progress)
        // Simulate progress during loading since WhisperKit doesn't provide callbacks
        progressCallback?(0.15)

        // Start simulating progress in background (60 seconds from 15% to 95%)
        let progressTask = Task {
            // 80% range over 60 seconds = ~1.3% per second
            for progress in stride(from: 0.15, to: 0.95, by: 0.013) {
                try? await Task.sleep(for: .seconds(1.0))
                self.progressCallback?(progress)
            }
        }

        whisperKit = try await WhisperKit(
            modelFolder: modelPath,
            computeOptions: ModelComputeOptions(
                audioEncoderCompute: .cpuAndNeuralEngine,
                textDecoderCompute: .cpuAndNeuralEngine
            ),
            verbose: false,
            logLevel: .error
        )

        // Cancel progress simulation and set to 100%
        progressTask.cancel()
        progressCallback?(1.0)
        print("Model loaded successfully!")
    }

    private func copyBundledModelToDocuments() async throws -> String {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AudioStreamError.engineSetupFailed
        }

        let modelDestPath = documentsPath.appendingPathComponent("openai_whisper-medium")

        // Clean up any incomplete HuggingFace downloads that might conflict
        let hfCachePath = documentsPath.appendingPathComponent("huggingface")
        if fileManager.fileExists(atPath: hfCachePath.path) {
            try? fileManager.removeItem(at: hfCachePath)
        }

        let requiredFiles = ["config.json", "generation_config.json", "tokenizer.json", "tokenizer_config.json", "AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"]

        // Check if all required files already exist in Documents
        if fileManager.fileExists(atPath: modelDestPath.path) {
            var allFilesExist = true
            for file in requiredFiles {
                let filePath = modelDestPath.appendingPathComponent(file)
                if !fileManager.fileExists(atPath: filePath.path) {
                    allFilesExist = false
                    break
                }
            }

            if allFilesExist {
                return modelDestPath.path
            } else {
                try? fileManager.removeItem(at: modelDestPath)
            }
        }

        // Model files are in bundle root - copy them to Documents/openai_whisper-medium/
        // Use the bundle for this class, not Bundle.main (which may be test bundle)
        let bundle = Bundle(for: WhisperKitManager.self)
        guard let bundleResourcePath = bundle.resourcePath else {
            throw AudioStreamError.engineSetupFailed
        }

        // Create destination directory
        try fileManager.createDirectory(at: modelDestPath, withIntermediateDirectories: true)

        // Copy each file/folder
        for file in requiredFiles {
            let sourcePath = (bundleResourcePath as NSString).appendingPathComponent(file)
            let destPath = modelDestPath.appendingPathComponent(file)

            if fileManager.fileExists(atPath: sourcePath) {
                try fileManager.copyItem(atPath: sourcePath, toPath: destPath.path)
            }
        }

        return modelDestPath.path
    }
}
