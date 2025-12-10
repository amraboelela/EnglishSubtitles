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
  @Published var isModelLoading: Bool = false
  @Published var loadingProgress: Double = 0.0

  // Subtitle timing and queueing system
  var currentSubtitleStartTime: Date?
  var subtitleQueue: [(text: String, segmentNumber: Int)] = []
  private var displayTimer: Timer?
  private let wordsPerSecond: Double = 3.0 // Average reading speed
  private let minimumDisplayTime: Double = 2.0 // Minimum 2 seconds per subtitle

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
    self.isModelLoading = true
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

          // Use the timing-based queueing system instead of direct text replacement
          print("🎯 Received translation for segment #\(segmentNumber): \(englishText)")
          self.handleNewSubtitle(text: englishText, segmentNumber: segmentNumber)
        }
      }

      if success {
        isRecording = true
      }
    }
  }

  // MARK: - Subtitle Timing and Queueing System

  /// Calculate required reading time based on word count and reading speed
  func calculateReadingTime(for text: String) -> Double {
    let wordCount = text.split(separator: " ").count
    let calculatedTime = Double(wordCount) / wordsPerSecond
    return max(calculatedTime, minimumDisplayTime)
  }

  /// Handle new subtitle with timing-based queueing
  func handleNewSubtitle(text: String, segmentNumber: Int) {
    let now = Date()

    // If queue is not empty, add new subtitle to queue
    guard subtitleQueue.isEmpty else {
      print("📦 Queue not empty, adding subtitle to queue")
      queueSubtitle(text: text, segmentNumber: segmentNumber)
      return
    }

    // If no subtitle is currently displayed, show immediately
    guard let startTime = currentSubtitleStartTime else {
      print("🚀 First subtitle, displaying immediately")
      displaySubtitle(text: text, segmentNumber: segmentNumber, startTime: now)
      return
    }

    // Calculate how long current subtitle has been displayed
    let currentDisplayDuration = now.timeIntervalSince(startTime)
    let requiredDisplayTime = calculateReadingTime(for: english)

    print("⏰ Current subtitle displayed for \(String(format: "%.1f", currentDisplayDuration))s, requires \(String(format: "%.1f", requiredDisplayTime))s")

    // If current subtitle has been displayed long enough, show new one immediately
    if currentDisplayDuration >= requiredDisplayTime {
      print("✅ Adequate time elapsed, displaying new subtitle immediately")
      displaySubtitle(text: text, segmentNumber: segmentNumber, startTime: now)
    } else {
      // Queue the new subtitle and set timer
      let remainingTime = requiredDisplayTime - currentDisplayDuration
      print("⏳ Queueing subtitle, will display in \(String(format: "%.1f", remainingTime))s")
      queueSubtitle(text: text, segmentNumber: segmentNumber)
      scheduleNextSubtitle(remainingTime: remainingTime)
    }
  }

  /// Display subtitle
  private func displaySubtitle(text: String, segmentNumber: Int, startTime: Date) {
    currentSubtitleStartTime = startTime
    english = text
    print("📝 Displaying: \(text)")
  }

  /// Add subtitle to queue
  private func queueSubtitle(text: String, segmentNumber: Int) {
    // Add new subtitle to queue
    subtitleQueue.append((text: text, segmentNumber: segmentNumber))
    print("⏳ Queued subtitle (\(subtitleQueue.count) in queue): \(text)")
  }

  /// Schedule the next subtitle from queue
  private func scheduleNextSubtitle(remainingTime: Double) {
    displayTimer?.invalidate()
    displayTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
      Task { @MainActor in
        self?.processQueue()
      }
    }
  }

  /// Process the subtitle queue
  func processQueue() {
    guard let nextSubtitle = subtitleQueue.first else {
      print("📭 Queue empty, nothing to process")
      return
    }
    subtitleQueue.removeFirst()

    let now = Date()
    print("🎬 Processing queued subtitle: \(nextSubtitle.text)")

    // Display the queued subtitle immediately (it's already waited its turn)
    displaySubtitle(text: nextSubtitle.text, segmentNumber: nextSubtitle.segmentNumber, startTime: now)

    // If there are more subtitles in queue, calculate timing based on the NEWLY displayed subtitle
    if !subtitleQueue.isEmpty {
      let displayTime = calculateReadingTime(for: nextSubtitle.text) // Use the subtitle we just displayed
      print("⏭️ More subtitles in queue (\(subtitleQueue.count)), scheduling next in \(String(format: "%.1f", displayTime))s")
      scheduleNextSubtitle(remainingTime: displayTime)
    } else {
      print("🏁 Queue now empty")
    }
  }

  func reset() {
    speechRecognition.stopListening()
    isRecording = false

    // Clean up timing system
    displayTimer?.invalidate()
    displayTimer = nil
    currentSubtitleStartTime = nil
    subtitleQueue.removeAll()
  }

  /// Unload model to free memory - call when view disappears
  func unloadModel() {
    reset()
    isModelLoading = false
    Task {
      await speechRecognition.unloadModel()
    }
    loadingProgress = 0.0
  }

  deinit {
    displayTimer?.invalidate()
    NotificationCenter.default.removeObserver(self)
  }
}
