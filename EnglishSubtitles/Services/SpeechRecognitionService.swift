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
    private var transcriptCallback: ((String) -> Void)?
    private var translationCallback: ((String) -> Void)?

    init() {
        Task {
            await loadModel()
        }
    }

    private func loadModel() async {
        do {
            print("Loading WhisperKit model...")

            // Copy bundled model files to Documents directory
            let modelPath = try await copyBundledModelToDocuments()

            print("Found model at: \(modelPath)")
            whisperKit = try await WhisperKit(
                modelFolder: modelPath,
                computeOptions: ModelComputeOptions(),
                verbose: true,
                logLevel: .debug
            )
            print("WhisperKit model loaded successfully")
        } catch {
            print("Failed to load WhisperKit model: \(error)")
        }
    }

    private func copyBundledModelToDocuments() async throws -> String {
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AudioStreamError.engineSetupFailed
        }

        let modelDestPath = documentsPath.appendingPathComponent("openai_whisper-base")

        // Clean up any incomplete HuggingFace downloads that might conflict
        let hfCachePath = documentsPath.appendingPathComponent("huggingface")
        if fileManager.fileExists(atPath: hfCachePath.path) {
            try? fileManager.removeItem(at: hfCachePath)
            print("Cleaned up HuggingFace cache to avoid conflicts")
        }

        let requiredFiles = ["config.json", "generation_config.json", "tokenizer.json", "tokenizer_config.json", "AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc"]

        // Check if all required files already exist in Documents
        if fileManager.fileExists(atPath: modelDestPath.path) {
            var allFilesExist = true
            for file in requiredFiles {
                let filePath = modelDestPath.appendingPathComponent(file)
                if !fileManager.fileExists(atPath: filePath.path) {
                    print("Missing file: \(file)")
                    allFilesExist = false
                    break
                }
            }

            if allFilesExist {
                print("Model already exists in Documents directory with all required files")
                return modelDestPath.path
            } else {
                print("Model directory exists but missing some files, will recopy")
                try? fileManager.removeItem(at: modelDestPath)
            }
        }

        // Model files are in bundle root - copy them to Documents/openai_whisper-base/
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
                print("Copied \(file) to Documents")
            } else {
                print("WARNING: \(file) not found in bundle")
            }
        }

        return modelDestPath.path
    }

    /// Start transcribing audio in the original language
    /// - Parameter onTranscriptUpdate: Callback with transcribed text in original language
    /// - Returns: Success status
    func startTranscribing(onTranscriptUpdate: @escaping (String) -> Void) async -> Bool {
        guard let whisperKit = whisperKit else {
            print("WhisperKit not initialized")
            return false
        }

        transcriptCallback = onTranscriptUpdate

        // Start audio streaming for transcription
        if audioStreamManager == nil {
            audioStreamManager = AudioStreamManager()
        }

        do {
            try await audioStreamManager?.startRecording { [weak self] audioBuffer in
                guard let self = self else { return }
                Task {
                    await self.processAudioForTranscription(audioBuffer)
                }
            }
            return true
        } catch {
            print("Failed to start audio recording: \(error)")
            return false
        }
    }

    /// Start translating audio to English
    /// - Parameter onTranslationUpdate: Callback with English translation
    /// - Returns: Success status
    func startTranslating(onTranslationUpdate: @escaping (String) -> Void) async -> Bool {
        guard let whisperKit = whisperKit else {
            print("WhisperKit not initialized")
            return false
        }

        translationCallback = onTranslationUpdate

        // Start audio streaming for translation
        if audioStreamManager == nil {
            audioStreamManager = AudioStreamManager()
        }

        do {
            try await audioStreamManager?.startRecording { [weak self] audioBuffer in
                guard let self = self else { return }
                Task {
                    await self.processAudioForTranslation(audioBuffer)
                }
            }
            return true
        } catch {
            print("Failed to start audio recording: \(error)")
            return false
        }
    }

    private func processAudioForTranscription(_ audioBuffer: AVAudioPCMBuffer) async {
        guard let whisperKit = whisperKit else { return }

        do {
            // Convert audio buffer to format WhisperKit expects
            let audioData = convertBufferToFloatArray(audioBuffer)

            // Transcribe with .transcribe task (maintains original language)
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: DecodingOptions(task: .transcribe)
            )

            // Extract text from all segments
            let text = results.map { $0.text }.joined(separator: " ")
            if !text.isEmpty {
                transcriptCallback?(text)
            }
        } catch {
            print("Transcription error: \(error)")
        }
    }

    private func processAudioForTranslation(_ audioBuffer: AVAudioPCMBuffer) async {
        guard let whisperKit = whisperKit else { return }

        do {
            // Convert audio buffer to format WhisperKit expects
            let audioData = convertBufferToFloatArray(audioBuffer)

            // Translate with .translate task (converts to English)
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: DecodingOptions(task: .translate)
            )

            // Extract text from all segments
            let text = results.map { $0.text }.joined(separator: " ")
            if !text.isEmpty {
                translationCallback?(text)
            }
        } catch {
            print("Translation error: \(error)")
        }
    }

    private func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            print("ERROR: No float channel data available")
            return []
        }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        // WhisperKit expects mono audio at 16kHz
        // If we have stereo, average the channels
        let channelCount = Int(buffer.format.channelCount)
        print("Audio format - Channels: \(channelCount), Sample Rate: \(buffer.format.sampleRate), Frames: \(frameLength)")

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

        print("Converted \(samples.count) samples from \(channelCount) channel(s)")

        // Check for silence
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        print("Max amplitude: \(maxAmplitude)")

        if maxAmplitude < 0.001 {
            print("WARNING: Audio appears to be silent (max amplitude < 0.001)")
        }

        return samples
    }

    func stopTranscribing() {
        audioStreamManager?.stopRecording()
        audioStreamManager = nil
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
            print("ERROR: WhisperKit not initialized")
            throw AudioStreamError.engineSetupFailed
        }

        print("Loading audio file: \(audioFileURL.lastPathComponent)")

        // Load the audio file
        let audioFile = try AVAudioFile(forReading: audioFileURL)
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        print("Audio file loaded - Format: \(format), Frames: \(frameCount)")

        // WhisperKit expects 16kHz mono PCM
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: 16000,
                                               channels: 1,
                                               interleaved: false) else {
            print("ERROR: Failed to create target audio format")
            throw AudioStreamError.engineSetupFailed
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("ERROR: Failed to create audio buffer")
            throw AudioStreamError.engineSetupFailed
        }

        try audioFile.read(into: buffer)
        print("Audio file read into buffer successfully")

        // Resample to 16kHz if needed
        let resampledBuffer: AVAudioPCMBuffer
        if format.sampleRate != 16000 {
            print("Resampling from \(format.sampleRate)Hz to 16000Hz...")
            guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
                print("ERROR: Failed to create audio converter")
                throw AudioStreamError.engineSetupFailed
            }

            let capacity = AVAudioFrameCount(Double(frameCount) * (16000.0 / format.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
                print("ERROR: Failed to create resampled buffer")
                throw AudioStreamError.engineSetupFailed
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                print("ERROR: Audio conversion failed: \(error)")
                throw AudioStreamError.engineSetupFailed
            }

            resampledBuffer = convertedBuffer
            print("Resampling complete - new frame count: \(resampledBuffer.frameLength)")
        } else {
            resampledBuffer = buffer
        }

        // Convert to float array
        let audioData = convertBufferToFloatArray(resampledBuffer)
        print("Converted to float array - Sample count: \(audioData.count)")

        guard !audioData.isEmpty else {
            print("ERROR: Audio data is empty after conversion")
            throw AudioStreamError.engineSetupFailed
        }

        // Process with WhisperKit
        print("Starting WhisperKit transcription with task: \(task)")
        var decodingOptions = DecodingOptions(task: task)
        if let language = language {
            decodingOptions.language = language
            print("Using language: \(language)")
        }
        let results = try await whisperKit.transcribe(
            audioArray: audioData,
            decodeOptions: decodingOptions
        )

        print("WhisperKit returned \(results.count) segments")

        // Print each segment for debugging
        for (index, result) in results.enumerated() {
            print("  Segment \(index): \"\(result.text)\"")
        }

        // Extract text from all segments
        let combinedText = results.map { $0.text }.joined(separator: " ")
        print("Combined text (\(combinedText.count) chars): \"\(combinedText)\"")

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
            throw AudioStreamError.permissionDenied
        }

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioStreamError.engineSetupFailed
        }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioStreamError.inputNodeNotAvailable
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            self?.audioCallback?(buffer)
        }

        try audioEngine.start()
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
