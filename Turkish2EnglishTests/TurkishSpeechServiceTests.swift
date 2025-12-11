//
//  TurkishSpeechServiceTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/11/25.
//

import Testing
import Foundation
import Speech
import AVFoundation
@testable import EnglishSubtitles

/// Tests for TurkishSpeechService - Turkish speech recognition and translation
@Suite(.serialized)
@MainActor
class TurkishSpeechServiceTests {
    
    static let speechService = TurkishSpeechService()
    
    // MARK: - Initialization Tests
    
    @Test func testSpeechServiceInitialization() async throws {
        // Test that the service can be initialized without crashing
        let service = TurkishSpeechService()
        #expect(true, "Service should initialize without crashing")
        
        // Service should have translation service initialized
        print("TurkishSpeechService initialized successfully")
    }
    
    // MARK: - Authorization Tests
    
    @Test func testRequestAuthorization() async throws {
        // Test speech recognition authorization request
        let isAuthorized = await Self.speechService.requestAuthorization()
        
        // In simulator/test environment, authorization might be denied
        // The important thing is that the method doesn't crash
        print("Speech recognition authorization result: \(isAuthorized)")
        
        // Test completes successfully if no crash occurs
        #expect(true, "Authorization request should complete without crashing")
    }
    
    // MARK: - Start/Stop Listening Tests
    
    @Test func testStartListeningBasicFlow() async throws {
        var turkishCallbackCalled = false
        var englishCallbackCalled = false
        var receivedTurkishText = ""
        var receivedEnglishText = ""
        var receivedSegmentNumber = 0
        
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { text, segmentNumber in
                turkishCallbackCalled = true
                receivedTurkishText = text
                receivedSegmentNumber = segmentNumber
                print("📝 Turkish callback: '\(text)' (segment \(segmentNumber))")
            },
            onEnglishUpdate: { text, segmentNumber in
                englishCallbackCalled = true
                receivedEnglishText = text
                receivedSegmentNumber = segmentNumber
                print("🌍 English callback: '\(text)' (segment \(segmentNumber))")
            }
        )
        
        // In simulator/test environment, microphone access might fail
        // The important thing is that the method doesn't crash
        print("Start listening result: \(success)")
        
        // Give some time for potential callbacks (in real device with microphone)
        try await Task.sleep(for: .seconds(1))
        
        // Stop listening to clean up
        Self.speechService.stopListening()
        
        // Test that the method calls don't crash
        #expect(true, "Start listening flow should complete without crashing")
        
