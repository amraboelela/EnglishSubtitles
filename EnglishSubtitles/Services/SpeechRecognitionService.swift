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
    private var whisperKit: WhisperKit?
    private var audioStreamManager: AudioStreamManager?

    // Callbacks for updates
    private var translationCallback: ((String, Int) -> Void)?
    private var progressCallback: ((Double) -> Void)?

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
        progressCallback = onProgress
        Task {
            await loadModel()
        }
    }

    private func loadModel() async {
        do {
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
        } catch {
            print("Failed to load WhisperKit model: \(error)")
            progressCallback?(0.0) // Reset on error
        }
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
        let bundle = Bundle(for: SpeechRecognitionService.self)
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

    /// Start translating audio to English
    /// - Parameter onTranslationUpdate: Callback with English translation and segment number
    /// - Returns: Success status
    func startListening(
        onTranslationUpdate: @escaping (String, Int) -> Void
    ) async -> Bool {
        guard whisperKit != nil else {
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
        let resampledBuffer = resampleIfNeeded(buffer)

        // Convert to float array
        let audioData = convertBufferToFloatArray(resampledBuffer)

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
                // Only process silence detection if we weren't already silent
                if !lastChunkWasSilent {
                    print("🔇 Silence/music detected - ending segment #\(segmentNumber)")
                    lastChunkWasSilent = true
                    segmentNumber += 1
                }

                // Reset buffer for new segment
                print("🔄 Resetting buffer")
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
        let rms = calculateRMS(samples)
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
        guard let whisperKit = whisperKit else { return false }

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

    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    private func processTranslation(_ audioData: [Float]) async {
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

    private func resampleIfNeeded(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let format = buffer.format

        // If already 16kHz, return as-is
        if format.sampleRate == 16000 {
            return buffer
        }

        // Create target format: 16kHz mono
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ),
        let converter = AVAudioConverter(from: format, to: targetFormat) else {
            return buffer
        }

        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / format.sampleRate))
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return buffer
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        return error == nil ? convertedBuffer : buffer
    }

    private func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        // WhisperKit expects mono audio at 16kHz
        // If we have stereo, average the channels
        let channelCount = Int(buffer.format.channelCount)

        var samples: [Float] = []
        samples.reserveCapacity(frameLength)

        if channelCount == 1 {
            // Mono audio - direct copy
            for i in 0..<frameLength {
                samples.append(channelDataValue[i])
            }
        } else {
            // Stereo or multi-channel - average to mono
            for i in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][i]
                }
                samples.append(sum / Float(channelCount))
            }
        }

        return samples
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
        return whisperKit != nil
    }

    // MARK: - Testing Support

    /// Process an audio file for testing purposes (not for real-time use)
    /// - Parameters:
    ///   - audioFileURL: URL to the audio file
    ///   - task: The task to perform (.transcribe or .translate)
    ///   - language: Optional language code (e.g., "tr" for Turkish, "en" for English)
    /// - Returns: The transcribed/translated text
    func processAudioFile(at audioFileURL: URL, task: DecodingTask, language: String? = nil) async throws -> String {
        guard let whisperKit = whisperKit else {
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

        // Resample to 16kHz if needed
        let resampledBuffer: AVAudioPCMBuffer
        if format.sampleRate != 16000 {
            guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
                throw AudioStreamError.engineSetupFailed
            }

            let capacity = AVAudioFrameCount(Double(frameCount) * (16000.0 / format.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
                throw AudioStreamError.engineSetupFailed
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                throw AudioStreamError.engineSetupFailed
            }

            resampledBuffer = convertedBuffer
        } else {
            resampledBuffer = buffer
        }

        // Convert to float array
        let audioData = convertBufferToFloatArray(resampledBuffer)

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

// MARK: - Audio Stream Manager

class AudioStreamManager {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioCallback: ((AVAudioPCMBuffer) -> Void)?

    func startRecording(onAudioBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        audioCallback = onAudioBuffer

        // Request microphone permission
        let permissionGranted = await AVAudioApplication.requestRecordPermission()
        guard permissionGranted else {
            print("❌ Microphone permission denied")
            throw AudioStreamError.permissionDenied
        }

        print("✓ Microphone permission granted")

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioStreamError.engineSetupFailed
        }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioStreamError.inputNodeNotAvailable
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Microphone format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")

        // Install tap with nil format to use the hardware's native format
        // This is the safest approach - let the system choose the format
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, time in
            self?.audioCallback?(buffer)
        }

        try audioEngine.start()
        print("✓ Audio engine started")
    }

    func stopRecording() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
    }
}

enum AudioStreamError: Error {
    case permissionDenied
    case engineSetupFailed
    case inputNodeNotAvailable
}
