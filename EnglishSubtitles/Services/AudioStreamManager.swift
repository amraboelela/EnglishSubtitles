//
//  AudioStreamManager.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/1/25.
//

import Foundation
import AVFoundation

/// Manages audio capture from the microphone and provides audio processing utilities
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

    // MARK: - Audio Processing Utilities

    /// Resample audio buffer to 16kHz mono if needed
    /// - Parameter buffer: Source audio buffer
    /// - Returns: Resampled buffer at 16kHz mono, or original if already 16kHz
    static func resampleIfNeeded(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
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

    /// Convert audio buffer to float array
    /// - Parameter buffer: Audio buffer to convert
    /// - Returns: Float array suitable for WhisperKit (mono audio at 16kHz)
    static func convertBufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
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

    /// Calculate RMS (Root Mean Square) of audio samples
    /// - Parameter samples: Audio samples
    /// - Returns: RMS value
    static func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }

        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}

enum AudioStreamError: Error {
    case permissionDenied
    case engineSetupFailed
    case inputNodeNotAvailable
}
