//
//  SpeechRecognitionService.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation
import WhisperKit
import AVFoundation
import os.log

/// Service that handles multilingual speech-to-text and translation using WhisperKit
final class SpeechRecognitionService: @unchecked Sendable {
  static let shared = SpeechRecognitionService()
  
  private var audioStreamManager: AudioStreamManager?
  private var whisperKitManager: WhisperKitManager?
  
  // Callbacks for updates
  private var transcriptionCallback: ((String, Int) -> Void)?
  private var translationCallback: ((String, Int) -> Void)?
  
  // Audio buffer management using Swift Concurrency Actor
  private let audioBuffer = AudioBufferActor()
  private let maxSegmentLimit: Double = 7.0
  private let sampleRate: Double = 16000.0
  
  // Silence detection configuration
  private let silenceThreshold: Float = 0.025
  private let silenceDurationRequired: Double = 0.7
  
  // Serialization for concurrent loadModel() calls
  private var loadingTask: Task<Void, Error>? = nil
  
  /// Initialize the speech recognition service as singleton
  private init() {
    print("🎤 SpeechRecognitionService singleton initialized: \(Unmanaged.passUnretained(self).toOpaque())")
    whisperKitManager = WhisperKitManager()
    // Don't load model automatically - wait for explicit loadModel() call
  }
  
  /// Set progress callback for model loading
  /// - Parameter onProgress: Optional callback for model loading progress (0.0 to 1.0)
  func setProgressCallback(_ onProgress: ((Double) -> Void)?) {
    print("📞 SpeechRecognitionService.setProgressCallback called")
    Task {
      await whisperKitManager?.setProgressCallback(onProgress)
    }
  }
  
  /// Load the WhisperKit model for speech recognition and translation
  /// Must be called before starting listening - may take several seconds to complete
  func loadModel() async {
    // Unload any existing model first to ensure clean slate
    await unloadModel()
    
    do {
      try await whisperKitManager?.loadModel()
    } catch {
      print("Failed to load WhisperKit model: \(error)")
    }
  }
  
  /// Unload the WhisperKit model to free memory
  func unloadModel() async {
    await whisperKitManager?.unloadModel()
  }
  
  /// Start listening for speech recognition with either transcription or translation
  /// Processes microphone input in segments based on silence detection or 30-second limit
  /// - Parameters:
  ///   - transcribeOnly: If true, transcribes to original language. If false, translates to English
  ///   - onUpdate: Callback for receiving text updates (text, segmentNumber)
  /// - Returns: True if listening started successfully, false if model not ready
  func startListening(
    transcribeOnly: Bool = false,
    onUpdate: @escaping (String, Int) -> Void
  ) async -> Bool {
    guard await whisperKitManager?.whisperKit != nil else {
      print("WhisperKit not initialized")
      return false
    }
    
    // Store the single callback based on the transcribeOnly flag
    if transcribeOnly {
      transcriptionCallback = onUpdate
      translationCallback = nil
    } else {
      transcriptionCallback = nil
      translationCallback = onUpdate
    }
    
    // Start audio streaming - single stream for chosen task
    if audioStreamManager == nil {
      audioStreamManager = AudioStreamManager()
    }
    do {
      try await audioStreamManager?.startRecording { [weak self] buffer in
        guard let self = self else { return }
        Task {
          await self.accumulateAudio(buffer)
        }
      }
      return true
    } catch {
      print("Failed to start audio recording: \(error)")
      return false
    }
  }
  
  /// Process incoming audio buffer and manage segment boundaries
  /// This function uses the AudioBufferActor to safely manage state and determine when to process segments.
  /// Much cleaner than the previous GCD-based approach - no more withCheckedContinuation needed!
  /// - Parameter buffer: Audio buffer from microphone input
  func accumulateAudio(_ buffer: AVAudioPCMBuffer) async {
    // Resample to 16kHz if needed
    let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)
    
    // Convert to float array
    let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)
    
    // Calculate RMS for silence detection
    let rms = AudioStreamManager.calculateRMS(audioData)
    let now = CFAbsoluteTimeGetCurrent()
    
    // Ask the actor to process the audio and determine if we should cut a segment
    // This replaces all the complex GCD queue logic with a simple actor call
    let segmentToProcess = await audioBuffer.appendAudio(
      audioData,
      now: now,
      rms: rms,
      sampleRate: sampleRate,
      maxSegmentLimit: maxSegmentLimit,
      silenceThreshold: silenceThreshold,
      silenceDurationRequired: silenceDurationRequired
    )
    
    // Process segment if the actor determined one is ready
    if let (audioToProcess, segmentNumber) = segmentToProcess {
      Task.detached { [weak self] in
        guard let self, let whisperKitManager = self.whisperKitManager else { return }
        print("🎯 Starting WhisperKit processing for segment #\(segmentNumber)")
        
        // Process either transcription OR translation based on what callback is set
        if let transcriptionCallback = self.transcriptionCallback {
          await whisperKitManager.processSegment(
            audioToProcess,
            segmentNumber: segmentNumber,
            sampleRate: self.sampleRate,
            transcribeOnly: true,
            callback: transcriptionCallback
          )
        } else if let translationCallback = self.translationCallback {
          await whisperKitManager.processSegment(
            audioToProcess,
            segmentNumber: segmentNumber,
            sampleRate: self.sampleRate,
            transcribeOnly: false,
            callback: translationCallback
          )
        }
        
        print("✅ Completed WhisperKit processing for segment #\(segmentNumber)")
        print("✅ Marked segment #\(segmentNumber) as complete, ready for next segment")
      }
    }
  }
  
  /// Stop audio listening and clean up resources
  /// Stops microphone recording, releases audio buffers, and resets all state.
  /// Safe to call multiple times.
  func stopListening() {
    audioStreamManager?.stopRecording()
    audioStreamManager = nil
    
    // Clear callbacks to prevent ghost callbacks
    transcriptionCallback = nil
    translationCallback = nil
    
    // Reset the actor state
    Task {
      await audioBuffer.reset()
    }
  }
  
  /// Check if the service is ready for audio processing
  /// Returns true when WhisperKit model is loaded and ready for translation
  var isReady: Bool {
    get async {
      return await whisperKitManager?.whisperKit != nil
    }
  }
  
  // MARK: - Testing Support
  
  /// Process an audio file for testing - loads entire file and processes through WhisperKit
  /// - Returns: The complete transcribed/translated text from the entire audio file
  func processAudioFile(at audioFileURL: URL, task: DecodingTask, language: String? = nil) async throws -> String {
    guard let whisperKit = await whisperKitManager?.whisperKit else {
      throw AudioStreamError.engineSetupFailed
    }
    
    // Load the audio file
    let audioFile = try AVAudioFile(forReading: audioFileURL)
    let format = audioFile.processingFormat
    let frameCount = UInt32(audioFile.length)
    
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw AudioStreamError.engineSetupFailed
    }
    
    try audioFile.read(into: buffer)
    
    // Resample to 16kHz if needed and convert to float array
    let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)
    let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)
    
    guard !audioData.isEmpty else {
      throw AudioStreamError.engineSetupFailed
    }
    
    // Process with WhisperKit
    var decodingOptions = DecodingOptions(task: task)
    if let language = language {
      decodingOptions.language = language
    }
    let results = try await whisperKit.transcribe(
      audioArray: audioData,
      decodeOptions: decodingOptions
    )
    
    // Extract text from all segments
    let combinedText = results.map { $0.text }.joined(separator: " ")
    
    return combinedText
  }
}
