//
//  AudioStreamManagerTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/1/25.
//

import Testing
import Foundation
import AVFoundation
@testable import EnglishSubtitles

/// Tests for AudioStreamManager - Audio capture and processing utilities
struct AudioStreamManagerTests {
  
  // MARK: - Audio Processing Utility Tests
  
  @Test func testResampleIfNeeded_AlreadySixteenKHz() async throws {
    // Create a 16kHz buffer
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 16000,
                                     channels: 1,
                                     interleaved: false) else {
      Issue.record("Failed to create audio format")
      return
    }
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
      Issue.record("Failed to create audio buffer")
      return
    }
    
    buffer.frameLength = 1024
    
    // Resample (should return same buffer since already 16kHz)
    let resampled = AudioStreamManager.resampleIfNeeded(buffer)
    
    #expect(resampled.format.sampleRate == 16000, "Should remain at 16kHz")
    #expect(resampled.frameLength == buffer.frameLength, "Frame length should be unchanged")
  }
  
  @Test func testResampleIfNeeded_FortyEightKHz() async throws {
    // Create a 48kHz buffer (common microphone sample rate)
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 48000,
                                     channels: 1,
                                     interleaved: false) else {
      Issue.record("Failed to create audio format")
      return
    }
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800) else {
      Issue.record("Failed to create audio buffer")
      return
    }
    
    buffer.frameLength = 4800 // 0.1 seconds at 48kHz
    
    // Resample to 16kHz
    let resampled = AudioStreamManager.resampleIfNeeded(buffer)
    
    #expect(resampled.format.sampleRate == 16000, "Should be resampled to 16kHz")
    // Expected frame length: 4800 * (16000/48000) = 1600
    let expectedFrames = AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / 48000.0))
    #expect(resampled.frameLength == expectedFrames, "Frame length should be scaled proportionally")
  }
  
  @Test func testConvertBufferToFloatArray_MonoAudio() async throws {
    // Create mono buffer
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 16000,
                                     channels: 1,
                                     interleaved: false) else {
      Issue.record("Failed to create audio format")
      return
    }
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
      Issue.record("Failed to create audio buffer")
      return
    }
    
    buffer.frameLength = 100
    
    // Fill with test data
    guard let channelData = buffer.floatChannelData else {
      Issue.record("No channel data")
      return
    }
    
    for i in 0..<100 {
      channelData[0][i] = Float(i) / 100.0
    }
    
    // Convert to float array
    let floatArray = AudioStreamManager.convertBufferToFloatArray(buffer)
    
    #expect(floatArray.count == 100, "Should have 100 samples")
    #expect(floatArray[0] == 0.0, "First sample should be 0.0")
    #expect(floatArray[99] == 0.99, "Last sample should be 0.99")
  }
  
  @Test func testConvertBufferToFloatArray_StereoAudio() async throws {
    // Create stereo buffer
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 16000,
                                     channels: 2,
                                     interleaved: false) else {
      Issue.record("Failed to create audio format")
      return
    }
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
      Issue.record("Failed to create audio buffer")
      return
    }
    
    buffer.frameLength = 100
    
    // Fill with test data (different values for left and right channels)
    guard let channelData = buffer.floatChannelData else {
      Issue.record("No channel data")
      return
    }
    
    for i in 0..<100 {
      channelData[0][i] = 1.0 // Left channel
      channelData[1][i] = 0.0 // Right channel
    }
    
    // Convert to float array (should average channels)
    let floatArray = AudioStreamManager.convertBufferToFloatArray(buffer)
    
    #expect(floatArray.count == 100, "Should have 100 samples")
    #expect(floatArray[0] == 0.5, "Should average left (1.0) and right (0.0) to 0.5")
    #expect(floatArray[50] == 0.5, "All samples should be averaged to 0.5")
  }
  
  @Test func testConvertBufferToFloatArray_EmptyBuffer() async throws {
    // Create empty buffer
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 16000,
                                     channels: 1,
                                     interleaved: false) else {
      Issue.record("Failed to create audio format")
      return
    }
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100) else {
      Issue.record("Failed to create audio buffer")
      return
    }
    
    buffer.frameLength = 0 // Empty buffer
    
    // Convert to float array
    let floatArray = AudioStreamManager.convertBufferToFloatArray(buffer)
    
    #expect(floatArray.isEmpty, "Should return empty array for empty buffer")
  }
  
  @Test func testCalculateRMS_SilentAudio() async throws {
    let samples: [Float] = Array(repeating: 0.0, count: 1000)
    
    let rms = AudioStreamManager.calculateRMS(samples)
    
    #expect(rms == 0.0, "RMS of silence should be 0.0")
  }
  
  @Test func testCalculateRMS_ConstantAudio() async throws {
    // RMS of constant value should equal absolute value
    let samples: [Float] = Array(repeating: 0.5, count: 1000)
    
    let rms = AudioStreamManager.calculateRMS(samples)
    
    #expect(rms == 0.5, "RMS of constant 0.5 should be 0.5")
  }
  
  @Test func testCalculateRMS_AlternatingAudio() async throws {
    // Create alternating +1.0 and -1.0 samples
    var samples: [Float] = []
    for i in 0..<1000 {
      samples.append(i % 2 == 0 ? 1.0 : -1.0)
    }
    
    let rms = AudioStreamManager.calculateRMS(samples)
    
    // RMS of alternating ±1.0 should be 1.0
    // sqrt((1^2 + (-1)^2 + 1^2 + (-1)^2 + ...) / n) = sqrt(1) = 1.0
    #expect(abs(rms - 1.0) < 0.001, "RMS of alternating ±1.0 should be approximately 1.0")
  }
  
  @Test func testCalculateRMS_EmptyArray() async throws {
    let samples: [Float] = []
    
    let rms = AudioStreamManager.calculateRMS(samples)
    
    #expect(rms == 0.0, "RMS of empty array should be 0.0")
  }
  
  // MARK: - Integration Tests
  
  @Test func testResampleAndConvertPipeline() async throws {
    // Test the complete pipeline: create 48kHz buffer → resample to 16kHz → convert to float array
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 48000,
                                     channels: 2,
                                     interleaved: false) else {
      Issue.record("Failed to create audio format")
      return
    }
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800) else {
      Issue.record("Failed to create audio buffer")
      return
    }
    
    buffer.frameLength = 4800
    
    // Fill with test data
    guard let channelData = buffer.floatChannelData else {
      Issue.record("No channel data")
      return
    }
    
    for i in 0..<4800 {
      channelData[0][i] = 0.3
      channelData[1][i] = 0.7
    }
    
    // Process through pipeline
    let resampled = AudioStreamManager.resampleIfNeeded(buffer)
    let floatArray = AudioStreamManager.convertBufferToFloatArray(resampled)
    
    #expect(resampled.format.sampleRate == 16000, "Should be resampled to 16kHz")
    #expect(!floatArray.isEmpty, "Should produce non-empty float array")
    
    // Calculate RMS of result
    let rms = AudioStreamManager.calculateRMS(floatArray)
    #expect(rms > 0.0, "RMS should be non-zero for non-silent audio")
    #expect(rms < 1.0, "RMS should be less than 1.0 for this test data")
  }
  
  // Note: Testing AudioStreamManager.startRecording() requires microphone access
  // which is not available in automated tests. These tests would need to be run
  // on a physical device with microphone permissions granted.
}
