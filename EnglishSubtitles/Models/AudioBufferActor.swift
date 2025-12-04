//
//  AudioBufferActor.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/4/25.
//

import Foundation

/// Actor that manages audio buffer state with thread safety (replaces GCD)
actor AudioBufferActor {
    // Audio buffer state (previously managed by GCD serial queue)
    private var audioBuffer: [Float] = []
    private var isProcessing = false
    private var silenceStartTime: Double?
    private var hasReceivedSpeech = false
    private var segmentNumber = 0

    /// Append audio data and determine if segment should be processed
    /// Handles audio accumulation logic with silence detection and buffer limits
    /// - Returns: Tuple of (audioData, segmentNumber) if segment ready, nil otherwise
    func appendAudio(
        _ audioData: [Float],
        now: Double,
        rms: Float,
        sampleRate: Double,
        maxBufferDuration: Double,
        silenceThreshold: Float,
        silenceDurationRequired: Double
    ) -> ([Float], Int)? {

        // Accumulate samples
        audioBuffer.append(contentsOf: audioData)

        let currentDuration = Double(audioBuffer.count) / sampleRate

        // Hard buffer limit: force processing when approaching WhisperKit's 30-second limit
        if currentDuration > maxBufferDuration {
            let maxSamples = Int(maxBufferDuration * sampleRate)
            let excessSamples = audioBuffer.count - maxSamples
            print("⚠️ Approaching WhisperKit 30s limit: \(String(format: "%.1f", currentDuration))s - discarding \(excessSamples) samples")
            audioBuffer.removeFirst(excessSamples)
        }

        // Detect silence
        let isSilent = rms < silenceThreshold

        if isSilent {
            // Start silence timer if not already started
            if silenceStartTime == nil {
                silenceStartTime = now
            }
        } else {
            // Reset silence timer when we hear sound
            silenceStartTime = nil
            hasReceivedSpeech = true
        }

        // Calculate how long we've been silent
        let silenceDuration = silenceStartTime != nil ? (now - silenceStartTime!) : 0

        // Check if we should end the segment
        let silenceHit = silenceDuration >= silenceDurationRequired
        let modelLimitHit = currentDuration >= (maxBufferDuration - 1.0) // Process 1 second before limit

        // Minimum samples to prevent processing noise (0.1 seconds)
        let minSamples = Int(sampleRate * 0.1)

        // Process segment on natural silence break
        if silenceHit && audioBuffer.count >= minSamples && hasReceivedSpeech && !isProcessing {
            print("🔇 Silence detected (\(String(format: "%.1f", silenceDuration))s) - processing segment #\(segmentNumber) (\(audioBuffer.count) samples, \(String(format: "%.1f", currentDuration))s)")
            return cutSegment()
        }

        // OR force processing when approaching WhisperKit model limit (29 seconds)
        if modelLimitHit && !audioBuffer.isEmpty && hasReceivedSpeech && !isProcessing {
            print("⏰ WhisperKit limit approaching (\(String(format: "%.1f", currentDuration))s) - forcing segment #\(segmentNumber) (\(audioBuffer.count) samples)")
            return cutSegment()
        }

        // No speech received - discard silent buffer if we hit limits
        if (silenceHit || modelLimitHit) && !audioBuffer.isEmpty && !hasReceivedSpeech {
            print("🗑️ Discarding silent buffer (\(audioBuffer.count) samples)")
            audioBuffer.removeAll(keepingCapacity: false)
            silenceStartTime = nil
        }

        return nil
    }

    /// Cut the current segment for processing
    /// Extracts the current audio buffer and resets state for the next segment
    /// - Returns: Tuple of audio data and segment number
    private func cutSegment() -> ([Float], Int) {
        isProcessing = true

        // Copy buffer for processing and immediately release memory
        let audioToProcess = Array(audioBuffer)
        let currentSegment = segmentNumber

        // Clear buffer and reset state - RELEASE MEMORY IMMEDIATELY
        audioBuffer.removeAll(keepingCapacity: false)
        silenceStartTime = nil
        hasReceivedSpeech = false
        segmentNumber += 1

        return (audioToProcess, currentSegment)
    }

    /// Mark processing as complete, allowing next segment to be processed
    /// Called after WhisperKit finishes processing a segment
    func markProcessingComplete() {
        isProcessing = false
    }

    /// Stop listening and reset all state
    /// Called when stopping the listening session
    func reset() {
        audioBuffer.removeAll(keepingCapacity: false)
        isProcessing = false
        silenceStartTime = nil
        hasReceivedSpeech = false
        segmentNumber = 0
    }
}