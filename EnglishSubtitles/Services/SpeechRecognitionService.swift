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
    private let maxBufferDuration: Double = 10.0 // Hard limit to prevent unbounded buffer growth
    private let sampleRate: Double = 16000.0
    private var isProcessing = false

    // Silence detection
    private let silenceThreshold: Float = 0.015 // RMS threshold for silence
    private let silenceDurationRequired: Double = 0.7 // Require 0.7s of silence to end segment
    private var silenceStartTime: Double? // When silence started
    private var segmentNumber = 0 // Track segment number
    private var hasReceivedSpeech = false // Track if we've received any speech in this segment

    // Translation configuration
    private var sourceLanguage: String = "tr" // Default to Turkish

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
    /// - Parameters:
    ///   - sourceLanguage: Source language code (e.g., "tr" for Turkish, "ar" for Arabic). Defaults to "tr".
    ///   - onTranslationUpdate: Callback with English translation and segment number
    /// - Returns: Success status
    func startListening(
        sourceLanguage: String = "tr",
        onTranslationUpdate: @escaping (String, Int) -> Void
    ) async -> Bool {
        guard whisperKitManager?.whisperKit != nil else {
            print("WhisperKit not initialized")
            return false
        }

        self.sourceLanguage = sourceLanguage
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
        let segmentToProcess: ([Float], Int)? = await audioQueue.sync { [weak self] in
            guard let self else { return nil }

            // Accumulate samples (thread-safe)
            self.audioBuffer.append(contentsOf: audioData)

            let currentDuration = Double(self.audioBuffer.count) / self.sampleRate

            // Hard buffer limit: discard oldest audio if exceeded to prevent unbounded growth
            if currentDuration > self.maxBufferDuration {
                let maxSamples = Int(self.maxBufferDuration * self.sampleRate)
                let excessSamples = self.audioBuffer.count - maxSamples
                print("⚠️ Buffer overflow: \(String(format: "%.1f", currentDuration))s - discarding \(excessSamples) samples")
                self.audioBuffer.removeFirst(excessSamples)
            }

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

            // Minimum samples to prevent processing noise (0.1 seconds)
            let minSamples = Int(self.sampleRate * 0.1)

            // ALWAYS break segments at maxSegmentDuration, even if already processing
            // This prevents unbounded buffer growth
            if durationHit && !self.audioBuffer.isEmpty && self.hasReceivedSpeech {
                print("⏱️ Max duration (\(String(format: "%.1f", currentDuration))s) - forcing segment #\(self.segmentNumber) (\(self.audioBuffer.count) samples)")

                // Mark as processing to prevent overlapping segments
                self.isProcessing = true

                // Copy buffer for processing
                let audioToProcess = self.audioBuffer
                let currentSegment = self.segmentNumber

                // Clear buffer and reset state
                self.audioBuffer.removeAll(keepingCapacity: true)
                self.silenceStartTime = nil
                self.hasReceivedSpeech = false
                self.segmentNumber += 1

                // Return segment data to process
                return (audioToProcess, currentSegment)
            }

            // Process segment on silence ONLY if not currently processing and buffer has meaningful content
            if silenceHit && self.audioBuffer.count >= minSamples && self.hasReceivedSpeech && !self.isProcessing {
                print("🔇 Silence detected (\(String(format: "%.1f", silenceDuration))s) - processing segment #\(self.segmentNumber) (\(self.audioBuffer.count) samples)")

                // Mark as processing to prevent overlapping segments
                self.isProcessing = true

                // Copy buffer for processing
                let audioToProcess = self.audioBuffer
                let currentSegment = self.segmentNumber

                // Clear buffer and reset state
                self.audioBuffer.removeAll(keepingCapacity: true)
                self.silenceStartTime = nil
                self.hasReceivedSpeech = false
                self.segmentNumber += 1

                // Return segment data to process
                return (audioToProcess, currentSegment)
            }

            return nil
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
        await audioQueue.sync { [weak self] in
            self?.isProcessing = false
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
                decodeOptions: DecodingOptions(task: .translate, language: sourceLanguage)
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
            segmentNumber = 0
            hasReceivedSpeech = false
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

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioStreamError.engineSetupFailed
        }

        try audioFile.read(into: buffer)

        // Resample to 16kHz if needed and convert to float array
        // AudioStreamManager.resampleIfNeeded() handles conversion to 16kHz mono PCM
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
