//
//  SubtitlesViewModel.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation
import SwiftUI

/// Main ViewModel that uses WhisperKit for both transcription and translation
@MainActor
class SubtitlesViewModel: ObservableObject {
    @Published var english: String = ""
    @Published var isRecording: Bool = false
    @Published var isModelLoading: Bool = true
    @Published var loadingProgress: Double = 0.0

    private var currentTextSegment = -1 // Track which segment is currently displayed on screen

    private var speechRecognition: SpeechRecognitionService!

    init() {
        // Initialize service with progress callback
        speechRecognition = SpeechRecognitionService { [weak self] progress in
            Task { @MainActor in
                self?.loadingProgress = progress
            }
        }

        // Monitor when the model is ready
        Task {
            while !speechRecognition.isReady {
                try? await Task.sleep(for: .seconds(0.5))
            }
            loadingProgress = 1.0
            isModelLoading = false
        }

        // Handle app lifecycle
        setupLifecycleObservers()
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App going to background - stop recording
            self?.stop()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App returning to foreground - restart recording if model is ready
            Task { @MainActor in
                if self?.speechRecognition.isReady == true && self?.isRecording == false {
                    self?.start()
                }
            }
        }
    }

    func start() {
        Task {
            // Wait for model to be ready before starting
            while !speechRecognition.isReady {
                try? await Task.sleep(for: .seconds(0.5))
            }

            // Start listening - translates audio to English
            let success = await speechRecognition.startListening { [weak self] englishText, segmentNumber in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Update current segment tracker
                    if self.currentTextSegment != segmentNumber {
                        print("🔄 Switching to segment #\(segmentNumber)")
                        self.currentTextSegment = segmentNumber
                    }

                    print("📝 Displaying: \(englishText)")
                    self.english = englishText
                }
            }

            if success {
                isRecording = true
            }
        }
    }

    func stop() {
        speechRecognition.stopListening()
        isRecording = false
        currentTextSegment = -1
    }
}
