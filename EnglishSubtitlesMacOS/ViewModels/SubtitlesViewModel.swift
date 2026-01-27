//
//  SubtitlesViewModel.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/25/26.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers
import AppKit

@MainActor
class SubtitlesViewModel: ObservableObject {
    @Published var currentSubtitle: String = "Waiting for audio..."
    @Published var isCapturing: Bool = false
    @Published var errorMessage: String?
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    @Published var isDownloading: Bool = false

    private var audioService: ScreenAudioCaptureService?
    private var transcriptionService: TranscriptionService?
    private var audioBuffer: [Float] = []
    private let maxBufferDuration: TimeInterval = 60.0 // Keep last 60 seconds
    private let sampleRate: Double = 16000
    private var subtitleClearTask: Task<Void, Never>?

    func startCapture() async {
        isCapturing = true
        errorMessage = nil
        currentSubtitle = "Initializing..."

        do {
            // Initialize transcription service (will auto-download model if needed)
            transcriptionService = try await TranscriptionService { [weak self] fileName, progress, downloaded, total in
                Task { @MainActor in
                    self?.isDownloading = true
                    self?.downloadProgress = progress
                    let downloadedMB = Double(downloaded) / 1024 / 1024
                    let totalMB = Double(total) / 1024 / 1024
                    self?.downloadStatus = "Downloading \(fileName): \(String(format: "%.1f", downloadedMB)) / \(String(format: "%.1f", totalMB)) MB"
                    self?.currentSubtitle = self?.downloadStatus ?? "Downloading..."
                }
            }

            isDownloading = false
            downloadProgress = 0.0
            downloadStatus = ""

            // Initialize screen audio service
            audioService = ScreenAudioCaptureService()
            audioService?.onAudioData = { [weak self] audioData in
                await self?.processAudio(audioData)
            }
            try await audioService?.startCapture()
            currentSubtitle = "Listening to screen audio..."

        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
            currentSubtitle = "Error - see below"
            isCapturing = false
            isDownloading = false
        }
    }

    func stopCapture() async {
        audioService?.stopCapture()
        audioService = nil
        await transcriptionService?.stop()
        transcriptionService = nil
        subtitleClearTask?.cancel()
        subtitleClearTask = nil
        isCapturing = false
        currentSubtitle = "Stopped"
    }

    private func processAudio(_ audioData: Data) async {
        guard let transcriptionService = transcriptionService else { return }

        // Convert Data to Float array and buffer it
        let floatArray = audioData.withUnsafeBytes { buffer -> [Float] in
            let count = buffer.count / MemoryLayout<Float>.size
            return Array(buffer.bindMemory(to: Float.self).prefix(count))
        }

        // Add to buffer
        audioBuffer.append(contentsOf: floatArray)

        // Keep only last maxBufferDuration seconds
        let maxSamples = Int(maxBufferDuration * sampleRate)
        if audioBuffer.count > maxSamples {
            audioBuffer.removeFirst(audioBuffer.count - maxSamples)
        }

        do {
            let result = try await transcriptionService.transcribe(audioData)
            if !result.isEmpty {
                currentSubtitle = result

                // Cancel previous clear task if any
                subtitleClearTask?.cancel()

                // Schedule subtitle to clear after 10 seconds
                subtitleClearTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(10))
                    if !Task.isCancelled {
                        currentSubtitle = ""
                    }
                }
            }
        } catch {
            print("#debug ❌ Transcription error: \(error.localizedDescription)")
        }
    }

    func saveAudio() {
        guard !audioBuffer.isEmpty else {
            print("#debug ⚠️  No audio to save")
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.wav]
        savePanel.nameFieldStringValue = "captured_audio.wav"

        savePanel.begin { [weak self] response in
            guard let self = self,
                  response == .OK,
                  let url = savePanel.url else {
                return
            }

            Task { @MainActor in
                do {
                    try self.writeWAVFile(samples: self.audioBuffer, to: url)
                    print("#debug ✅ Audio saved to: \(url.path)")
                } catch {
                    print("#debug ❌ Failed to save audio: \(error.localizedDescription)")
                }
            }
        }
    }

    private func writeWAVFile(samples: [Float], to url: URL) throws {
        let sampleRate: Int32 = 16000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16

        // Convert Float samples to Int16
        let int16Samples = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * 32767.0)
        }

        // Create WAV header
        let dataSize = Int32(int16Samples.count * 2)
        let fileSize = dataSize + 36

        var header = Data()

        // RIFF chunk
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: Int32(16).littleEndian) { Data($0) }) // Subchunk1Size
        header.append(withUnsafeBytes(of: Int16(1).littleEndian) { Data($0) })  // AudioFormat (PCM)
        header.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: (sampleRate * Int32(numChannels) * Int32(bitsPerSample) / 8).littleEndian) { Data($0) }) // ByteRate
        header.append(withUnsafeBytes(of: (numChannels * bitsPerSample / 8).littleEndian) { Data($0) }) // BlockAlign
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        // Write header
        try header.write(to: url)

        // Append audio data
        let fileHandle = try FileHandle(forWritingTo: url)
        fileHandle.seekToEndOfFile()

        for sample in int16Samples {
            var sampleLE = sample.littleEndian
            let data = Data(bytes: &sampleLE, count: 2)
            fileHandle.write(data)
        }

        fileHandle.closeFile()
    }
}
