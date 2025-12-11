//
//  SubtitlesViewModel.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation
import SwiftUI

/// Main ViewModel that uses SFSpeechRecognizer for Turkish transcription and Apple Translation for English
@MainActor
class SubtitlesViewModel: ObservableObject {
    @Published var turkish: String = ""
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
    
    private var turkishSpeechService: TurkishSpeechService!
    
    init() {
        // Initialize Turkish speech service (no model loading needed for SFSpeechRecognizer)
        turkishSpeechService = TurkishSpeechService()
        
        // Handle app lifecycle
        setupLifecycleObservers()
    }
    
    /// Load the model - simplified for SFSpeechRecognizer (no heavy model loading needed)
    func loadModel() async {
        // No actual loading needed for SFSpeechRecognizer, but maintain compatibility
        isModelLoading = true
        loadingProgress = 0.0
        
        // Simulate brief initialization
        try? await Task.sleep(for: .milliseconds(100))
        loadingProgress = 0.5
        
        try? await Task.sleep(for: .milliseconds(100))
        loadingProgress = 1.0
        isModelLoading = false
    }
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App going to background - stop listening
            Task { @MainActor in
                self?.reset()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App returning to foreground - restart
            Task { @MainActor in
                guard let self else { return }
                self.start()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // App terminating - clean up
            Task { @MainActor in
                self?.reset()
            }
        }
    }
    
    func start() {
        Task {
            // Start listening for Turkish speech and English translation
            let success = await turkishSpeechService.startListening(
                onTurkishUpdate: { [weak self] turkishText, segmentNumber in
                    Task { @MainActor in
                        guard let self = self else { return }
                        print("🎯 Received Turkish transcription for segment #\(segmentNumber): \(turkishText)")
                        self.turkish = turkishText
                    }
                },
                onEnglishUpdate: { [weak self] englishText, segmentNumber in
                    Task { @MainActor in
                        guard let self = self else { return }
                        print("🎯 Received English translation for segment #\(segmentNumber): \(englishText)")
                        self.handleNewSubtitle(text: englishText, segmentNumber: segmentNumber)
                    }
                }
            )
            
            if success {
                isRecording = true
            } else {
                print("Failed to start Turkish speech recognition")
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
        turkishSpeechService.stopListening()
        isRecording = false
        
        // Clean up timing system
        displayTimer?.invalidate()
        displayTimer = nil
        currentSubtitleStartTime = nil
        subtitleQueue.removeAll()
        
        // Clear text
        turkish = ""
        english = ""
    }
    
    /// Unload model to free memory - call when view disappears
    func unloadModel() {
        reset()
        isModelLoading = false
        loadingProgress = 0.0
    }
    
    deinit {
        displayTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Testing Methods
    
    /// Testing method to calculate reading time
    func calculateReadingTimeForTesting(text: String) -> Double {
        return calculateReadingTime(for: text)
    }
    
    /// Testing method to handle new subtitle
    func handleNewSubtitleForTesting(text: String, segmentNumber: Int) {
        handleNewSubtitle(text: text, segmentNumber: segmentNumber)
    }
    
    /// Testing method to get queue count
    func getQueueCountForTesting() -> Int {
        return subtitleQueue.count
    }
    
    /// Testing method to process queue manually
    func processQueueForTesting() {
        processQueue()
    }
    
    /// Testing method to simulate time passage
    func simulateTimePassageForTesting(seconds: TimeInterval) {
        if let startTime = currentSubtitleStartTime {
            currentSubtitleStartTime = startTime.addingTimeInterval(-seconds)
        }
    }
}
