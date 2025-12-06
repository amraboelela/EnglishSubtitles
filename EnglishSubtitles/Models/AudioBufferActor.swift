//
//  AudioBufferActor.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/4/25.
//

import Foundation

/// Actor that manages audio buffer state with thread safety (replaces GCD)
actor AudioBufferActor {
    // Audio buffer state
    private var audioBuffer: [Float] = []
    private var silenceStartTime: Double?
    private var hasReceivedSpeech = false
    private var segmentNumber = 0

    /// Append audio data and determine if a segment should be processed
    /// Handles audio accumulation logic with silence detection and segment limits
    /// - Returns: Tuple of (audioData, segmentNumber) if segment ready, nil otherwise
    func appendAudio(
        _ audioData: [Float],
        now: Double,
        rms: Float,
        sampleRate: Double,
        maxSegmentLimit: Double,
        silenceThreshold: Float,
        silenceDurationRequired: Double
    ) -> ([Float], Int)? {
        if rms >= silenceThreshold {
            hasReceivedSpeech = true
        }
        audioBuffer.append(contentsOf: audioData)

        let currentDuration = Double(audioBuffer.count) / sampleRate
        let minSamples = Int(sampleRate * 0.1) // 0.1 second minimum

        // Detect silence
        let isSilent = rms < silenceThreshold
        if isSilent {
            if silenceStartTime == nil {
                silenceStartTime = now
            }
        } else {
            silenceStartTime = nil
        }

        let silenceDuration = silenceStartTime != nil ? (now - silenceStartTime!) : 0

        let silenceHit = silenceDuration >= silenceDurationRequired
        let segmentLimitHit = currentDuration >= maxSegmentLimit // process at segment limit

        // Segment ready if silence break or reaching max segment limit
        if (silenceHit || segmentLimitHit) && audioBuffer.count >= minSamples && hasReceivedSpeech {
            print("🟢 Segment ready: \(audioBuffer.count) samples, \(String(format: "%.1f", currentDuration))s")
            return cutSegment()
        }

        // Discard silent buffer if limits hit and no speech
        if (silenceHit || segmentLimitHit) && audioBuffer.count >= minSamples && !hasReceivedSpeech {
            print("🗑️ Discarding silent buffer (\(audioBuffer.count) samples)")
            audioBuffer.removeAll(keepingCapacity: false)
            silenceStartTime = nil
        }

        return nil
    }

    /// Cut the current segment for processing
    private func cutSegment() -> ([Float], Int) {
        let audioToProcess = Array(audioBuffer)
        let currentSegment = segmentNumber

        // Clear buffer and reset state
        audioBuffer.removeAll(keepingCapacity: false)
        silenceStartTime = nil
        hasReceivedSpeech = false
        segmentNumber += 1

        return (audioToProcess, currentSegment)
    }

    /// Stop listening and reset all state
    func reset() {
        audioBuffer.removeAll(keepingCapacity: false)
        silenceStartTime = nil
        hasReceivedSpeech = false
        segmentNumber = 0
    }
}
