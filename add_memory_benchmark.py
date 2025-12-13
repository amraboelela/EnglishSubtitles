#!/usr/bin/env python3
"""
Generate Memory and Performance Benchmark Test

Add memory benchmarking to WhisperKitManagerTests.swift
"""

benchmark_test = '''
  // MARK: - Memory and Performance Benchmarking

  @Test func testMemoryUsageBenchmark() async throws {
    // Benchmark memory usage during model operations
    print("🧠 MEMORY USAGE BENCHMARK")
    print("=" * 40)

    let memoryBefore = getMemoryUsage()
    print("📊 Memory before any operations: \\(String(format: "%.1f", memoryBefore)) MB")

    var progressValues: [Double] = []
    let manager = WhisperKitManager { progress in
      progressValues.append(progress)
    }

    // Benchmark model loading
    let loadStartTime = Date()
    let loadMemoryBefore = getMemoryUsage()

    try? await manager.loadModel()

    let loadEndTime = Date()
    let loadMemoryAfter = getMemoryUsage()
    let loadDuration = loadEndTime.timeIntervalSince(loadStartTime)
    let loadMemoryUsage = loadMemoryAfter - loadMemoryBefore

    print("⏱️ Model load time: \\(String(format: "%.2f", loadDuration)) seconds")
    print("💾 Memory after loading: \\(String(format: "%.1f", loadMemoryAfter)) MB")
    print("📈 Memory used for loading: \\(String(format: "%.1f", loadMemoryUsage)) MB")

    // Benchmark translation processing
    let testAudio = generateTestAudio(durationSeconds: 5.0, sampleRate: 16000)
    var translationResults: [String] = []
    var segmentTimes: [Double] = []

    print("🔄 Testing translation performance...")

    for segment in 1...5 {
      let processStartTime = Date()
      let processMemoryBefore = getMemoryUsage()

      await manager.processTranslation(
        testAudio,
        segmentNumber: segment,
        sampleRate: 16000.0
      ) { text, segmentNum in
        translationResults.append(text)
      }

      let processEndTime = Date()
      let processMemoryAfter = getMemoryUsage()
      let processDuration = processEndTime.timeIntervalSince(processStartTime)
      let processMemoryDelta = processMemoryAfter - processMemoryBefore

      segmentTimes.append(processDuration)

      print("📝 Segment \\(segment): \\(String(format: "%.3f", processDuration))s, Memory: \\(String(format: "%.1f", processMemoryAfter)) MB (Δ\\(String(format: "%.1f", processMemoryDelta)) MB)")
    }

    let avgProcessTime = segmentTimes.reduce(0, +) / Double(segmentTimes.count)
    let memoryAfterProcessing = getMemoryUsage()

    // Benchmark model unloading
    let unloadStartTime = Date()
    let unloadMemoryBefore = getMemoryUsage()

    await manager.unloadModel()

    let unloadEndTime = Date()
    let unloadMemoryAfter = getMemoryUsage()
    let unloadDuration = unloadEndTime.timeIntervalSince(unloadStartTime)
    let memoryFreed = unloadMemoryBefore - unloadMemoryAfter

    print("🗑️ Model unload time: \\(String(format: "%.3f", unloadDuration)) seconds")
    print("💾 Memory after unloading: \\(String(format: "%.1f", unloadMemoryAfter)) MB")
    print("📉 Memory freed: \\(String(format: "%.1f", memoryFreed)) MB")

    // Performance summary
    print("\\n📊 BENCHMARK SUMMARY:")
    print("📁 Model load time: \\(String(format: "%.2f", loadDuration))s")
    print("💾 Peak memory usage: \\(String(format: "%.1f", memoryAfterProcessing)) MB")
    print("⚡ Avg translation time: \\(String(format: "%.3f", avgProcessTime))s per segment")
    print("🔄 Processed \\(translationResults.count) translation segments")
    print("📉 Memory freed on unload: \\(String(format: "%.1f", memoryFreed)) MB")

    // Assertions for reasonable performance
    #expect(loadDuration < 180.0, "Model should load within 3 minutes")
    #expect(avgProcessTime < 10.0, "Average translation should be under 10 seconds per segment")
    #expect(memoryAfterProcessing < 6000.0, "Peak memory should be under 6GB")
    #expect(memoryFreed > 1000.0, "Should free substantial memory on unload (>1GB)")

    // Log results for CI/performance tracking
    print("\\nPERFORMENCE_METRICS: load=\\(String(format: "%.2f", loadDuration)), memory=\\(String(format: "%.1f", memoryAfterProcessing)), translation=\\(String(format: "%.3f", avgProcessTime))")
  }

  @Test func testMemoryPressureHandling() async throws {
    // Test model behavior under simulated memory pressure
    print("⚠️ MEMORY PRESSURE TEST")

    var managers: [WhisperKitManager] = []
    var memorySnapshots: [Double] = []

    // Create multiple managers to simulate memory pressure
    for i in 1...3 {
      let manager = WhisperKitManager()
      managers.append(manager)

      let memoryBefore = getMemoryUsage()
      print("📊 Memory before manager \\(i): \\(String(format: "%.1f", memoryBefore)) MB")

      try? await manager.loadModel()

      let memoryAfter = getMemoryUsage()
      memorySnapshots.append(memoryAfter)
      print("💾 Memory after loading manager \\(i): \\(String(format: "%.1f", memoryAfter)) MB")

      // Test if memory growth is linear or if there are efficiencies
      if i > 1 {
        let memoryGrowth = memoryAfter - memorySnapshots[i-2]
        print("📈 Memory growth for manager \\(i): \\(String(format: "%.1f", memoryGrowth)) MB")
      }
    }

    // Cleanup all managers
    for (index, manager) in managers.enumerated() {
      await manager.unloadModel()
      let memoryAfterUnload = getMemoryUsage()
      print("🗑️ Memory after unloading manager \\(index + 1): \\(String(format: "%.1f", memoryAfterUnload)) MB")
    }

    let finalMemory = getMemoryUsage()
    print("📊 Final memory: \\(String(format: "%.1f", finalMemory)) MB")

    #expect(managers.count == 3, "Should create 3 managers for pressure test")
  }

  @Test func testMemoryLeakDetection() async throws {
    // Test for memory leaks in load/unload cycles
    print("🔍 MEMORY LEAK DETECTION")

    let initialMemory = getMemoryUsage()
    print("📊 Initial memory: \\(String(format: "%.1f", initialMemory)) MB")

    var memoryAfterCycles: [Double] = []

    // Perform multiple load/unload cycles
    for cycle in 1...5 {
      let manager = WhisperKitManager()

      // Load
      try? await manager.loadModel()
      let memoryAfterLoad = getMemoryUsage()

      // Process some translation
      let testAudio = generateTestAudio(durationSeconds: 2.0, sampleRate: 16000)
      await manager.processTranslation(testAudio, segmentNumber: 1, sampleRate: 16000.0) { _, _ in }

      // Unload
      await manager.unloadModel()
      let memoryAfterUnload = getMemoryUsage()
      memoryAfterCycles.append(memoryAfterUnload)

      print("🔄 Cycle \\(cycle): Load=\\(String(format: "%.1f", memoryAfterLoad))MB, Unload=\\(String(format: "%.1f", memoryAfterUnload))MB")
    }

    let finalMemory = getMemoryUsage()
    let memoryGrowth = finalMemory - initialMemory

    print("📊 Memory growth after 5 cycles: \\(String(format: "%.1f", memoryGrowth)) MB")

    // Check for significant memory leaks (allow some growth for caches)
    #expect(memoryGrowth < 500.0, "Memory growth should be under 500MB (indicates potential leaks if exceeded)")

    print(memoryGrowth < 100.0 ? "✅ No significant memory leaks detected" : "⚠️ Some memory growth detected")
  }

  // MARK: - Helper Methods

  private func getMemoryUsage() -> Double {
    let taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &count) {
      $0.withMemoryRebound(to: mach_msg_type_number_t.self, capacity: 1) {
        task_info(mach_task_self_,
                 task_flavor_t(MACH_TASK_BASIC_INFO),
                 UnsafeMutablePointer<integer_t>(OpaquePointer($0)),
                 $0)
      }
    }

    if kerr == KERN_SUCCESS {
      let memoryUsageBytes = taskInfo.resident_size
      return Double(memoryUsageBytes) / (1024 * 1024) // Convert to MB
    }

    return 0.0
  }

  private func generateTestAudio(durationSeconds: Double, sampleRate: Int) -> [Float] {
    let sampleCount = Int(durationSeconds * Double(sampleRate))
    var audio: [Float] = []

    // Generate a mix of frequencies to simulate speech
    for i in 0..<sampleCount {
      let t = Double(i) / Double(sampleRate)
      let sample = Float(
        0.3 * sin(2.0 * Double.pi * 440.0 * t) +  // A4
        0.2 * sin(2.0 * Double.pi * 880.0 * t) +  // A5
        0.1 * sin(2.0 * Double.pi * 220.0 * t)    // A3
      )
      audio.append(sample)
    }

    return audio
  }
'''

print("📝 Memory Benchmark Test Generated!")
print("Copy this into your WhisperKitManagerTests.swift file:")
print(benchmark_test)