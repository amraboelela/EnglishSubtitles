//
//  TranscriptionService.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/25/26.
//

import Foundation
import SwiftFasterWhisper

class TranscriptionService {
    private var whisper: WhisperContext?

    init() async throws {
        // Initialize SwiftFasterWhisper with base model for testing
        // You can change this to "medium" or "large-v2" later
        whisper = try await WhisperContext(modelName: "base")
    }

    func transcribe(_ audioData: Data) async throws -> String {
        guard let whisper = whisper else {
            throw NSError(domain: "Transcription", code: 1, userInfo: [NSLocalizedDescriptionKey: "Whisper not initialized"])
        }

        // Convert Data to Float array
        let floatArray = audioData.withUnsafeBytes { buffer -> [Float] in
            let count = buffer.count / MemoryLayout<Float>.size
            return Array(buffer.bindMemory(to: Float.self).prefix(count))
        }

        // Transcribe with SwiftFasterWhisper
        // The library handles VAD and segmentation internally
        let result = try await whisper.transcribe(audio: floatArray, language: "auto", task: .translate)

        // Combine all segments into a single string
        let text = result.segments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }
}
