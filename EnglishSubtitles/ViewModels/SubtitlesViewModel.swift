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

    private func setupLifecycleObservers() {
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

            // Start listening - translates audio to English
            let success = await speechRecognition.startListening { [weak self] englishText, segmentNumber in
                Task { @MainActor in
                    guard let self = self else { return }

                    // If this is a different segment than what's currently displayed, update segment number
                    // but DON'T clear the text - keep previous translation visible until new one arrives
                    if self.currentTextSegment != segmentNumber {
                        print("🔄 Switching from segment #\(self.currentTextSegment) to #\(segmentNumber)")
                        self.currentTextSegment = segmentNumber
                        // Don't clear english text - keep previous translation visible
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
