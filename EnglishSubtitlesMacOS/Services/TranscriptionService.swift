//
//  TranscriptionService.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/25/26.
//

import Foundation
import SwiftFasterWhisper

class TranscriptionService {
    private var recognizer: StreamingRecognizer?

    // Common Whisper hallucinations to filter out
    private let hallucinations: Set<String> = [
        "you", "thank you", "thanks for watching",
        "bye", "goodbye", "the", "a", "an",
        "uh", "um", "hmm", "mm", "ah"
    ]

    init(progressCallback: DownloadProgressCallback? = nil) async throws {
        print("#debug Initializing TranscriptionService...")

        // Get or download model to app's directory
        // SwiftFasterWhisper automatically detects app name from Bundle.main
        let modelURL = try await ModelFileManager.ensureWhisperModel(
            size: .medium,
            progressCallback: progressCallback
        )

        print("#debug Using model at: \(modelURL.path)")

        do {
            // Initialize streaming recognizer
            recognizer = StreamingRecognizer(modelPath: modelURL.path)
            print("#debug Configuring recognizer...")
            // Auto-detect language and translate to English
            try await recognizer?.configure(language: nil, task: "translate")
            print("#debug TranscriptionService initialized successfully with medium model (auto-detect language)")
        } catch {
            print("#debug TranscriptionService initialization failed: \(error.localizedDescription)")
            throw NSError(
                domain: "TranscriptionService",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to initialize: \(error.localizedDescription)"
                ]
            )
        }
    }

    func transcribe(_ audioData: Data) async throws -> String {
        guard let recognizer = recognizer else {
            throw NSError(domain: "Transcription", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recognizer not initialized"])
        }

        // Convert Data to Float array
        let floatArray = audioData.withUnsafeBytes { buffer -> [Float] in
            let count = buffer.count / MemoryLayout<Float>.size
            return Array(buffer.bindMemory(to: Float.self).prefix(count))
        }

        // Feed audio chunk and get text immediately
        let text = await recognizer.addAudioChunk(floatArray)

        // Filter out hallucinations
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hallucinations.contains(trimmed) {
            return ""  // Skip hallucination
        }

        if !text.isEmpty {
            print("#debug ✅ Got transcription: '\(text)'")
        }

        return text
    }

    func stop() async {
        await recognizer?.stop()
        recognizer = nil
    }
}
