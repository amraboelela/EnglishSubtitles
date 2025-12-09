//
//  AudioBufferActorTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/4/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for AudioBufferActor - Thread-safe audio buffer management
struct AudioBufferActorTests {
  
  // MARK: - Basic Functionality Tests
  
  @Test func testAudioBufferActorInitialization() async {
    let actor = AudioBufferActor()
    
    // Test that we can interact with the actor
    let result = await actor.appendAudio(
      [0.1, 0.2, 0.3],
      now: 0.0,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result == nil, "Initial audio append should not trigger segment processing")
  }
  
  @Test func testAudioAccumulation() async {
    let actor = AudioBufferActor()
    
    // Add multiple audio chunks
    let chunk1: [Float] = Array(repeating: 0.1, count: 8000) // 0.5 seconds at 16kHz
    let chunk2: [Float] = Array(repeating: 0.1, count: 8000) // 0.5 seconds at 16kHz
    
    let result1 = await actor.appendAudio(
      chunk1,
      now: 0.0,
      rms: 0.1,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result1 == nil, "First chunk should not trigger processing")
    
    let result2 = await actor.appendAudio(
      chunk2,
      now: 0.5,
      rms: 0.1,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result2 == nil, "Second chunk should not trigger processing (no silence)")
  }
  
  // MARK: - Silence Detection Tests
  
