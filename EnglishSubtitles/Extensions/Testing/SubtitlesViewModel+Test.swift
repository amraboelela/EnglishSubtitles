//
//  SubtitlesViewModel+Test.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/9/25.
//

import Foundation

#if DEBUG
extension SubtitlesViewModel {
    /// Testing extension to expose calculateReadingTime for unit tests
    func calculateReadingTimeForTesting(text: String) -> Double {
        return calculateReadingTime(for: text)
    }

    /// Testing extension to expose handleNewSubtitle for unit tests
    func handleNewSubtitleForTesting(text: String, segmentNumber: Int) {
        handleNewSubtitle(text: text, segmentNumber: segmentNumber)
    }

    /// Testing extension to expose queue count for unit tests
    func getQueueCountForTesting() -> Int {
        return subtitleQueue.count
    }

    /// Testing extension to manually process queue for unit tests
    func processQueueForTesting() {
        processQueue()
    }

    /// Testing extension to simulate time passage for unit tests
    func simulateTimePassageForTesting(seconds: Double) {
        guard let startTime = currentSubtitleStartTime else { return }
        currentSubtitleStartTime = startTime.addingTimeInterval(-seconds)
    }
}
#endif