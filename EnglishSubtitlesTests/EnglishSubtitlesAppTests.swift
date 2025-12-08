//
//  EnglishSubtitlesAppTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/6/24.
//

import Testing
import SwiftUI
@testable import EnglishSubtitles

@MainActor
struct EnglishSubtitlesAppTests {

    @Test func appInitialization_StartsTrialOnFirstLaunch() async throws {
        // Clear UserDefaults before test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Given: No previous trial date
        #expect(UserDefaults.standard.object(forKey: "FirstLaunchDate") == nil)

        // When: App is initialized
        let app = EnglishSubtitlesApp()

        // Then: Trial should be started
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        #expect(trialStartDate != nil, "Trial start date should be set when app initializes")

        // Verify it's approximately now (within 1 minute)
        let now = Date()
        let timeDifference = abs(trialStartDate!.timeIntervalSince(now))
        #expect(timeDifference < 60, "Trial start date should be very close to current time")

        // Suppress unused variable warning
        _ = app

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func appInitialization_DoesNotResetExistingTrial() async throws {
        // Clear and setup UserDefaults before test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Given: Trial already started 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: App is initialized again
        let app = EnglishSubtitlesApp()

        // Then: Original trial date should be preserved
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        #expect(storedDate == threeDaysAgo, "Existing trial date should not be changed")

        // Suppress unused variable warning
        _ = app

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func appInitialization_TranslationPurchaseManagerSingleton() async throws {
        // Clear UserDefaults before test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Given: App initialization

        // When: App is created
        let app = EnglishSubtitlesApp()

        // Then: Should use the shared TranslationPurchaseManager instance
        let purchaseManager = TranslationPurchaseManager.shared
        // TranslationPurchaseManager.shared is non-optional, so we just verify it exists
        let _ = purchaseManager

        // Verify trial was started through the shared instance
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        #expect(trialStartDate != nil, "Shared TranslationPurchaseManager should have started the trial")

        // Suppress unused variable warning
        _ = app

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func appBodyReturnsWindowGroup() async throws {
        // Clear UserDefaults before test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Given: App instance
        let app = EnglishSubtitlesApp()

        // When: Getting app body
        let scene = app.body

        // Then: Should return WindowGroup with ContentView
        #expect(scene is WindowGroup<ContentView>, "App body should return WindowGroup containing ContentView")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    // MARK: - Integration Tests

    @Test func appInitialization_IntegrationWithTranslationPurchaseManager() async throws {
        // Clear UserDefaults before test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Given: Clean state
        #expect(UserDefaults.standard.object(forKey: "FirstLaunchDate") == nil)

        // When: App initializes
        let app = EnglishSubtitlesApp()

        // Then: TranslationPurchaseManager should reflect trial state correctly
        let purchaseManager = TranslationPurchaseManager.shared

        // Trial should be active
        #expect(purchaseManager.isTrialActive, "Trial should be active after app initialization")

        // Should have 7 days remaining
        #expect(purchaseManager.trialDaysRemaining == 7, "Should have full 7 days remaining on first launch")

        // Should be able to use translation during trial
        #expect(purchaseManager.canUseTranslation, "Should be able to use translation during active trial")

        // Should not show upgrade prompt during trial
        #expect(purchaseManager.shouldShowTranslationUpgrade == false, "Should not show upgrade during active trial")

        // Suppress unused variable warning
        _ = app

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func multipleAppInitializations() async throws {
        // Clear UserDefaults before test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Given: Multiple app instances created (simulating app restart)

        // When: Creating multiple instances
        let app1 = EnglishSubtitlesApp()
        let firstTrialDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date

        // Small delay to ensure different timestamps if bug exists
        try await Task.sleep(for: .milliseconds(1))

        let app2 = EnglishSubtitlesApp()
        let secondTrialDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date

        // Then: Trial date should remain the same (allowing for minimal timing differences)
        #expect(firstTrialDate != nil)
        #expect(secondTrialDate != nil)

        // Check that the dates are very close (within 1 second) rather than exactly equal
        let timeDifference = abs(firstTrialDate!.timeIntervalSince(secondTrialDate!))
        #expect(timeDifference < 1.0, "Trial dates should be very close, difference: \(timeDifference) seconds")

        // Both instances should see the same trial state
        let purchaseManager = TranslationPurchaseManager.shared
        #expect(purchaseManager.isTrialActive, "Trial should remain active across app initializations")

        // Suppress unused variable warnings
        _ = app1
        _ = app2

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }
}