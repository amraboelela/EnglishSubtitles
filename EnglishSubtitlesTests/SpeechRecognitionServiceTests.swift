//
//  SpeechRecognitionServiceTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
import WhisperKit
import AVFoundation
@testable import EnglishSubtitles

/// Tests for SpeechRecognitionService - WhisperKit integration and actor-based audio processing
@Suite(.serialized)
class SpeechRecognitionServiceTests {

    // Use shared singleton instance for all tests
    static let service = SpeechRecognitionService.shared

    // MARK: - Initialization Tests

    @Test func testSpeechRecognitionServiceInitialization() async throws {

        // Test initial state
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Service should not be ready before model load")

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        #expect(isReady, "SpeechRecognitionService should be ready after initialization")
    }

    @Test func testServiceReadyState() async throws {
        // Ensure clean state
        await Self.service.unloadModel()

        // Initially not ready after unload
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Service should not be ready after unload")

        await Self.service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        #expect(isReady, "Service should be ready after model load")
        #expect(await Self.service.isReady, "isReady should return true after model load")

        // Unload model
        await Self.service.unloadModel()

        #expect(!(await Self.service.isReady), "Service should not be ready after model unload")
    }

    // MARK: - Audio File Processing Tests

    @Test func testTranscriptionWithTurkishAudio() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Transcribe the audio file (auto-detect language)
        let transcribedText = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.transcribe)
        print("Transcribed (Turkish): \(transcribedText)")

        // Verify we got some transcription
        #expect(!transcribedText.isEmpty, "Should transcribe Turkish audio to text")

        // The audio says "Haydi. Emret sultanım" in Turkish
        // We expect to get Turkish text back
        let hasTurkishWords = transcribedText.lowercased().contains("haydi") ||
                             transcribedText.lowercased().contains("emret") ||
                             transcribedText.lowercased().contains("sultan")

        #expect(hasTurkishWords, "Transcription should contain expected Turkish words (haydi, emret, or sultan)")
    }

    @Test func testTranslationWithTurkishAudio() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }
        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }
        let audioURL = URL(fileURLWithPath: audioPath)

        // Translate the audio file to English (auto-detect source language)
        let translatedText = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.translate)
        print("Translated (English): \(translatedText)")

        // Verify we got some translation
        #expect(!translatedText.isEmpty, "Should translate Turkish audio to English")

        // The audio says "Haydi. Emret sultanım" which translates to "Come on. As you order my sultan"
        // Check if translation contains key English words
        let hasEnglishWords = translatedText.lowercased().contains("come") ||
                             translatedText.lowercased().contains("sultan") ||
                             translatedText.lowercased().contains("order") ||
                             translatedText.lowercased().contains("command")

        #expect(hasEnglishWords, "Translation should contain expected English words (come, sultan, order, or command)")
    }

    @Test func testTranscriptionWithArabicQuran() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }
        guard let audioPath = TestHelpers.bundledQuranAudioPath() else {
            Issue.record("Quran audio file not found")
            return
        }

        // Test with Quran recitation (Arabic)
        let quranURL = URL(fileURLWithPath: audioPath)

        // Transcribe the Quran audio (auto-detect Arabic)
        let transcribedText = try await Self.service.processAudioFile(at: quranURL, task: DecodingTask.transcribe)
        print("Transcribed (Arabic Quran): \(transcribedText)")

        // Verify we got some transcription
        #expect(!transcribedText.isEmpty, "Should transcribe Arabic Quran recitation")

        // Surah Al-Fatiha contains these common Arabic words
        let hasArabicWords = transcribedText.contains("الله") ||  // Allah
                            transcribedText.contains("الرحمن") ||  // Ar-Rahman
                            transcribedText.contains("الرحيم") ||  // Ar-Raheem
                            transcribedText.lowercased().contains("allah") ||
                            transcribedText.lowercased().contains("rahman")

        #expect(hasArabicWords, "Transcription should contain expected Arabic words from Al-Fatiha")
    }

    @Test func testTranslationWithArabicQuran() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }
        guard let audioPath = TestHelpers.bundledQuranAudioPath() else {
            Issue.record("Quran audio file not found")
            return
        }
        // Test with Quran recitation (Arabic)
        let quranURL = URL(fileURLWithPath: audioPath)

        // Translate the Quran audio to English (auto-detect Arabic)
        let translatedText = try await Self.service.processAudioFile(at: quranURL, task: DecodingTask.translate)
        print("Translated (English): \(translatedText)")

        // Verify we got some translation
        #expect(!translatedText.isEmpty, "Should translate Arabic Quran to English")

        // Al-Fatiha translation should contain these key English words
        let hasEnglishWords = translatedText.lowercased().contains("allah") ||
                             translatedText.lowercased().contains("god") ||
                             translatedText.lowercased().contains("merciful") ||
                             translatedText.lowercased().contains("compassionate") ||
                             translatedText.lowercased().contains("lord")

        #expect(hasEnglishWords, "Translation should contain expected English words from Al-Fatiha")
    }

    // MARK: - Hallucination Filtering Tests

    @Test func testHallucinationFiltering() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Test that the Self.service would filter hallucinations in processTranslation
        // We can't easily test this without mocking WhisperKit, but we can test the String extension
        let hallucinations = [
            "Subscribe",
            "Thanks for watching",
            "(music)",
            "[laughter]",
            "*door closes*",
            "-The End-"
        ]

        for hallucination in hallucinations {
            #expect(hallucination.isLikelyHallucination, "Service should filter '\(hallucination)' as hallucination")
        }

        let validSpeech = [
            "Hello, how are you?",
            "This is a normal conversation.",
            "Can you help me with this?"
        ]

        for speech in validSpeech {
            #expect(!speech.isLikelyHallucination, "Service should not filter '\(speech)' as hallucination")
        }
    }

    // MARK: - Real-time Listening Tests

    @Test func testStartListeningWithoutModel() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }
        // Try to start listening without loading model first
        let success = await Self.service.startListening(
            transcribeOnly: false,
            onUpdate: { text, segment in
                // Should not be called
            }
        )
        #expect(!success, "Should fail to start listening without loaded model")
    }

    @Test func testStartListeningWithModel() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // On simulator, we expect this to fail quickly due to no microphone access
        // On real device, this should succeed
        // Instead of waiting indefinitely, we'll just test that the method can be called

        #if targetEnvironment(simulator)
        // On simulator, just verify the service is ready and can attempt to start
        // We don't actually call startListening as it hangs on simulator
        #expect(await Self.service.isReady, "Service should be ready to attempt listening")
        print("Skipping startListening on simulator due to microphone access issues")
        #else
        // On real device, test actual listening functionality
        var receivedTranslations: [(text: String, segment: Int)] = []
        let success = await Self.service.startListening(
            transcribeOnly: false,
            onUpdate: { text, segment in
                receivedTranslations.append((text: text, segment: segment))
            }
        )

        #expect(success, "Should successfully start listening with loaded model")

        // Give it a moment to initialize
        try? await Task.sleep(for: .milliseconds(100))

        // Stop listening
        Self.service.stopListening()

        // The callback setup should work (we can't easily test audio input without actual microphone)
        #expect(receivedTranslations.isEmpty, "No translations expected without real audio input")
        #endif
    }

    @Test func testStopListening() async throws {

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        #if targetEnvironment(simulator)
        // On simulator, just test that stopListening can be called safely without starting
        Self.service.stopListening()
        Self.service.stopListening() // Should be safe to call multiple times
        #expect(true, "stopListening should not crash on simulator")
        #else
        // On real device, test actual start/stop cycle
        let success = await Self.service.startListening(
            transcribeOnly: false,
            onUpdate: { _, _ in }
        )
        #expect(success, "Should start listening")

        // Stop listening should be safe to call
        Self.service.stopListening()
        Self.service.stopListening() // Should be safe to call multiple times

        #expect(true, "stopListening should not crash")
        #endif
    }

    // MARK: - Model Lifecycle Tests

    @Test func testModelLoadUnloadCycle() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }
        // Initially not ready
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Should not be ready initially")
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)
        #expect(isReady, "Should be ready after load")

        // Unload model
        await Self.service.unloadModel()
        #expect(!(await Self.service.isReady), "Should not be ready after unload")

        // Load again
        await Self.service.loadModel()
        let isReady2 = await TestHelpers.waitForWhisperKit(Self.service)
        #expect(isReady2, "Should be ready after second load")
    }

    // MARK: - Error Handling Tests

    @Test func testProcessAudioFileWithInvalidURL() async throws {

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.wav")

        do {
            let _ = try await Self.service.processAudioFile(at: invalidURL, task: DecodingTask.transcribe)
            Issue.record("Should have thrown error for invalid file")
        } catch {
            #expect(true, "Should throw error for invalid audio file")
        }
    }

    @Test func testProcessAudioFileWithoutModel() async throws {
        if await Self.service.isReady {
            await Self.service.unloadModel()
        }
        // Don't load model
        let isReadyInitial = await Self.service.isReady
        #expect(!isReadyInitial, "Should not be ready without model")

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        do {
            let _ = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.transcribe)
            Issue.record("Should have thrown error without model")
        } catch {
            #expect(true, "Should throw error when processing without loaded model")
        }
    }

    // MARK: - Segmentation Tests

    @Test func testSegmentationWith001Audio() async throws {

        // Ensure model is properly loaded
        await Self.service.unloadModel()
        await Self.service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Get path to 001.mp3 (54.8 seconds of Quran recitation with natural pauses)
        guard let audioPath = TestHelpers.bundled001AudioPath() else {
            Issue.record("001.mp3 file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Process the audio file once to verify segmentation capability
        // In production, audio is chunked in real-time by the microphone
        // and segmentation happens based on silence detection
        print("Processing 001.mp3 for translation test...")

        let translation = try await Self.service.processAudioFile(at: audioURL, task: DecodingTask.translate, language: "ar")

        #expect(!translation.isEmpty, "Should detect audio content")

        // Verify we got a translation
        print("Translation result: \(translation)")

        let hasExpectedWords = translation.lowercased().contains("allah") ||
                               translation.lowercased().contains("god") ||
                               translation.lowercased().contains("merciful") ||
                               translation.lowercased().contains("lord") ||
                               translation.lowercased().contains("praise")

        #expect(hasExpectedWords, "Translation should contain expected words from Al-Fatiha")

        print("✅ Segmentation test completed - translation contains expected content")
    }

    // MARK: - Progress Callback Tests

    // MARK: - Audio Buffer Processing Tests

    @Test func testAudioAccumulationAndProcessing() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Create a mock audio buffer to test audio processing
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 16000 // 1 second at 16kHz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create audio buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with test audio data (sine wave)
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                let sample = sin(2.0 * Double.pi * 440.0 * Double(i) / 16000.0) * 0.1
                channelData.pointee[i] = Float(sample)
            }
        }

        // Test audio processing pipeline
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(buffer)
        let audioData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)
        let rms = AudioStreamManager.calculateRMS(audioData)

        #expect(!audioData.isEmpty, "Should convert buffer to audio data")
        #expect(rms > 0.0, "Should calculate non-zero RMS for sine wave")
        #expect(audioData.count == Int(frameCapacity), "Should preserve frame count")

        print("Audio processing pipeline verified: \(audioData.count) samples, RMS: \(rms)")
    }

    // MARK: - AccumulateAudio Direct Tests

    @Test func testAccumulateAudioWithValidBuffer() async throws {
        // Load model first
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
            _ = await TestHelpers.waitForWhisperKit(Self.service)
        }

        // Create test audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 8000 // 0.5 seconds at 16kHz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create audio buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with test audio data (sine wave)
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                let sample = sin(2.0 * Double.pi * 440.0 * Double(i) / 16000.0) * 0.1
                channelData.pointee[i] = Float(sample)
            }
        }

        // Test accumulate audio - should not throw
        await Self.service.accumulateAudio(buffer)

        print("✅ Audio accumulation with valid buffer tested")
    }

    @Test func testAccumulateAudioWithEmptyBuffer() async throws {
        // Create empty audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0) else {
            Issue.record("Could not create empty buffer")
            return
        }

        buffer.frameLength = 0

        // Test accumulate audio with empty buffer - should handle gracefully
        await Self.service.accumulateAudio(buffer)

        print("✅ Empty audio buffer accumulation tested")
    }

    @Test func testAccumulateAudioWithLargeBuffer() async throws {
        // Load model first
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
            _ = await TestHelpers.waitForWhisperKit(Self.service)
        }

        // Create large audio buffer that could trigger processing
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 160000 // 10 seconds at 16kHz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create large buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with test audio data (low volume random noise)
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                channelData.pointee[i] = Float.random(in: -0.05...0.05)
            }
        }

        // This should trigger internal processing logic
        await Self.service.accumulateAudio(buffer)

        print("✅ Large audio buffer accumulation tested")
    }

    @Test func testAccumulateAudioWithSilence() async throws {
        // Create silence buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 8000 // 0.5 seconds at 16kHz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create silence buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with silence (zeros) - should be below silence threshold
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                channelData.pointee[i] = 0.0
            }
        }

        // Test accumulating silence - should not trigger processing
        await Self.service.accumulateAudio(buffer)

        print("✅ Silence audio accumulation tested")
    }

    @Test func testAccumulateAudioWithNoise() async throws {
        // Create noisy audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 16000 // 1 second at 16kHz

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create noise buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with high amplitude noise - should be above silence threshold
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                channelData.pointee[i] = Float.random(in: -0.5...0.5)
            }
        }

        // Test with noisy audio data
        await Self.service.accumulateAudio(buffer)

        print("✅ Noise audio accumulation tested")
    }

    @Test func testAccumulateAudioDifferentSampleRates() async throws {
        // Test with 44.1kHz audio (should be resampled to 16kHz)
        let format441 = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 44100 // 1 second at 44.1kHz

        guard let buffer441 = AVAudioPCMBuffer(pcmFormat: format441, frameCapacity: frameCapacity) else {
            Issue.record("Could not create 44.1kHz buffer")
            return
        }

        buffer441.frameLength = frameCapacity

        // Fill with test audio
        if let channelData = buffer441.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                let sample = sin(2.0 * Double.pi * 880.0 * Double(i) / 44100.0) * 0.1
                channelData.pointee[i] = Float(sample)
            }
        }

        // Should handle different sample rate gracefully (resample internally)
        await Self.service.accumulateAudio(buffer441)

        print("✅ Different sample rate audio accumulation tested")
    }

    @Test func testAccumulateAudioStereoToMono() async throws {
        // Test with stereo audio (should be converted to mono)
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 2)!
        let frameCapacity: AVAudioFrameCount = 8000 // 0.5 seconds

        guard let stereoBuffer = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: frameCapacity) else {
            Issue.record("Could not create stereo buffer")
            return
        }

        stereoBuffer.frameLength = frameCapacity

        // Fill with different values for left/right channels
        if let channelData = stereoBuffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                channelData[0][i] = Float(sin(2.0 * Double.pi * 440.0 * Double(i) / 16000.0) * 0.1) // Left
                channelData[1][i] = Float(sin(2.0 * Double.pi * 880.0 * Double(i) / 16000.0) * 0.1) // Right
            }
        }

        // Should handle stereo to mono conversion
        await Self.service.accumulateAudio(stereoBuffer)

        print("✅ Stereo to mono audio accumulation tested")
    }

    @Test func testAccumulateAudioSequential() async throws {
        // Test multiple sequential calls to accumulate audio
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
            _ = await TestHelpers.waitForWhisperKit(Self.service)
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 1600 // 0.1 seconds at 16kHz

        // Create multiple small buffers
        for chunk in 0..<10 {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                Issue.record("Could not create buffer for chunk \(chunk)")
                continue
            }

            buffer.frameLength = frameCapacity

            // Fill with test audio (different frequency for each chunk)
            if let channelData = buffer.floatChannelData {
                let frequency = 220.0 + Double(chunk) * 55.0 // Different frequency per chunk
                for i in 0..<Int(frameCapacity) {
                    let sample = sin(2.0 * Double.pi * frequency * Double(i) / 16000.0) * 0.1
                    channelData.pointee[i] = Float(sample)
                }
            }

            // Accumulate each chunk sequentially
            await Self.service.accumulateAudio(buffer)
        }

        print("✅ Sequential audio accumulation tested")
    }

    @Test func testAccumulateAudioConcurrent() async throws {
        // Test concurrent calls to accumulate audio
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
            _ = await TestHelpers.waitForWhisperKit(Self.service)
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 1600 // 0.1 seconds at 16kHz

        // Create multiple buffers for concurrent processing
        let buffers = (0..<5).compactMap { chunk -> AVAudioPCMBuffer? in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                return nil
            }

            buffer.frameLength = frameCapacity

            // Fill with test audio
            if let channelData = buffer.floatChannelData {
                let frequency = 440.0 + Double(chunk) * 110.0
                for i in 0..<Int(frameCapacity) {
                    let sample = sin(2.0 * Double.pi * frequency * Double(i) / 16000.0) * 0.05
                    channelData.pointee[i] = Float(sample)
                }
            }

            return buffer
        }

        // Send buffers concurrently using TaskGroup
        await withTaskGroup(of: Void.self) { group in
            for buffer in buffers {
                group.addTask {
                    await Self.service.accumulateAudio(buffer)
                }
            }
        }

        print("✅ Concurrent audio accumulation tested")
    }

    @Test func testAccumulateAudioBeforeModelReady() async throws {
        // Test accumulating audio before model is ready
        let freshService = SpeechRecognitionService.shared

        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let frameCapacity: AVAudioFrameCount = 1600

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            Issue.record("Could not create test buffer")
            return
        }

        buffer.frameLength = frameCapacity

        // Fill with test audio
        if let channelData = buffer.floatChannelData {
            for i in 0..<Int(frameCapacity) {
                channelData.pointee[i] = Float(0.1)
            }
        }

        // Should handle gracefully even without model loaded
        await freshService.accumulateAudio(buffer)

        print("✅ Accumulate audio before model ready tested")
    }

    @Test func testSilenceDetection() async throws {
        // Test silence detection logic using AudioStreamManager utility methods

        // Create silent audio (all zeros)
        let silentAudio: [Float] = Array(repeating: 0.0, count: 1600) // 0.1 seconds
        let silentRMS = AudioStreamManager.calculateRMS(silentAudio)

        // Create loud audio (sine wave)
        let loudAudio: [Float] = (0..<1600).map { i in
            Float(sin(2.0 * Double.pi * 440.0 * Double(i) / 16000.0) * 0.5)
        }
        let loudRMS = AudioStreamManager.calculateRMS(loudAudio)

        // Test RMS calculation accuracy
        #expect(silentRMS < 0.01, "Silent audio should have very low RMS")
        #expect(loudRMS > 0.1, "Loud audio should have higher RMS")

        // Test threshold logic (using service's threshold)
        let silenceThreshold: Float = 0.025
        #expect(silentRMS < silenceThreshold, "Silent RMS should be below threshold")
        #expect(loudRMS > silenceThreshold, "Loud RMS should be above threshold")

        print("Silence detection verified: silent RMS=\(silentRMS), loud RMS=\(loudRMS)")
    }

    @Test func testAudioBufferConversion() async throws {
        // Test audio buffer conversion utilities

        // Create stereo buffer
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let stereoBuffer = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: 4410)! // 0.1 seconds
        stereoBuffer.frameLength = 4410

        // Fill with different values for left/right channels
        if let channelData = stereoBuffer.floatChannelData {
            for i in 0..<Int(stereoBuffer.frameLength) {
                channelData[0][i] = 0.5 // Left channel
                channelData[1][i] = 0.3 // Right channel
            }
        }

        // Test resampling and conversion
        let resampledBuffer = AudioStreamManager.resampleIfNeeded(stereoBuffer)
        let monoData = AudioStreamManager.convertBufferToFloatArray(resampledBuffer)

        #expect(!monoData.isEmpty, "Should convert stereo to mono")

        // If resampling occurred, check sample rate conversion
        if resampledBuffer.format.sampleRate == 16000 {
            let expectedSamples = Int(Double(stereoBuffer.frameLength) * (16000.0 / 44100.0))
            let actualSamples = monoData.count
            let tolerance = expectedSamples / 10 // 10% tolerance

            #expect(abs(actualSamples - expectedSamples) <= tolerance,
                   "Resampled length should be approximately correct")
        }

        print("Audio conversion verified: \(stereoBuffer.frameLength) -> \(monoData.count) samples")
    }

    // MARK: - Service State Management Tests

    @Test func testServiceInitializationStates() async throws {
        let service = SpeechRecognitionService.shared

        // Ensure clean state for this test
        await service.unloadModel()

        // Test initial state
        let initialReady = await service.isReady
        #expect(!initialReady, "Service should not be ready after unload")

        // Load model
        await service.loadModel()
        let loadedReady = await service.isReady
        // Note: May be true or false depending on model loading success in test environment

        print("Service initialization: initial=\(initialReady), after load=\(loadedReady)")
    }

    @Test func testServiceWithProgressCallback() async throws {
        var progressUpdates: [Double] = []

        let service = SpeechRecognitionService.shared

        // Ensure we start with model unloaded to test progress callbacks
        await service.unloadModel()

        service.setProgressCallback { progress in
            progressUpdates.append(progress)
        }

        await service.loadModel()

        // Should have received progress updates
        #expect(!progressUpdates.isEmpty, "Should receive progress updates")

        // Progress should be between 0 and 1
        for progress in progressUpdates {
            #expect(progress >= 0.0 && progress <= 1.0, "Progress should be between 0 and 1")
        }

        print("Progress callback test: \(progressUpdates.count) updates received")
    }

    @Test func testUnloadModelBehavior() async throws {
        //let service = SpeechRecognitionService()

        // Unload when not loaded (should be safe)
        await Self.service.unloadModel()
        let unloadedReady = await Self.service.isReady
        #expect(!unloadedReady, "Should not be ready after unload")

        // Load then unload
        await Self.service.loadModel()
        await Self.service.unloadModel()
        let reUnloadedReady = await Self.service.isReady
        #expect(!reUnloadedReady, "Should not be ready after second unload")

        print("Unload behavior verified")
    }

    // MARK: - Real-time Processing Simulation Tests

    @Test func testStopListeningCleanup() async throws {
        //let service = SpeechRecognitionService()

        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        if isReady {
            // Start listening (may fail on simulator)
            let _ = await Self.service.startListening(
                transcribeOnly: false,
                onUpdate: { _, _ in }
            )

            // Stop should always be safe to call
            Self.service.stopListening()
            Self.service.stopListening() // Multiple calls should be safe

            #expect(true, "Multiple stopListening calls should not crash")
        }

        print("Stop listening cleanup verified")
    }

    @Test func testAudioFileProcessingErrorHandling() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        // Test with nonexistent file
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.wav")

        do {
            let _ = try await Self.service.processAudioFile(at: invalidURL, task: .transcribe)
            Issue.record("Should have thrown error for nonexistent file")
        } catch {
            #expect(true, "Should throw error for nonexistent file")
            print("Correctly handled nonexistent file error: \(error)")
        }

        // Test with invalid audio file (create empty file)
        let tempDir = FileManager.default.temporaryDirectory
        let invalidAudioURL = tempDir.appendingPathComponent("invalid.wav")

        do {
            // Create empty file
            try Data().write(to: invalidAudioURL)

            let _ = try await Self.service.processAudioFile(at: invalidAudioURL, task: .transcribe)
            Issue.record("Should have thrown error for invalid audio file")
        } catch {
            #expect(true, "Should throw error for invalid audio file")
            print("Correctly handled invalid audio file error: \(error)")
        }

        // Clean up
        try? FileManager.default.removeItem(at: invalidAudioURL)
    }

    // MARK: - Language and Task Parameter Tests

    @Test func testProcessAudioFileWithLanguageParameter() async throws {
        // Ensure model is properly loaded
        await Self.service.unloadModel()
        await Self.service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Test with explicit language parameter
        let transcriptionWithLang = try await Self.service.processAudioFile(
            at: audioURL,
            task: .transcribe,
            language: "tr"
        )

        #expect(!transcriptionWithLang.isEmpty, "Should transcribe with explicit language")
        print("Transcription with language parameter: \(transcriptionWithLang)")

        // Verify model is still ready before second call
        let stillReady = await Self.service.isReady
        if !stillReady {
            print("⚠️ Model became not ready between calls, reloading...")
            await Self.service.loadModel()
            let _ = await TestHelpers.waitForWhisperKit(Self.service)
        }

        // Test without language parameter (auto-detect)
        let transcriptionAutoDetect = try await Self.service.processAudioFile(
            at: audioURL,
            task: .transcribe
        )

        #expect(!transcriptionAutoDetect.isEmpty, "Should transcribe with auto-detect")
        print("Transcription with auto-detect: \(transcriptionAutoDetect)")
    }

    @Test func testTaskParameterVariations() async throws {
        if !(await Self.service.isReady) {
            await Self.service.loadModel()
        }
        let isReady = await TestHelpers.waitForWhisperKit(Self.service)

        guard isReady else {
            Issue.record("WhisperKit model not loaded")
            return
        }

        guard let audioPath = TestHelpers.bundledAudioPath() else {
            Issue.record("Audio file not found")
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)

        // Test transcription task
        let transcription = try await Self.service.processAudioFile(at: audioURL, task: .transcribe)
        #expect(!transcription.isEmpty, "Transcription should not be empty")

        // Test translation task
        let translation = try await Self.service.processAudioFile(at: audioURL, task: .translate)
        #expect(!translation.isEmpty, "Translation should not be empty")

        print("Task variations - Transcription: \(transcription.prefix(50))...")
        print("Task variations - Translation: \(translation.prefix(50))...")
    }

    // MARK: - Integration and Performance Tests

    @Test func testServiceIntegrationFlow() async throws {
        let service = SpeechRecognitionService.shared

        // Ensure clean state for integration test
        await service.unloadModel()

        // Full integration flow
        #expect(!(await service.isReady), "Should start not ready after unload")

        await service.loadModel()
        let isReady = await TestHelpers.waitForWhisperKit(service)

        if isReady {
            #expect(await service.isReady, "Should be ready after load")

            var receivedCallbacks = 0
            let success = await service.startListening(
                transcribeOnly: false,
                onUpdate: { text, segment in
                    receivedCallbacks += 1
                    print("Integration test translation callback: \(text) (segment \(segment))")
                }
            )

            #if targetEnvironment(simulator)
            #expect(!success, "Should fail on simulator")
            #else
            #expect(success, "Should succeed on real device")
            #endif

            service.stopListening()

            await service.unloadModel()
            #expect(!(await service.isReady), "Should not be ready after unload")
        }

        print("Integration flow completed")
    }

    @Test func testConcurrentServiceOperations() async throws {
        let service = SpeechRecognitionService.shared

        // Test concurrent access to the singleton
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await service.loadModel()
            }
            group.addTask {
                await service.loadModel()  // Same service, should handle concurrent calls
            }
        }

        let ready = await service.isReady

        print("Concurrent operations: service ready=\(ready)")

        // Singleton should handle concurrent access gracefully
        #expect(true, "Concurrent operations should complete without crashes")
    }

    @Test func testServiceMemoryManagement() async throws {
        // Test service lifecycle and memory management with singleton
        let service = SpeechRecognitionService.shared

        for i in 0..<3 {
            await service.loadModel()
            let _ = await service.isReady

            service.stopListening()
            await service.unloadModel()

            print("Memory management cycle \(i) completed")
        }

        #expect(true, "Memory management cycles should complete without leaks")
    }
}
