//
//  SubtitlesViewModel.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation

/// Main ViewModel that uses WhisperKit for both transcription and translation
@MainActor
class SubtitlesViewModel: ObservableObject {
    @Published var original: String = ""
    @Published var english: String = ""
    @Published var isRecording: Bool = false
    @Published var isModelLoading: Bool = true

    private let speechRecognition = SpeechRecognitionService()

    init() {
        // Monitor when the model is ready
        Task {
            while !speechRecognition.isReady {
                try? await Task.sleep(for: .seconds(0.5))
            }
            isModelLoading = false
        }
    }

    func start() {
        Task {
            // Wait for model to be ready before starting
            while !speechRecognition.isReady {
                try? await Task.sleep(for: .seconds(0.5))
            }

            // Start both transcription (.transcribe task) and translation (.translate task)
            async let transcribeSuccess = speechRecognition.startTranscribing { [weak self] text in
                Task { @MainActor in
                    self?.original = text
                }
            }

            async let translateSuccess = speechRecognition.startTranslating { [weak self] englishText in
                Task { @MainActor in
                    self?.english = englishText
                }
            }

            let (transcribed, translated) = await (transcribeSuccess, translateSuccess)

            if transcribed && translated {
                isRecording = true
            }
        }
    }

    func stop() {
        speechRecognition.stopTranscribing()
        isRecording = false
    }
}
