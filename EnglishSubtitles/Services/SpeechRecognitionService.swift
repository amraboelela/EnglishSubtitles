//
//  SpeechRecognitionService.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation
import WhisperKit
import AVFoundation
import os.log

/// Service that handles multilingual speech-to-text and translation using WhisperKit
class SpeechRecognitionService: @unchecked Sendable {
    private var audioStreamManager: AudioStreamManager?
    private var whisperKitManager: WhisperKitManager?

    // Callbacks for updates
    private var translationCallback: ((String, Int) -> Void)?

    // Audio buffer management using Swift Concurrency Actor (replaces GCD queue)
    private let bufferActor = AudioBufferActor()
    private let maxBufferDuration: Double = 30.0 // WhisperKit model limit (30 seconds max)
    private let sampleRate: Double = 16000.0

    // Silence detection configuration
    private let silenceThreshold: Float = 0.025 // Slightly higher RMS threshold to reduce noise processing
    private let silenceDurationRequired: Double = 1.0 // Require 1.0s of silence to end segment (was 0.7s)
    private var lastChunkWasSilent = true // Start as true since we haven't received speech yet
    private var lastAudioTime: Double = 0 // Last time we received audio

    /// Initialize the speech recognition service
    /// - Parameter onProgress: Optional callback for model loading progress (0.0 to 1.0)
    init(onProgress: ((Double) -> Void)? = nil) {
        whisperKitManager = WhisperKitManager(onProgress: onProgress)
        // Don't load model automatically - wait for explicit loadModel() call
    }

    /// Load the WhisperKit model for speech recognition and translation
    /// Must be called before starting listening - may take several seconds to complete
    func loadModel() async {
        // Unload any existing model first to ensure clean slate
        await unloadModel()

        do {
            try await whisperKitManager?.loadModel()
        } catch {
            print("Failed to load WhisperKit model: \(error)")
        }
    }

    /// Unload the WhisperKit model to free memory
    func unloadModel() async {
        await whisperKitManager?.unloadModel()
    }

    /// Start real-time audio listening and translation to English
    /// Processes microphone input in segments based on silence detection or 30-second limit
    /// - Returns: True if listening started successfully, false if model not ready
    func startListening(
        onTranslationUpdate: @escaping (String, Int) -> Void
    ) async -> Bool {
        guard await whisperKitManager?.whisperKit != nil else {
            print("WhisperKit not initialized")
            return false
        }

        translationCallback = onTranslationUpdate

        // Start audio streaming - single stream for both tasks
        if audioStreamManager == nil {
            audioStreamManager = AudioStreamManager()
        }

        do {
            try await audioStreamManager?.startRecording { [weak self] buffer in
                guard let self = self else { return }
                Task {
                    await self.accumulateAudio(buffer)
                }
            }
            return true
        } catch {
            print("Failed to start audio recording: \(error)")
            return false
        }
    }

    /// Process incoming audio buffer and manage segment boundaries
    /// This function uses the AudioBufferActor to safely manage state and determine when to process segments.
    /// Much cleaner than the previous GCD-based approach - no more withCheckedContinuation needed!
    /// - Parameter buffer: Audio buffer from microphone input
    private func accumulateAudio(_ buffer: AVAudioPCMBuffer) async {
        // Resample to 16kHz if needed
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)

        // Convert to float array
        let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)

        // Calculate RMS for silence detection
        let rms = AudioStreamManager.calculateRMS(audioData)
        let now = CFAbsoluteTimeGetCurrent()

        // Update last audio time
        lastAudioTime = now

        // Ask the actor to process the audio and determine if we should cut a segment
        // This replaces all the complex GCD queue logic with a simple actor call
        let segmentToProcess = await bufferActor.appendAudio(
            audioData,
            now: now,
            rms: rms,
            sampleRate: sampleRate,
            maxBufferDuration: maxBufferDuration,
            silenceThreshold: silenceThreshold,
            silenceDurationRequired: silenceDurationRequired
        )

        // Process segment if the actor determined one is ready
        if let (audioToProcess, segmentNumber) = segmentToProcess {
            Task { [weak self] in
                guard let self else { return }
                print("🎯 Starting WhisperKit processing for segment #\(segmentNumber)")
                await self.processTranslation(audioToProcess, segmentNumber: segmentNumber)
                print("✅ Completed WhisperKit processing for segment #\(segmentNumber)")
                await self.bufferActor.markProcessingComplete()
                print("✅ Marked segment #\(segmentNumber) as complete, ready for next segment")
            }
        }
    }

    /// Process audio data through WhisperKit for translation to English
    /// Handles audio padding (WhisperKit requires minimum 1.0 second of audio),
    /// performs translation using the .translate task, and filters out hallucinations.
    ///
    /// - Parameter audioData: Float array of audio samples (16kHz mono)
    /// - Parameter segmentNumber: Segment identifier for tracking and logging
    private func processTranslation(_ audioData: [Float], segmentNumber: Int) async {
        guard let whisperKit = await whisperKitManager?.whisperKit else { return }

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
                translationCallback?(text, segmentNumber)
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

    /// Stop audio listening and clean up resources
    /// Stops microphone recording, releases audio buffers, and resets all state.
    /// Safe to call multiple times.
    func stopListening() {
        audioStreamManager?.stopRecording()
        audioStreamManager = nil
        lastChunkWasSilent = true // Reset to true (no speech state)
        lastAudioTime = 0

        // Reset the actor state
        Task {
            await bufferActor.reset()
        }
    }

    /// Check if the service is ready for audio processing
    /// Returns true when WhisperKit model is loaded and ready for translation
    var isReady: Bool {
        get async {
            return await whisperKitManager?.whisperKit != nil
        }
    }

    // MARK: - Testing Support

    /// Process an audio file for testing - loads entire file and processes through WhisperKit
    /// - Returns: The complete transcribed/translated text from the entire audio file
    func processAudioFile(at audioFileURL: URL, task: DecodingTask, language: String? = nil) async throws -> String {
        guard let whisperKit = await whisperKitManager?.whisperKit else {
            throw AudioStreamError.engineSetupFailed
        }

        // Load the audio file
        let audioFile = try AVAudioFile(forReading: audioFileURL)
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioStreamError.engineSetupFailed
        }

        try audioFile.read(into: buffer)

        // Resample to 16kHz if needed and convert to float array
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)
        let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)

        guard !audioData.isEmpty else {
            throw AudioStreamError.engineSetupFailed
        }

        // Process with WhisperKit
        var decodingOptions = DecodingOptions(task: task)
        if let language = language {
            decodingOptions.language = language
        }
        let results = try await whisperKit.transcribe(
            audioArray: audioData,
            decodeOptions: decodingOptions
        )

        // Extract text from all segments
        let combinedText = results.map { $0.text }.joined(separator: " ")

        return combinedText
    }
}
