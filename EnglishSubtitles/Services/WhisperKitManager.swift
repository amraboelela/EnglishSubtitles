//
//  WhisperKitManager.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/1/25.
//

import Foundation
import WhisperKit

/// Manages WhisperKit model loading and initialization with thread-safe serialized access
actor WhisperKitManager {
    private var progressCallback: ((Double) -> Void)?
    private(set) var whisperKit: WhisperKit?

    init(onProgress: ((Double) -> Void)? = nil) {
        progressCallback = onProgress
    }

    /// Load WhisperKit model with progress updates
    func loadModel() async throws {
        print("Starting model load...")

        // Clear cache before loading to prevent memory buildup
        clearCache()

        // Step 1: Copy files (10% of progress)
        progressCallback?(0.05)
        let modelPath = try await copyBundledModelToDocuments()
        //print("Model path: \(modelPath)")
        progressCallback?(0.10)

        // Step 2: Load WhisperKit (90% of progress)
        // Simulate progress during loading since WhisperKit doesn't provide callbacks
        progressCallback?(0.15)

        // Start simulating progress in background (60 seconds from 15% to 95%)
        let progressTask = Task {
            // 80% range over 60 seconds = ~1.3% per second
            for progress in stride(from: 0.15, to: 0.95, by: 0.013) {
                // Stop if task was cancelled
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(1.0))
                if Task.isCancelled { break }
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

        // Cancel progress simulation and wait for it to stop
        progressTask.cancel()
        _ = await progressTask.result

        // Now safe to send final 1.0
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

        // Copy each file/folder with concurrent-safe error handling
        for file in requiredFiles {
            let sourcePath = (bundleResourcePath as NSString).appendingPathComponent(file)
            let destPath = modelDestPath.appendingPathComponent(file)

            // Skip if already exists (concurrent tests may have copied it)
            if fileManager.fileExists(atPath: destPath.path) {
                continue
            }

            // Copy from source if it exists
            if fileManager.fileExists(atPath: sourcePath) {
                do {
                    try fileManager.copyItem(atPath: sourcePath, toPath: destPath.path)
                } catch let error as NSError {
                    // If error is "file exists", another test copied it - ignore
                    if error.code != 516 { // NSFileWriteFileExistsError
                        throw error
                    }
                }
            }
        }

        print("✓ Model files ready at: \(modelDestPath.path)")
        return modelDestPath.path
    }

    /// Unload model to free memory
    func unloadModel() {
        if whisperKit != nil {
            print("Unloading WhisperKit model to free memory...")
            whisperKit = nil
            progressCallback?(0.0)
            print("✓ Model unloaded")
        }
    }

    /// Process translation of audio data using WhisperKit
    /// - Parameters:
    ///   - audioData: Float array of audio samples
    ///   - segmentNumber: Segment identifier for tracking
    ///   - sampleRate: Audio sample rate (typically 16000)
    ///   - translationCallback: Callback for translation results (text, segmentNumber)
    func processTranslation(
        _ audioData: [Float],
        segmentNumber: Int,
        sampleRate: Double,
        translationCallback: @escaping (String, Int) -> Void
    ) async {
        guard let whisperKit = whisperKit else { return }

        // WhisperKit requires at least 1.0 seconds of audio (16000 samples at 16kHz)
        // Pad if necessary to prevent memory access errors
        let minSamples = Int(sampleRate * 1.0)
        var processedAudio = audioData

        if processedAudio.count < minSamples {
            print("⚠️ Audio too short: \(processedAudio.count) samples, padding to \(minSamples)")
            // Pad with silence (zeros) to reach minimum length
            processedAudio.append(contentsOf: [Float](repeating: 0.0, count: minSamples - processedAudio.count))
        }

        do {
            // Translate with .translate task (converts to English)
            let results = try await whisperKit.transcribe(
                audioArray: processedAudio,
                decodeOptions: DecodingOptions(task: .translate, language: "tr")
            )

            // Extract text from all segments
            let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)

            if !text.isEmpty && !text.isLikelyHallucination {
                NSLog("🌍 Segment #\(segmentNumber) translation: \(text)")
                NSLog("📝 Sending to ViewModel: segment #\(segmentNumber)")
                translationCallback(text, segmentNumber)
            } else {
                if text.isLikelyHallucination {
                    print("🚫 Filtered hallucination: \(text)")
                } else {
                    print("⚠️ Empty result for segment #\(segmentNumber)")
                }
            }
        } catch {
            print("❌ Translation error: \(error)")
        }
    }

    /// Clear WhisperKit cache to prevent memory buildup
    private func clearCache() {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        // Clear HuggingFace cache (used by WhisperKit for downloads)
        let hfCachePath = documentsPath.appendingPathComponent("huggingface")
        if fileManager.fileExists(atPath: hfCachePath.path) {
            do {
                try fileManager.removeItem(at: hfCachePath)
                print("✓ Cleared HuggingFace cache")
            } catch {
                print("⚠️ Failed to clear HuggingFace cache: \(error)")
            }
        }

        // Clear any temporary WhisperKit files
        let tmpPath = fileManager.temporaryDirectory.appendingPathComponent("whisperkit")
        if fileManager.fileExists(atPath: tmpPath.path) {
            do {
                try fileManager.removeItem(at: tmpPath)
                print("✓ Cleared WhisperKit temp files")
            } catch {
                print("⚠️ Failed to clear WhisperKit temp: \(error)")
            }
        }
    }
}
