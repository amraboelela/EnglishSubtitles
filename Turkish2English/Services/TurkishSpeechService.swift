//
//  TurkishSpeechService.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/11/25.
//

import Foundation
import Speech
import AVFoundation
import os.log

/// Service that handles Turkish speech-to-text using SFSpeechRecognizer
/// Then uses M2M100 model for Turkish-to-English translation
@MainActor
class TurkishSpeechService: NSObject, ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Translation service
    private var translationService: AppleTranslationService

    // Callbacks
    private var turkishCallback: ((String, Int) -> Void)?
    private var englishCallback: ((String, Int) -> Void)?

    // Segment management
    private var segmentCounter = 0
    private var currentTurkishText = ""

    override init() {
        // Initialize translation service first
        translationService = AppleTranslationService()

        super.init()

        // Initialize Turkish speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
        speechRecognizer?.delegate = self

        print("✅ Initialized Apple Translation service")

        // Prepare translation model in background
//        Task {
//            await translationService.prepareTranslation()
//        }
    }

    /// Request speech recognition authorization
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
    }

    /// Start listening for Turkish speech and translate to English
    func startListening(
        onTurkishUpdate: @escaping (String, Int) -> Void,
        onEnglishUpdate: @escaping (String, Int) -> Void
    ) async -> Bool {
        // Check authorization
        guard await requestAuthorization() else {
            print("Speech recognition not authorized")
            return false
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return false
        }

        // Store callbacks
        self.turkishCallback = onTurkishUpdate
        self.englishCallback = onEnglishUpdate

        do {
            try await startRecording()
            return true
        } catch {
            print("Failed to start recording: \(error)")
            return false
        }
    }

    private func startRecording() async throws {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Stop audio engine and remove any existing taps
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionRequestFailed
        }

        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Use server-based recognition for better Turkish support

        // Get audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node (after removing any existing ones)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Prepare audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    let turkishText = result.bestTranscription.formattedString

                    // Update Turkish text
                    self.currentTurkishText = turkishText
                    self.turkishCallback?(turkishText, self.segmentCounter)

                    // If this is a final result, translate it
                    if result.isFinal {
                        await self.translateToEnglish(turkishText)
                        self.segmentCounter += 1

                        // Start a new recognition request for continuous listening
                        try? await self.restartRecognition()
                    }
                }

                if let error = error {
                    print("Recognition error: \(error)")
                    // Try to restart recognition
                    try? await self.restartRecognition()
                }
            }
        }
    }

    private func restartRecognition() async throws {
        // Stop current recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()

        // Small delay before restarting
        try await Task.sleep(for: .milliseconds(100))

        // Start new recognition
        try await startRecording()
    }

    private func translateToEnglish(_ turkishText: String) async {
        do {
            let englishText = try await translationService.translate(text: turkishText)
            // Update English text
            englishCallback?(englishText, segmentCounter)
        } catch {
            print("Translation error: \(error)")
            // Fallback: just use the Turkish text
            englishCallback?(turkishText, segmentCounter)
        }
    }

    /// Check if translation is available
//    func isTranslationAvailable() async -> Bool {
//        return await translationService.isTranslationAvailable()
//    }

    /// Prepare translation service (download models if needed)
//    func prepareTranslation() async {
//        await translationService.prepareTranslation()
//    }

    /// Stop listening and clean up
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        segmentCounter = 0
        currentTurkishText = ""
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension TurkishSpeechService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("Speech recognizer availability changed: \(available)")
    }
}

// MARK: - Error Types

enum SpeechError: Error {
    case recognitionRequestFailed
    case audioEngineFailed
    case recognitionFailed
}
