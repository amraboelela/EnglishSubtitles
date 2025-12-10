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
    
    /// Get the path to the bundled Quran audio file
    static func bundledQuranAudioPath() -> String? {
        let fileManager = FileManager.default
        
        // 1. Try all loaded bundles
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "001", withExtension: "mp3") {
                print("Found Quran audio in bundle: \(bundle.bundlePath)")
                return url.path
            }
        }
        
        // 2. Try the main app bundle
        if let url = Bundle.main.url(forResource: "001", withExtension: "mp3") {
            return url.path
        }
        
        // 3. Try project root (for development) using #filePath
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("001.mp3")
        
        if fileManager.fileExists(atPath: projectRoot.path) {
            print("Found Quran audio in project root: \(projectRoot.path)")
            return projectRoot.path
        }
        
        print("✗ Quran audio file not found in any expected location")
        return nil
    }
    
    /// Get the path to 001.mp3 (alias for bundledQuranAudioPath)
    static func bundled001AudioPath() -> String? {
        return bundledQuranAudioPath()
    }
    
    /// Wait for WhisperKit model to load with progress updates
    /// - Returns: True if model loaded, false if timeout
    static func waitForWhisperKit(_ service: SpeechRecognitionService, maxWait: Double = 180.0) async -> Bool {
        var waited = 0.0
        
        while !(await service.isReady) && waited < maxWait {
            try? await Task.sleep(for: .seconds(1))
            waited += 1.0
            if Int(waited) % 10 == 0 {
                print("Waiting for WhisperKit model... \(Int(waited))s")
            }
        }
        
        return await service.isReady
    }
}
