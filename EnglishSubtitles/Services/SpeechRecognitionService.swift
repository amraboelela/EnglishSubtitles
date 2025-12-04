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

    // Audio buffer accumulation (protected by serial queue)
    private let audioQueue = DispatchQueue(label: "com.englishsubtitles.audioprocessing")
    private var audioBuffer: [Float] = []
    private let maxSegmentDuration: Double = 5.0 // Process when buffer reaches 5 seconds
    private let sampleRate: Double = 16000.0
    private var isProcessing = false

    // Silence detection
    private let silenceThreshold: Float = 0.015 // RMS threshold for silence
    private let silenceDurationRequired: Double = 0.7 // Require 0.7s of silence to end segment
    private var silenceStartTime: Double? // When silence started
    private var lastChunkWasSilent = true // Start as true since we haven't received speech yet
    private var segmentNumber = 0 // Track segment number
    private var lastAudioTime: Double = 0 // Last time we received audio
    private var hasReceivedSpeech = false // Track if we've received any speech in this segment

    init(onProgress: ((Double) -> Void)? = nil) {
        whisperKitManager = WhisperKitManager(onProgress: onProgress)
        // Don't load model automatically - wait for explicit loadModel() call
    }

    func loadModel() async {
        // Unload any existing model first to ensure clean slate
        unloadModel()

        do {
            try await whisperKitManager?.loadModel()
        } catch {
            print("Failed to load WhisperKit model: \(error)")
        }
    }

    func unloadModel() {
        whisperKitManager?.unloadModel()
    }

    /// Start translating audio to English
    /// - Parameter onTranslationUpdate: Callback with English translation and segment number
    /// - Returns: Success status
    func startListening(
        onTranslationUpdate: @escaping (String, Int) -> Void
    ) async -> Bool {
        guard whisperKitManager?.whisperKit != nil else {
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

    private func accumulateAudio(_ buffer: AVAudioPCMBuffer) async {
        // Resample to 16kHz if needed
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)

        // Convert to float array
        let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)

        // Calculate RMS for silence detection
        let rms = AudioStreamManager.calculateRMS(audioData)
        let now = CFAbsoluteTimeGetCurrent()

        // Check if we should process a segment (decision made inside queue, processing outside)
        let segmentToProcess: ([Float], Int)? = await withCheckedContinuation { continuation in
            audioQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                // Update last audio time
                self.lastAudioTime = now

                // Accumulate samples (thread-safe)
                self.audioBuffer.append(contentsOf: audioData)

                let currentDuration = Double(self.audioBuffer.count) / self.sampleRate

                // Detect silence
                let isSilent = rms < self.silenceThreshold

                if isSilent {
                    // Start silence timer if not already started
                    if self.silenceStartTime == nil {
                        self.silenceStartTime = now
                    }
                } else {
                    // Reset silence timer when we hear sound
                    self.silenceStartTime = nil
                    self.hasReceivedSpeech = true // Mark that we've received speech in this segment
                }

                // Calculate how long we've been silent
                let silenceDuration = self.silenceStartTime != nil ? (now - self.silenceStartTime!) : 0

                // Check if we should end the segment
                let silenceHit = silenceDuration >= self.silenceDurationRequired
                let durationHit = currentDuration >= self.maxSegmentDuration

                // Process segment ONLY if we have actual speech content
                if (silenceHit || durationHit) && !self.audioBuffer.isEmpty && !self.isProcessing {
                    if self.hasReceivedSpeech {
                        // We have speech content - prepare it for processing
                        self.isProcessing = true

                        // Copy buffer for processing
                        let audioToProcess = self.audioBuffer
                        let currentSegment = self.segmentNumber

                        if silenceHit {
                            print("🔇 Silence detected (\(String(format: "%.1f", silenceDuration))s) - processing segment #\(currentSegment) (\(audioToProcess.count) samples)")
                        } else {
                            print("⏱️ Max duration (\(String(format: "%.1f", currentDuration))s) - processing segment #\(currentSegment) (\(audioToProcess.count) samples)")
                        }

                        // Clear buffer and reset state
                        self.audioBuffer.removeAll(keepingCapacity: true)
                        self.silenceStartTime = nil
                        self.hasReceivedSpeech = false // Reset for next segment

                        // Return segment data to process outside the queue
                        continuation.resume(returning: (audioToProcess, currentSegment))
                        return
                    } else {
                        // No speech received - just discard the silent buffer
                        print("🗑️ Discarding silent buffer (\(self.audioBuffer.count) samples)")
                        self.audioBuffer.removeAll(keepingCapacity: true)
                        self.silenceStartTime = nil
                    }
                }

                continuation.resume(returning: nil)
            }
        }

        // Process segment OUTSIDE the audioQueue to avoid blocking
        if let (audioToProcess, currentSegment) = segmentToProcess {
            Task.detached { [weak self] in
                guard let self else { return }
                print("🎯 Starting WhisperKit processing for segment #\(currentSegment)")
                await self.processTranslation(audioToProcess, segmentNumber: currentSegment)
                print("✅ Completed WhisperKit processing for segment #\(currentSegment)")
                await self.markProcessingComplete()
                print("✅ Marked segment #\(currentSegment) as complete, ready for next segment")
            }
        }
    }

    private func markProcessingComplete() async {
        await withCheckedContinuation { continuation in
            audioQueue.async { [weak self] in
                self?.isProcessing = false
                self?.segmentNumber += 1  // Increment AFTER processing completes
                continuation.resume()
            }
        }
    }

    private func processTranslation(_ audioData: [Float], segmentNumber: Int) async {
        guard let whisperKit = whisperKitManager?.whisperKit else { return }

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

            if !text.isEmpty {
                NSLog("🌍 Segment #\(segmentNumber) translation: \(text)")
                NSLog("📝 Sending to ViewModel: segment #\(segmentNumber)")
                translationCallback?(text, segmentNumber)
            } else {
                print("⚠️ Empty result for segment #\(segmentNumber)")
            }
        } catch {
            print("❌ Translation error: \(error)")
        }
    }

    func stopListening() {
        audioQueue.sync {
            audioStreamManager?.stopRecording()
            audioStreamManager = nil
            audioBuffer.removeAll()
            isProcessing = false
            silenceStartTime = nil
            lastChunkWasSilent = true // Reset to true (no speech state)
            segmentNumber = 0
            lastAudioTime = 0
            hasReceivedSpeech = false // Reset speech tracking
        }
    }

    var isReady: Bool {
        return whisperKitManager?.whisperKit != nil
    }

    // MARK: - Testing Support

    /// Process an audio file for testing purposes (not for real-time use)
    /// - Parameters:
    ///   - audioFileURL: URL to the audio file
    ///   - task: The task to perform (.transcribe or .translate)
    ///   - language: Optional language code (e.g., "tr" for Turkish, "en" for English)
    /// - Returns: The transcribed/translated text
    func processAudioFile(at audioFileURL: URL, task: DecodingTask, language: String? = nil) async throws -> String {
        guard let whisperKit = whisperKitManager?.whisperKit else {
            throw AudioStreamError.engineSetupFailed
        }

        // Load the audio file
        let audioFile = try AVAudioFile(forReading: audioFileURL)
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        // WhisperKit expects 16kHz mono PCM
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: 16000,
                                               channels: 1,
                                               interleaved: false) else {
            throw AudioStreamError.engineSetupFailed
        }

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