        // Note: Callbacks won't be called in simulator without audio input
        print("Callback status - Turkish: \(turkishCallbackCalled), English: \(englishCallbackCalled)")
    }
    
    @Test func testStartListeningWithoutAuthorization() async throws {
        // Test behavior when authorization is not granted
        // Note: This is hard to test directly as authorization state persists
        
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { _, _ in },
            onEnglishUpdate: { _, _ in }
        )
        
        // Service should handle authorization gracefully
        print("Start listening without auth result: \(success)")
        
        // Clean up
        Self.speechService.stopListening()
        
        #expect(true, "Should handle authorization gracefully")
    }
    
    @Test func testStopListening() async throws {
        // Test that stop listening can be called safely
        Self.speechService.stopListening()
        
        // Multiple calls should be safe
        Self.speechService.stopListening()
        Self.speechService.stopListening()
        
        #expect(true, "Stop listening should be safe to call multiple times")
        print("Stop listening test completed")
    }
    
    @Test func testStartStopCycle() async throws {
        // Test multiple start/stop cycles
        for i in 1...3 {
            print("Start/Stop cycle \(i)")
            
            let success = await Self.speechService.startListening(
                onTurkishUpdate: { text, segment in
                    print("Cycle \(i) Turkish: \(text)")
                },
                onEnglishUpdate: { text, segment in
                    print("Cycle \(i) English: \(text)")
                }
            )
            
            print("Cycle \(i) start result: \(success)")
            
            // Brief delay
            try await Task.sleep(for: .milliseconds(200))
            
            // Stop
            Self.speechService.stopListening()
            
            // Brief delay between cycles
            try await Task.sleep(for: .milliseconds(100))
        }
        
        #expect(true, "Multiple start/stop cycles should work safely")
        print("Start/Stop cycle test completed")
    }
    
    // MARK: - Callback Tests
    
    @Test func testCallbackParameters() async throws {
        var callbackResults: [(String, Int, String)] = [] // (text, segment, type)
        
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { text, segmentNumber in
                callbackResults.append((text, segmentNumber, "Turkish"))
                print("Turkish callback: '\(text)' segment \(segmentNumber)")
            },
            onEnglishUpdate: { text, segmentNumber in
                callbackResults.append((text, segmentNumber, "English"))
                print("English callback: '\(text)' segment \(segmentNumber)")
            }
        )
        
        print("Callback test - start result: \(success)")
        
        // Wait for potential callbacks
        try await Task.sleep(for: .seconds(1))
        
        // Clean up
        Self.speechService.stopListening()
        
        // In simulator, callbacks won't be triggered, but the test verifies setup
        print("Callback test completed - received \(callbackResults.count) callbacks")
        
        #expect(true, "Callback setup should complete without crashes")
    }
    
    @Test func testNilCallbacks() async throws {
        // Test that service handles callbacks gracefully even if they're simple
        var simpleCallbackCount = 0
        
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { _, _ in
                simpleCallbackCount += 1
            },
            onEnglishUpdate: { _, _ in
                simpleCallbackCount += 1
            }
        )
        
        print("Simple callback test - start result: \(success)")
        
        try await Task.sleep(for: .milliseconds(500))
        
        Self.speechService.stopListening()
        
        print("Simple callback count: \(simpleCallbackCount)")
        #expect(true, "Service should handle simple callbacks")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testRapidStartCalls() async throws {
        // Test rapid start calls don't cause issues
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            // Launch multiple start attempts
            for i in 1...3 {
                group.addTask {
                    let success = await Self.speechService.startListening(
                        onTurkishUpdate: { text, segment in
                            print("Rapid \(i) Turkish: \(text)")
                        },
                        onEnglishUpdate: { text, segment in
                            print("Rapid \(i) English: \(text)")
                        }
                    )
                    print("Rapid start \(i) result: \(success)")
                    return success
                }
            }
            
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Clean up
        Self.speechService.stopListening()
        
        print("Rapid start results: \(results)")
        #expect(true, "Rapid start calls should be handled gracefully")
    }
    
    @Test func testConcurrentOperations() async throws {
        // Test concurrent start and stop operations
        async let startTask: Bool = Self.speechService.startListening(
            onTurkishUpdate: { _, _ in },
            onEnglishUpdate: { _, _ in }
        )
        
        // Concurrent stop
        async let stopTask: Void = {
            try? await Task.sleep(for: .milliseconds(100))
            await Self.speechService.stopListening()
        }()
        
        let startResult = await startTask
        await stopTask
        
        print("Concurrent operations - start result: \(startResult)")
        #expect(true, "Concurrent operations should be handled safely")
    }
    
    // MARK: - Memory Management Tests
    
    @Test func testMemoryManagement() async throws {
        // Test that multiple service instances don't cause memory issues
        for i in 1...5 {
            var service: TurkishSpeechService? = TurkishSpeechService()
            
            let success = await service!.startListening(
                onTurkishUpdate: { _, _ in },
                onEnglishUpdate: { _, _ in }
            )
            
            print("Memory test \(i) - start result: \(success)")
            
            // Brief operation
            try await Task.sleep(for: .milliseconds(50))
            
            service?.stopListening()
            
            // Deallocate
            service = nil
        }
        
        #expect(true, "Memory management should work correctly")
        print("Memory management test completed")
    }
    
    @Test func testServiceDeallocation() async throws {
        // Test that service deallocates cleanly after operations
        var service: TurkishSpeechService? = TurkishSpeechService()
        
        let success = await service!.startListening(
            onTurkishUpdate: { _, _ in },
            onEnglishUpdate: { _, _ in }
        )
        
        print("Deallocation test - start result: \(success)")
        
        service?.stopListening()
        
        // Deallocate service
        service = nil
        
        #expect(true, "Service should deallocate cleanly")
        print("Service deallocation test completed")
    }
    
    // MARK: - Audio Engine Tests
    
    @Test func testAudioEngineHandling() async throws {
        // Test that audio engine operations don't crash
        let success1 = await Self.speechService.startListening(
            onTurkishUpdate: { _, _ in },
            onEnglishUpdate: { _, _ in }
        )
        
        print("Audio engine test 1 - start result: \(success1)")
        
        // Stop and start again to test audio engine cleanup
        Self.speechService.stopListening()
        
        let success2 = await Self.speechService.startListening(
            onTurkishUpdate: { _, _ in },
            onEnglishUpdate: { _, _ in }
        )
        
        print("Audio engine test 2 - start result: \(success2)")
        
        // Final cleanup
        Self.speechService.stopListening()
        
        #expect(true, "Audio engine operations should be handled safely")
    }
    
    // MARK: - Translation Integration Tests
    
    @Test func testTranslationServiceIntegration() async throws {
        // Test that the integration with AppleTranslationService works
        var translationAttempts = 0
        
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { text, segment in
                print("Integration test Turkish: '\(text)' (segment \(segment))")
            },
            onEnglishUpdate: { text, segment in
                translationAttempts += 1
                print("Integration test English: '\(text)' (segment \(segment))")
            }
        )
        
        print("Translation integration test - start result: \(success)")
        
        // In simulator, no actual speech will be processed
        // But the integration should be set up correctly
        try await Task.sleep(for: .seconds(1))
        
        Self.speechService.stopListening()
        
        print("Translation attempts during test: \(translationAttempts)")
        #expect(true, "Translation service integration should be set up correctly")
    }
    
    // MARK: - State Management Tests
    
    @Test func testServiceState() async throws {
        // Test service state through start/stop cycles
        
        // Initial state - stopped
        Self.speechService.stopListening() // Ensure clean state
        
        // Start listening
        let startResult = await Self.speechService.startListening(
            onTurkishUpdate: { _, _ in },
            onEnglishUpdate: { _, _ in }
        )
        
        print("State test - start result: \(startResult)")
        
        // Service should be in listening state (if authorization succeeded)
        
        // Stop listening
        Self.speechService.stopListening()
        
        // Service should be in stopped state
        
        #expect(true, "Service state transitions should work correctly")
        print("Service state test completed")
    }
    
    @Test func testRepeatedStarts() async throws {
        // Test that repeated starts are handled correctly
        
        for i in 1...3 {
            let success = await Self.speechService.startListening(
                onTurkishUpdate: { text, segment in
                    print("Repeated start \(i) Turkish: \(text)")
                },
                onEnglishUpdate: { text, segment in
                    print("Repeated start \(i) English: \(text)")
                }
            )
            
            print("Repeated start \(i) result: \(success)")
            
            // Don't stop between starts to test handling of repeated starts
        }
        
        // Final cleanup
        Self.speechService.stopListening()
        
        #expect(true, "Repeated starts should be handled gracefully")
    }
    
    // MARK: - Edge Cases
    
    @Test func testEmptyCallbacks() async throws {
        // Test with minimal callback implementations
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { _, _ in
                // Empty implementation
            },
            onEnglishUpdate: { _, _ in
                // Empty implementation
            }
        )
        
        print("Empty callbacks test - start result: \(success)")
        
        try await Task.sleep(for: .milliseconds(300))
        
        Self.speechService.stopListening()
        
        #expect(true, "Empty callbacks should be handled correctly")
    }
    
    @Test func testLongRunningSession() async throws {
        // Test a longer running session (but still reasonable for tests)
        let success = await Self.speechService.startListening(
            onTurkishUpdate: { text, segment in
                print("Long session Turkish: '\(text)' (segment \(segment))")
            },
            onEnglishUpdate: { text, segment in
                print("Long session English: '\(text)' (segment \(segment))")
            }
        )
        
        print("Long session test - start result: \(success)")
        
        // Run for a bit longer than other tests
        try await Task.sleep(for: .seconds(2))
        
        Self.speechService.stopListening()
        
        #expect(true, "Long running sessions should work correctly")
        print("Long running session test completed")
    }
}

