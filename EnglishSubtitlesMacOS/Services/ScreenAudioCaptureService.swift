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
    private let bufferSize = 16000 // 1 second at 16kHz

    override init() {
        super.init()
    }

    func startCapture() async throws {
        // Get available content for screen audio capture
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }

        // Configure stream for audio capture
        // Note: Using display filter enables video internally, causing harmless
        // "stream output NOT found. Dropping frame" warnings in console.
        // This is expected ScreenCaptureKit behavior for audio-only capture.
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000 // 16kHz for Whisper
        config.channelCount = 1 // Mono

        // Create and start stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Only add audio output
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "AudioCaptureQueue"))
        try await stream?.startCapture()
    }
}

// MARK: - SCStreamDelegate
extension ScreenAudioCaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("#debug Stream stopped with error: \(error.localizedDescription)")
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

        // Check actual sample rate
        if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
           let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
            let actualSampleRate = asbd.mSampleRate
            if actualSampleRate != 16000 {
                print("#debug ⚠️  Audio sample rate is \(actualSampleRate)Hz, need to resample to 16kHz")
            }
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
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            print("#debug ❌ No format description")
            return nil
        }

        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            print("#debug ❌ No audio stream description")
            return nil
        }

        // Verify Float32 format
        guard asbd.mFormatID == kAudioFormatLinearPCM,
              asbd.mBitsPerChannel == 32 else {
            print("#debug ❌ Unexpected audio format: \(asbd.mFormatID), bits: \(asbd.mBitsPerChannel)")
            return nil
        }

        var audioBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: asbd.mChannelsPerFrame,
                mDataByteSize: 0,
                mData: nil
            )
        )

        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            print("#debug ❌ Failed to get audio buffer list: \(status)")
            return nil
        }

        let buffer = audioBufferList.mBuffers
        let frameCount = Int(CMSampleBufferGetNumSamples(sampleBuffer))

        guard let data = buffer.mData else {
            print("#debug ❌ No audio data")
            return nil
        }

        let floatPtr = data.assumingMemoryBound(to: Float.self)
        let samples = Array(UnsafeBufferPointer(start: floatPtr, count: frameCount))

        return samples
    }
}
