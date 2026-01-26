//
//  SubtitlesViewModel.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/25/26.
//

import Foundation
import SwiftUI
import Combine

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

            // Initialize services
            audioService = ScreenAudioCaptureService()

            // Set up transcription callback
            audioService?.onAudioData = { [weak self] audioData in
                await self?.processAudio(audioData)
            }

            // Start capturing
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
        isCapturing = false
        currentSubtitle = "Stopped"
    }

    private func processAudio(_ audioData: Data) async {
        guard let transcriptionService = transcriptionService else { return }

        print("#DEBUG 🔄 Processing \(audioData.count) bytes of audio")

        do {
            let result = try await transcriptionService.transcribe(audioData)
            print("#DEBUG 📝 Transcription result: '\(result)' (length: \(result.count))")
            if !result.isEmpty {
                print("#DEBUG ✅ Updating subtitle to: '\(result)'")
                currentSubtitle = result
            } else {
                print("#DEBUG ⚠️  Empty transcription result")
            }
        } catch {
            print("#DEBUG ❌ Transcription error: \(error.localizedDescription)")
        }
    }
}
