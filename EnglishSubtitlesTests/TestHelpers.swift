//
//  TestHelpers.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Foundation
@testable import EnglishSubtitles

/// Shared helper methods for all test files
enum TestHelpers {

    /// Get the path to the bundled audio file (similar to bundledModelPath approach)
    static func bundledAudioPath() -> String? {
        // Try to find the audio file in various locations
        let fileManager = FileManager.default

        // 1. Try all loaded bundles
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "fateh-1", withExtension: "m4a") {
                print("Found audio in bundle: \(bundle.bundlePath)")
                return url.path
            }
        }

        // 2. Try the main app bundle
        if let url = Bundle.main.url(forResource: "fateh-1", withExtension: "m4a") {
            return url.path
        }

        // 3. Try project root (for development) using #filePath
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fateh-1.m4a")

        if fileManager.fileExists(atPath: projectRoot.path) {
            print("Found audio in project root: \(projectRoot.path)")
            return projectRoot.path
        }

        print("✗ Audio file not found in any expected location")
        return nil
    }

    /// Wait for WhisperKit model to load with progress updates
    /// - Parameters:
    ///   - service: The SpeechRecognitionService to check
    ///   - maxWait: Maximum wait time in seconds (default 180 for initial download)
    /// - Returns: True if model loaded, false if timeout
    static func waitForWhisperKit(_ service: SpeechRecognitionService, maxWait: Double = 180.0) async -> Bool {
        var waited = 0.0

        while !service.isReady && waited < maxWait {
            try? await Task.sleep(for: .seconds(1))
            waited += 1.0
            if Int(waited) % 10 == 0 {
                print("Waiting for WhisperKit model... \(Int(waited))s")
            }
        }

        return service.isReady
    }
}
