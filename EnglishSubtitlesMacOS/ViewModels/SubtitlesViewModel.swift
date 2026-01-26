//
//  SubtitlesViewModel.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/25/26.
//

import Foundation
import SwiftUI

@MainActor
class SubtitlesViewModel: ObservableObject {
    @Published var currentSubtitle: String = "Waiting for audio..."
    @Published var isCapturing: Bool = false
    @Published var errorMessage: String?

    private var audioService: ScreenAudioCaptureService?
    private var transcriptionService: TranscriptionService?

    func startCapture() async {
        isCapturing = true
        errorMessage = nil
        currentSubtitle = "Initializing..."

        do {
            // Initialize services
            transcriptionService = try await TranscriptionService()
            audioService = try await ScreenAudioCaptureService()

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
        }
    }

    func stopCapture() {
        audioService?.stopCapture()
        audioService = nil
        transcriptionService = nil
        isCapturing = false
        currentSubtitle = "Stopped"
    }

    private func processAudio(_ audioData: Data) async {
        guard let transcriptionService = transcriptionService else { return }

        do {
            let result = try await transcriptionService.transcribe(audioData)
            if !result.isEmpty {
                currentSubtitle = result
            }
        } catch {
            print("Transcription error: \(error)")
        }
    }
}
