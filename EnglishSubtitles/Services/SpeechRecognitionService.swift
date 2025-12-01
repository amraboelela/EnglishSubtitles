//
//  SpeechRecognitionService.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation
import WhisperKit
import AVFoundation

/// Service that handles multilingual speech-to-text and translation using WhisperKit
class SpeechRecognitionService {
    private var audioStreamManager: AudioStreamManager?
    private var whisperKitManager: WhisperKitManager?

    // Callbacks for updates
    private var translationCallback: ((String, Int) -> Void)?

    // Audio buffer accumulation
    private var audioBuffer: [Float] = []
    private let segmentDuration: Double = 1.5 // Process every 1.5 seconds
    private let sampleRate: Double = 16000.0
    private var isProcessing = false
    private var lastProcessedCount = 0

    // Silence detection
    private let silenceThreshold: Float = 0.01 // RMS threshold for silence
    private var lastChunkWasSilent = false
    private var segmentNumber = 0 // Track segment number

    init(onProgress: ((Double) -> Void)? = nil) {
        whisperKitManager = WhisperKitManager(onProgress: onProgress)
        Task {
            await loadModel()
        }
    }

    private func loadModel() async {
        do {
            try await whisperKitManager?.loadModel()
        } catch {
            print("Failed to load WhisperKit model: \(error)")
        }
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

        // Accumulate samples
        audioBuffer.append(contentsOf: audioData)

        let currentDuration = Double(audioBuffer.count) / sampleRate
        let newAudioDuration = Double(audioBuffer.count - lastProcessedCount) / sampleRate

        // Process every 1.5 seconds of NEW audio (not already processing)
        if newAudioDuration >= segmentDuration && !isProcessing {
            isProcessing = true

            // Get the new 1.5s chunk to check for silence/music
            let chunkStart = lastProcessedCount
            let chunkEnd = audioBuffer.count
            let chunk = Array(audioBuffer[chunkStart..<chunkEnd])

            // Check if this chunk is silence or music
            let isSilentOrMusic = await isSilenceOrMusic(chunk)

            if isSilentOrMusic {
                // Only log once when silence starts
                if !lastChunkWasSilent {
                    print("🔇 Silence/music detected - ending segment #\(segmentNumber)")
                    print("🔄 Resetting buffer")
                    lastChunkWasSilent = true
                    segmentNumber += 1
                }

                // Clear buffer during silence to prevent memory buildup
                audioBuffer.removeAll(keepingCapacity: true)
                lastProcessedCount = 0
            } else {
                // Process entire buffer from the beginning (with growing context)
                let audioToProcess = audioBuffer
                lastProcessedCount = audioBuffer.count

                print("🎯 Processing buffer: \(String(format: "%.2f", Double(audioToProcess.count) / sampleRate))s")
                await processTranslation(audioToProcess)
                lastChunkWasSilent = false
            }

            isProcessing = false
        }
    }

    private func isSilenceOrMusic(_ samples: [Float]) async -> Bool {
        guard !samples.isEmpty else { return true }

        // Check RMS for silence
        let rms = AudioStreamManager.calculateRMS(samples)
        if rms < silenceThreshold {
            return true
        }

        // WhisperKit requires at least 1.0 seconds of audio (16000 samples at 16kHz)
        let minSamples = Int(sampleRate * 1.0)
        var processedSamples = samples

        if processedSamples.count < minSamples {
            print("⚠️ Chunk too short for music detection: \(processedSamples.count) samples, padding to \(minSamples)")
            // Pad with silence to reach minimum length
            processedSamples.append(contentsOf: [Float](repeating: 0.0, count: minSamples - processedSamples.count))
        }

        // Use WhisperKit to detect if it's music (no text detected)
        guard let whisperKit = whisperKitManager?.whisperKit else { return false }

        do {
            let results = try await whisperKit.transcribe(
                audioArray: processedSamples,
                decodeOptions: DecodingOptions(task: .translate, language: "tr")
            )

            // If no segments or empty text, it's likely music
            let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            let isMusic = text.isEmpty || text.count < 3 // Very short text is likely noise/music

            if isMusic {
                print("🎵 Music detected (no speech)")
            }

            return isMusic
        } catch {
            print("❌ Error checking for music: \(error)")
            return false
        }
    }

    private func processTranslation(_ audioData: [Float]) async {
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
                print("🌍 Segment #\(segmentNumber): \(text)")
                print("📝 Sending to ViewModel: segment #\(segmentNumber)")
                translationCallback?(text, segmentNumber)
            } else {
                print("⚠️ Empty result for segment #\(segmentNumber)")
            }
        } catch {
            print("❌ Translation error: \(error)")
        }
    }

    func stopListening() {
        audioStreamManager?.stopRecording()
        audioStreamManager = nil
        audioBuffer.removeAll()
        isProcessing = false
        lastProcessedCount = 0
        lastChunkWasSilent = false
        segmentNumber = 0
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
