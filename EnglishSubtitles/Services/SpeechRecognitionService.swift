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
    private let maxBufferDuration: Double = 30.0 // WhisperKit model limit (30 seconds max)
    private let sampleRate: Double = 16000.0
    private var isProcessing = false

    // Silence detection
    private let silenceThreshold: Float = 0.025 // Slightly higher RMS threshold to reduce noise processing
    private let silenceDurationRequired: Double = 1.0 // Require 1.0s of silence to end segment (was 0.7s)
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
                let modelLimitHit = currentDuration >= (self.maxBufferDuration - 1.0) // Process 1 second before WhisperKit 30s limit

                // Process segment ONLY if we have actual speech content
                if (silenceHit || modelLimitHit) && !self.audioBuffer.isEmpty && !self.isProcessing {
                    if self.hasReceivedSpeech {
                        // We have speech content - prepare it for processing
                        self.isProcessing = true

                        // Copy buffer for processing
                        let audioToProcess = self.audioBuffer
                        let currentSegment = self.segmentNumber

                        if silenceHit {
                            print("🔇 Silence detected (\(String(format: "%.1f", silenceDuration))s) - processing segment #\(currentSegment) (\(audioToProcess.count) samples, \(String(format: "%.1f", currentDuration))s)")
                        } else {
                            print("⏰ WhisperKit limit approaching (\(String(format: "%.1f", currentDuration))s) - processing segment #\(currentSegment) (\(audioToProcess.count) samples)")
                        }

                        // Clear buffer and reset state - RELEASE MEMORY IMMEDIATELY
                        self.audioBuffer.removeAll(keepingCapacity: false) // Don't keep capacity
                        self.silenceStartTime = nil
                        self.hasReceivedSpeech = false // Reset for next segment

                        // Return segment data to process outside the queue
                        continuation.resume(returning: (audioToProcess, currentSegment))
                        return
                    } else {
                        // No speech received - just discard the silent buffer
                        print("🗑️ Discarding silent buffer (\(self.audioBuffer.count) samples)")
                        self.audioBuffer.removeAll(keepingCapacity: false) // Don't keep capacity
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

            if !text.isEmpty && !isLikelyHallucination(text) {
                NSLog("🌍 Segment #\(segmentNumber) translation: \(text)")
                NSLog("📝 Sending to ViewModel: segment #\(segmentNumber)")
                translationCallback?(text, segmentNumber)
            } else {
                if isLikelyHallucination(text) {
                    print("🚫 Filtered hallucination: \(text)")
                } else {
                    print("⚠️ Empty result for segment #\(segmentNumber)")
                }
            }
        } catch {
            print("❌ Translation error: \(error)")
        }
    }

    /// Filter out common WhisperKit hallucinations
    private func isLikelyHallucination(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Common hallucination patterns for silence/background noise
        let hallucinations = [
            "see you in next video",
            "see you in the next video",
            "see you in the next",
            "subscribe",
            "don't forget to subscribe",
            "like and subscribe",
            "thanks for watching",
            "thank you for watching",
            "bye bye",
            "bye",
            "goodbye",
            "see you later",
            "see you next time",
            "music",
            "applause",
            "laughter",
            "silence",
            "translated by",
            "translation by",
            "subtitle by",
            "subtitled by",
            "i'm sorry, i'm sorry",
            "the end",
            "-come on. -come on.",
            "-turkish. -turkish.",
            "-i'm sorry. -it's okay.",
            "-let's go. -let's go.",
            ".",
            "?",
            "!",
            "...",
            "subtitle",
            "subtitles",
            "captions"
        ]

        // Check for exact matches or if text starts with common patterns
        for hallucination in hallucinations {
            if lowercased == hallucination || lowercased.hasPrefix(hallucination) {
                return true
            }
        }

        // Filter very short outputs (likely hallucinations)
        if lowercased.count <= 2 {
            return true
        }

        // Filter repetitive patterns (e.g., "a a a a")
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)
        if words.count > 1 {
            let uniqueWords = Set(words)
            // If most words are the same, likely a hallucination
            if Double(uniqueWords.count) / Double(words.count) < 0.5 {
                return true
            }
        }

        // Filter bracketed annotations like (music), [laughter], (footsteps), *door closes*, -The End-
        let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("(") && trimmed.hasSuffix(")")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) ||
           (trimmed.hasPrefix("*") && trimmed.hasSuffix("*")) ||
           (trimmed.hasPrefix("-") && trimmed.hasSuffix("-")) {
            return true
        }

        return false
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