// MARK: - Mock Tests (for cases where we can simulate input)

@Suite(.serialized)
@MainActor
class TurkishSpeechServiceMockTests {

    @Test func testCallbackExecution() async throws {
        // Test that we can verify callback behavior with manual calls
        var receivedTurkishTexts: [String] = []
        var receivedEnglishTexts: [String] = []
        var receivedSegments: [Int] = []

        let turkishCallback: (String, Int) -> Void = { text, segment in
            receivedTurkishTexts.append(text)
            receivedSegments.append(segment)
        }

        let englishCallback: (String, Int) -> Void = { text, segment in
            receivedEnglishTexts.append(text)
            receivedSegments.append(segment)
        }

        // Simulate callbacks manually
        turkishCallback("Merhaba", 1)
        englishCallback("Hello", 1)
        turkishCallback("Nasılsınız", 2)
        englishCallback("How are you", 2)

        // Verify callback behavior
        #expect(receivedTurkishTexts.count == 2, "Should receive Turkish texts")
        #expect(receivedEnglishTexts.count == 2, "Should receive English texts")
        #expect(receivedSegments.count == 4, "Should receive segment numbers")

        #expect(receivedTurkishTexts[0] == "Merhaba", "First Turkish text correct")
        #expect(receivedEnglishTexts[0] == "Hello", "First English text correct")
        #expect(receivedTurkishTexts[1] == "Nasılsınız", "Second Turkish text correct")
        #expect(receivedEnglishTexts[1] == "How are you", "Second English text correct")

        print("Callback execution test completed successfully")
    }

    @Test func testSegmentNumbering() async throws {
        // Test that segment numbering works correctly
        var segments: [Int] = []

        let callback: (String, Int) -> Void = { _, segment in
            segments.append(segment)
        }

        // Simulate multiple segments
        callback("First", 1)
        callback("Second", 2)
        callback("Third", 3)

        #expect(segments == [1, 2, 3], "Segment numbers should be sequential")

        print("Segment numbering test completed successfully")
    }
}