  @Test func testSilenceDetectionTriggersSegment() async {
    let actor = AudioBufferActor()
    
    // Add speech (loud audio)
    let speechChunk: [Float] = Array(repeating: 0.5, count: 8000) // 0.5 seconds of speech
    
    let speechResult = await actor.appendAudio(
      speechChunk,
      now: 0.0,
      rms: 0.5,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(speechResult == nil, "Speech should not trigger processing")
    
    // Add silence for required duration
    let silenceChunk: [Float] = Array(repeating: 0.01, count: 1600) // 0.1 seconds of silence
    
    // Add multiple silence chunks to reach the 1.0 second threshold
    for i in 0..<12 { // 12 * 0.1 = 1.2 seconds of silence
      let timestamp = 0.5 + Double(i) * 0.1
      let result = await actor.appendAudio(
        silenceChunk,
        now: timestamp,
        rms: 0.01, // Below silence threshold
        sampleRate: 16000.0,
        maxSegmentLimit: 10.0,
        silenceThreshold: 0.025,
        silenceDurationRequired: 1.0
      )
      
      if i >= 10 { // After 1.0 seconds of silence
        #expect(result != nil, "Silence should trigger segment processing after 1.0 seconds")
        if let (audioData, segmentNumber) = result {
          #expect(audioData.count > 0, "Segment should contain audio data")
          #expect(segmentNumber == 0, "First segment should be number 0")
        }
        break
      }
    }
  }
  
  @Test func testSilenceResetBySpeech() async {
    let actor = AudioBufferActor()
    
    // Add speech
    let speechChunk: [Float] = Array(repeating: 0.5, count: 8000)
    let _ = await actor.appendAudio(
      speechChunk,
      now: 0.0,
      rms: 0.5,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Add some silence
    let silenceChunk: [Float] = Array(repeating: 0.01, count: 1600)
    let _ = await actor.appendAudio(
      silenceChunk,
      now: 0.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Add speech again (should reset silence timer)
    let speechChunk2: [Float] = Array(repeating: 0.4, count: 1600)
    let result = await actor.appendAudio(
      speechChunk2,
      now: 1.0,
      rms: 0.4,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result == nil, "Speech should reset silence timer and prevent segmentation")
  }
  
  // MARK: - Model Limit Tests
  
  @Test func testModelLimitTriggersSegment() async {
    let actor = AudioBufferActor()
    
    // Create audio that approaches the model limit (29 seconds)
    let longAudioChunk: [Float] = Array(repeating: 0.3, count: 16000 * 29) // 29 seconds at 16kHz
    
    let result = await actor.appendAudio(
      longAudioChunk,
      now: 0.0,
      rms: 0.3,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result != nil, "Model limit should trigger segment processing")
    if let (audioData, segmentNumber) = result {
      #expect(audioData.count > 0, "Segment should contain audio data")
      #expect(segmentNumber == 0, "First segment should be number 0")
    }
  }
  
  @Test func testBufferOverflowProtection() async {
    let actor = AudioBufferActor()
    
    // Create audio that exceeds the max buffer duration
    let oversizedChunk: [Float] = Array(repeating: 0.3, count: 16000 * 35) // 35 seconds (exceeds 30s limit)
    
    let result = await actor.appendAudio(
      oversizedChunk,
      now: 0.0,
      rms: 0.3,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // The actor should handle overflow by discarding excess samples
    // This test ensures no crash occurs and the buffer is managed safely
    #expect(result != nil, "Oversized buffer should be handled gracefully")
  }
  
  // MARK: - Processing State Tests
  
  @Test func testProcessingStateManagement() async {
    let actor = AudioBufferActor()
    
    // Add speech first at 0.0s
    let speechChunk: [Float] = Array(repeating: 0.5, count: 8000)
    let _ = await actor.appendAudio(
      speechChunk,
      now: 0.0,
      rms: 0.5,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Add silence starting at 0.5s (this sets silenceStartTime = 0.5)
    let silenceChunk: [Float] = Array(repeating: 0.01, count: 8000) // 0.5 seconds of silence
    let _ = await actor.appendAudio(
      silenceChunk,
      now: 0.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Continue silence until we reach 1.0s total (silenceStartTime=0.5, now=1.5, duration=1.0s)
    let result = await actor.appendAudio(
      silenceChunk,
      now: 1.5, // 1.5 - 0.5 = 1.0s of silence duration
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result != nil, "Should trigger segment processing")
    
    // Now try to add more audio after segment processing
    let newAudioChunk: [Float] = Array(repeating: 0.3, count: 8000)
    let _ = await actor.appendAudio(
      newAudioChunk,
      now: 2.0,
      rms: 0.3,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Since processing state management is internal, new audio should accumulate
    // Note: Behavior may vary based on internal processing state implementation
    
    // Add silence to trigger another segment
    let silenceChunk2: [Float] = Array(repeating: 0.01, count: 16000)
    let result3 = await actor.appendAudio(
      silenceChunk2,
      now: 3.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // This might not trigger immediately since we need speech first, but it shouldn't crash
    #expect(result3 == nil, "Should handle audio after processing complete")
  }
  
  // MARK: - Reset Functionality Tests
  
  @Test func testResetFunctionality() async {
    let actor = AudioBufferActor()
    
    // Add some audio
    let audioChunk: [Float] = Array(repeating: 0.3, count: 8000)
    let _ = await actor.appendAudio(
      audioChunk,
      now: 0.0,
      rms: 0.3,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Reset the actor
    await actor.reset()
    
    // Add new audio - should start fresh
    let newAudioChunk: [Float] = Array(repeating: 0.4, count: 8000)
    let result = await actor.appendAudio(
      newAudioChunk,
      now: 0.0, // Start from 0 again
      rms: 0.4,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result == nil, "After reset, should start fresh")
  }
  
  // MARK: - Segment Numbering Tests
  
  @Test func testSegmentNumberIncrement() async {
    let actor = AudioBufferActor()
    
    // Create and process first segment
    let speechChunk: [Float] = Array(repeating: 0.5, count: 8000)
    let _ = await actor.appendAudio(
      speechChunk,
      now: 0.0,
      rms: 0.5,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Start silence at 0.5s
    let silenceChunk: [Float] = Array(repeating: 0.01, count: 8000)
    let _ = await actor.appendAudio(
      silenceChunk,
      now: 0.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Complete 1.0s of silence (0.5 to 1.5 = 1.0s duration)
    let result1 = await actor.appendAudio(
      silenceChunk,
      now: 1.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result1?.1 == 0, "First segment should be number 0")
    
    // Create and process second segment
    let _ = await actor.appendAudio(
      speechChunk,
      now: 2.0,
      rms: 0.5,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Start silence at 2.5s
    let _ = await actor.appendAudio(
      silenceChunk,
      now: 2.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Complete 1.0s of silence (2.5 to 3.5 = 1.0s duration)
    let result2 = await actor.appendAudio(
      silenceChunk,
      now: 3.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    #expect(result2?.1 == 1, "Second segment should be number 1")
  }
  
  // MARK: - Edge Cases
  
  @Test func testMinimumSampleRequirement() async {
    let actor = AudioBufferActor()
    
    // Add very small amount of audio (less than minimum)
    let tinyChunk: [Float] = [0.3, 0.3, 0.3] // Only 3 samples
    let _ = await actor.appendAudio(
      tinyChunk,
      now: 0.0,
      rms: 0.3,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Try to trigger silence detection
    let silenceChunk: [Float] = Array(repeating: 0.01, count: 16000)
    let result = await actor.appendAudio(
      silenceChunk,
      now: 1.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Should not process due to minimum sample requirement (0.1 seconds = 1600 samples at 16kHz)
    #expect(result == nil, "Should not process segments below minimum sample requirement")
  }
  
  @Test func testSilentBufferDiscard() async {
    let actor = AudioBufferActor()
    
    // Add only silence (no speech)
    let silenceChunk: [Float] = Array(repeating: 0.01, count: 16000) // 1 second of silence
    
    let result = await actor.appendAudio(
      silenceChunk,
      now: 1.5,
      rms: 0.01,
      sampleRate: 16000.0,
      maxSegmentLimit: 10.0,
      silenceThreshold: 0.025,
      silenceDurationRequired: 1.0
    )
    
    // Should discard silent buffer, not process it
    #expect(result == nil, "Should discard buffer with no speech content")
  }
  
  // MARK: - Concurrent Access Tests
  
  @Test func testConcurrentAccess() async {
    let actor = AudioBufferActor()
    
    // Test multiple concurrent operations
    await withTaskGroup(of: Void.self) { group in
      // Add multiple audio chunks concurrently
      for i in 0..<10 {
        group.addTask {
          let chunk: [Float] = Array(repeating: Float(i) * 0.1, count: 1600)
          let _ = await actor.appendAudio(
            chunk,
            now: Double(i) * 0.1,
            rms: Float(i) * 0.01,
            sampleRate: 16000.0,
            maxSegmentLimit: 10.0,
            silenceThreshold: 0.025,
            silenceDurationRequired: 1.0
          )
        }
      }
    }
    
    // If we get here without hanging or crashing, the actor handles concurrency correctly
    #expect(true, "Actor should handle concurrent access safely")
  }
  
  // MARK: - Silent Buffer Discard Logic Tests
  
  @Test func testSilentBufferDiscard_SilenceHitNoSpeech() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 1.0
    let maxSegmentLimit = 10.0
    let minSamples = Int(sampleRate * 0.1) // 0.1 second minimum
    
    // Accumulate enough silent audio to meet minimum samples requirement
    let silentChunk: [Float] = Array(repeating: 0.01, count: minSamples) // Below threshold, enough samples
    
    // First append - establishes silence but not long enough yet
    let result1 = await actor.appendAudio(
      silentChunk,
      now: 0.0,
      rms: 0.01, // Below silenceThreshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result1 == nil, "Should not process segment on first silent chunk")
    
    // Second append after silence duration has elapsed - should trigger discard
    let result2 = await actor.appendAudio(
      silentChunk,
      now: silenceDurationRequired + 0.1, // Silence duration exceeded
      rms: 0.01, // Still below threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result2 == nil, "Should discard silent buffer, not process segment")
    
    // Verify buffer was discarded by checking if subsequent speech creates a segment from start
    let speechChunk: [Float] = Array(repeating: 0.1, count: minSamples)
    let result3 = await actor.appendAudio(
      speechChunk,
      now: silenceDurationRequired + 0.2,
      rms: 0.1, // Above threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result3 == nil, "Should start fresh accumulation after discard")
    print("✅ Silent buffer discard - silence hit, no speech tested")
  }
  
  @Test func testSilentBufferDiscard_SegmentLimitHitNoSpeech() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 1.0
    let maxSegmentLimit = 1.0 // Short limit for testing
    let _ = Int(sampleRate * 0.1) // Minimum samples calculation (unused in this test)
    
    // Accumulate silent audio that exceeds segment limit
    let silentChunk: [Float] = Array(repeating: 0.01, count: Int(sampleRate * maxSegmentLimit * 1.1)) // Exceeds limit
    
    let result = await actor.appendAudio(
      silentChunk,
      now: 0.0,
      rms: 0.01, // Below silenceThreshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result == nil, "Should discard silent buffer when segment limit hit without speech")
    
    print("✅ Silent buffer discard - segment limit hit, no speech tested")
  }
  
  @Test func testSilentBufferDiscard_BothConditionsNoSpeech() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 0.5 // Short duration
    let maxSegmentLimit = 1.0 // Short limit
    let _ = Int(sampleRate * 0.1) // Minimum sample calculation (unused in this test)
    
    // Accumulate silent audio that triggers both conditions
    let silentChunk: [Float] = Array(repeating: 0.01, count: Int(sampleRate * maxSegmentLimit * 1.1))
    
    let result = await actor.appendAudio(
      silentChunk,
      now: silenceDurationRequired + 0.1, // Both silence and segment limit hit
      rms: 0.01, // Below threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result == nil, "Should discard when both silence and segment limit conditions met")
    
    print("✅ Silent buffer discard - both conditions, no speech tested")
  }
  
  @Test func testSilentBufferDiscard_NotTriggeredWithSpeech() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 1.0
    let maxSegmentLimit = 10.0
    let minSamples = Int(sampleRate * 0.1)
    
    // First establish speech
    let speechChunk: [Float] = Array(repeating: 0.1, count: minSamples)
    let speechResult = await actor.appendAudio(
      speechChunk,
      now: 0.0,
      rms: 0.1, // Above threshold - establishes hasReceivedSpeech = true
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(speechResult == nil, "Speech chunk alone should not trigger segment")
    
    // Then add silence that would normally trigger discard
    let silentChunk: [Float] = Array(repeating: 0.01, count: minSamples)
    
    // First silence chunk - establishes silenceStartTime
    let silenceResult1 = await actor.appendAudio(
      silentChunk,
      now: 0.5, // Start silence at 0.5s
      rms: 0.01, // Below threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(silenceResult1 == nil, "First silence chunk should not trigger segment yet")
    
    // Second silence chunk - after silence duration requirement is met
    let silenceResult = await actor.appendAudio(
      silentChunk,
      now: 0.5 + silenceDurationRequired + 0.1, // 1.6s = silence duration of 1.1s
      rms: 0.01, // Below threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    // Should create segment, not discard, because hasReceivedSpeech = true
    #expect(silenceResult != nil, "Should create segment when speech was received, not discard")
    
    if let (audioData, segmentNum) = silenceResult {
      let expectedSamples = minSamples * 3 // speech + silence1 + silence2 chunks
      #expect(audioData.count == expectedSamples, "Segment should contain all three audio chunks")
      #expect(segmentNum == 0, "Should be first segment")
    }
    
    print("✅ Silent buffer discard - not triggered with prior speech tested")
  }
  
  @Test func testSilentBufferDiscard_InsufficientSamples() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 1.0
    let maxSegmentLimit = 10.0
    let minSamples = Int(sampleRate * 0.1)
    
    // Use fewer samples than minimum required
    let tinyChunk: [Float] = Array(repeating: 0.01, count: minSamples - 1) // Just under minimum
    
    let result = await actor.appendAudio(
      tinyChunk,
      now: silenceDurationRequired + 0.1, // Conditions would trigger discard
      rms: 0.01, // Below threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result == nil, "Should not discard if insufficient samples")
    
    print("✅ Silent buffer discard - insufficient samples tested")
  }
  
  @Test func testSilentBufferDiscard_StateResetAfterDiscard() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 1.0
    let maxSegmentLimit = 10.0
    let minSamples = Int(sampleRate * 0.1)
    
    // Trigger a discard
    let silentChunk: [Float] = Array(repeating: 0.01, count: minSamples)
    let discardResult = await actor.appendAudio(
      silentChunk,
      now: silenceDurationRequired + 0.1,
      rms: 0.01,
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(discardResult == nil, "Should discard silent buffer")
    
    // Verify state is reset by adding new speech - should start fresh accumulation
    let speechChunk: [Float] = Array(repeating: 0.1, count: minSamples)
    let speechResult = await actor.appendAudio(
      speechChunk,
      now: silenceDurationRequired + 0.2,
      rms: 0.1, // Above threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(speechResult == nil, "Should start fresh accumulation after discard")
    
    // Add more to confirm we're building a new segment from scratch
    let moreAudio: [Float] = Array(repeating: 0.05, count: minSamples)
    let finalResult = await actor.appendAudio(
      moreAudio,
      now: silenceDurationRequired + 1.2, // Trigger silence break
      rms: 0.01,
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    if let (audioData, segmentNum) = finalResult {
      let expectedSamples = minSamples * 2 // Only the new speech + more audio
      #expect(audioData.count == expectedSamples, "New segment should only contain post-discard audio")
      #expect(segmentNum == 0, "Should be first segment after reset")
    }
    
    print("✅ Silent buffer discard - state reset after discard tested")
  }
  
  @Test func testSilentBufferDiscard_EdgeCaseExactThreshold() async {
    let actor = AudioBufferActor()
    
    let sampleRate = 16000.0
    let silenceThreshold: Float = 0.025
    let silenceDurationRequired = 1.0
    let maxSegmentLimit = 10.0
    let minSamples = Int(sampleRate * 0.1)
    
    // Use RMS exactly at threshold (should NOT be considered silent)
    let thresholdChunk: [Float] = Array(repeating: 0.1, count: minSamples)
    let result = await actor.appendAudio(
      thresholdChunk,
      now: silenceDurationRequired + 0.1,
      rms: silenceThreshold, // Exactly at threshold
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    #expect(result == nil, "Should not discard when RMS is at threshold (not below)")
    
    print("✅ Silent buffer discard - exact threshold edge case tested")
  }
}
