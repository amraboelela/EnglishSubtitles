//
//  ScreenAudioCaptureService.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/25/26.
//

import Foundation
import ScreenCaptureKit
import AVFoundation

class ScreenAudioCaptureService: NSObject {
    var onAudioData: ((Data) async -> Void)?

    private var stream: SCStream?
    private var audioBuffer: [Float] = []
    private let bufferSize = 16000 * 3 // 3 seconds at 16kHz

    override init() async throws {
        super.init()
        try await setupScreenCapture()
    }

    private func setupScreenCapture() async throws {
        // Request permission
        guard try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) != nil else {
            throw NSError(domain: "ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get shareable content"])
        }
    }

    func startCapture() async throws {
        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        // Configure stream - audio only
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000 // 16kHz for Whisper
        config.channelCount = 1 // Mono

        // Create and start stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "AudioCaptureQueue"))
        try await stream?.startCapture()
    }

    func stopCapture() {
        Task {
            try? await stream?.stopCapture()
            stream = nil
            audioBuffer.removeAll()
        }
    }
}

// MARK: - SCStreamDelegate
extension ScreenAudioCaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
}

// MARK: - SCStreamOutput
extension ScreenAudioCaptureService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Convert sample buffer to float array
        guard let audioSamples = convertSampleBufferToFloatArray(sampleBuffer) else {
            return
        }

        // Accumulate audio samples
        audioBuffer.append(contentsOf: audioSamples)

        // When we have enough data, send it for transcription
        if audioBuffer.count >= bufferSize {
            let dataToTranscribe = audioBuffer
            audioBuffer.removeAll()

            // Convert float array to Data
            let data = Data(bytes: dataToTranscribe, count: dataToTranscribe.count * MemoryLayout<Float>.size)

            Task {
                await onAudioData?(data)
            }
        }
    }

    private func convertSampleBufferToFloatArray(_ sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        let length = CMBlockBufferGetDataLength(blockBuffer)
        var data = [Int16](repeating: 0, count: length / MemoryLayout<Int16>.size)

        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)

        // Convert Int16 to Float and normalize
        return data.map { Float($0) / 32768.0 }
    }
}
