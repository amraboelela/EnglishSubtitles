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
    @Published var originalText: String = "" // Free transcription in original language
    @Published var englishText: String = "" // Paid translation to English
    @Published var isRecording: Bool = false
    @Published var isModelLoading: Bool = true
    @Published var loadingProgress: Double = 0.0

    private var currentTextSegment = -1 // Track which segment is currently displayed on screen
    private let purchaseManager = TranslationPurchaseManager.shared

    private var speechRecognition: SpeechRecognitionService!

    init() {
        // Initialize service WITHOUT loading model yet
        speechRecognition = SpeechRecognitionService { [weak self] progress in
            Task { @MainActor in
                self?.loadingProgress = progress
            }
        }

        // Handle app lifecycle
        setupLifecycleObservers()
    }

    /// Load the model - should be called AFTER UI appears
    func loadModel() async {
        // Wait for model to load
        await self.speechRecognition.loadModel()

        // Monitor when the model is ready
        while !(await self.speechRecognition.isReady) {
            try? await Task.sleep(for: .seconds(0.5))
        }

        self.loadingProgress = 1.0
        self.isModelLoading = false
    }

    func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App going to background - unload model to free memory
            Task { @MainActor in
                self?.unloadModel()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App returning to foreground - reload and restart
            Task { @MainActor in
                guard let self else { return }
                await self.loadModel()
                if !self.isModelLoading {
                    self.start()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App terminating - unload model to clean up
            Task { @MainActor in
                self?.unloadModel()
            }
        }
    }

    func start() {
        Task {
            // Wait for model to be ready before starting
            while !(await speechRecognition.isReady) {
                try? await Task.sleep(for: .seconds(0.5))
            }

            // Choose transcription or translation based on IAP status
            let useTranslation = purchaseManager.canUseTranslation
            let success = await speechRecognition.startListening(
                transcribeOnly: !useTranslation,
                onUpdate: { [weak self] text, segmentNumber in
                    Task { @MainActor in
                        guard let self = self else { return }

                        if self.currentTextSegment != segmentNumber {
                            print("🔄 Switching from segment #\(self.currentTextSegment) to #\(segmentNumber)")
                            self.currentTextSegment = segmentNumber
                        }

                        if useTranslation {
                            // User has translation access, use English text
                            print("📝 Translation: \(text)")
                            self.englishText = text
                            self.originalText = "" // Clear transcription when using translation
                        } else {
                            // User only has transcription access, use original language
                            print("📝 Transcription: \(text)")
                            self.originalText = text
                            self.englishText = "" // Clear translation when using transcription
                        }
                    }
                }
            )

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

    /// Unload model to free memory - call when view disappears
    func unloadModel() {
        stop()
        Task {
            await speechRecognition.unloadModel()
        }
        isModelLoading = true
        loadingProgress = 0.0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
