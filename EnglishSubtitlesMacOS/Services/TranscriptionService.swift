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

    init(progressCallback: DownloadProgressCallback? = nil) async throws {
        print("#DEBUG Initializing TranscriptionService...")

        // Get or download model to app's directory
        // SwiftFasterWhisper automatically detects app name from Bundle.main
        let modelURL = try await ModelFileManager.ensureWhisperModel(
            size: .medium,
            progressCallback: progressCallback
        )

        print("#DEBUG Using model at: \(modelURL.path)")

        do {
            // Initialize streaming recognizer
            recognizer = StreamingRecognizer(modelPath: modelURL.path)
            print("#DEBUG Configuring recognizer...")
            try await recognizer?.configure(language: "en", task: "translate")
            print("#DEBUG TranscriptionService initialized successfully with medium model")
        } catch {
            print("#DEBUG TranscriptionService initialization failed: \(error.localizedDescription)")
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

        if !text.isEmpty {
            print("#DEBUG ✅ Got transcription: '\(text)'")
        }

        return text
    }

    func stop() async {
        await recognizer?.stop()
        recognizer = nil
    }
}
