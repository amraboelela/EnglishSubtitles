//
//  EnglishSubtitlesAppTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/6/24.
//

import XCTest
import SwiftUI
@testable import EnglishSubtitles

@MainActor
final class EnglishSubtitlesAppTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        super.tearDown()
    }

    func testAppInitialization_StartsTrialOnFirstLaunch() {
        // Given: No previous trial date
        XCTAssertNil(UserDefaults.standard.object(forKey: "FirstLaunchDate"))

        // When: App is initialized
        let app = EnglishSubtitlesApp()

        // Then: Trial should be started
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertNotNil(trialStartDate, "Trial start date should be set when app initializes")

        // Verify it's approximately now (within 1 minute)
        let now = Date()
        let timeDifference = abs(trialStartDate!.timeIntervalSince(now))
        XCTAssertLessThan(timeDifference, 60, "Trial start date should be very close to current time")

        // Suppress unused variable warning
        _ = app
    }

    func testAppInitialization_DoesNotResetExistingTrial() {
        // Given: Trial already started 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: App is initialized again
        let app = EnglishSubtitlesApp()

        // Then: Original trial date should be preserved
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertEqual(storedDate, threeDaysAgo, "Existing trial date should not be changed")

        // Suppress unused variable warning
        _ = app
    }

    func testAppInitialization_TranslationPurchaseManagerSingleton() {
        // Given: App initialization

        // When: App is created
        let app = EnglishSubtitlesApp()

        // Then: Should use the shared TranslationPurchaseManager instance
        let purchaseManager = TranslationPurchaseManager.shared
        XCTAssertNotNil(purchaseManager, "TranslationPurchaseManager.shared should be accessible")

        // Verify trial was started through the shared instance
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertNotNil(trialStartDate, "Shared TranslationPurchaseManager should have started the trial")

        // Suppress unused variable warning
        _ = app
    }

    func testAppBodyReturnsWindowGroup() {
        // Given: App instance
        let app = EnglishSubtitlesApp()

        // When: Getting app body
        let scene = app.body

        // Then: Should return WindowGroup with ContentView
        XCTAssertTrue(scene is WindowGroup<ContentView>, "App body should return WindowGroup containing ContentView")
    }

    // MARK: - Integration Tests

    func testAppInitialization_IntegrationWithTranslationPurchaseManager() {
        // Given: Clean state
        XCTAssertNil(UserDefaults.standard.object(forKey: "FirstLaunchDate"))

        // When: App initializes
        let app = EnglishSubtitlesApp()

        // Then: TranslationPurchaseManager should reflect trial state correctly
        let purchaseManager = TranslationPurchaseManager.shared

        // Trial should be active
        XCTAssertTrue(purchaseManager.isTrialActive, "Trial should be active after app initialization")

        // Should have 7 days remaining
        XCTAssertEqual(purchaseManager.trialDaysRemaining, 7, "Should have full 7 days remaining on first launch")

        // Should be able to use translation during trial
        XCTAssertTrue(purchaseManager.canUseTranslation, "Should be able to use translation during active trial")

        // Should not show upgrade prompt during trial
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade, "Should not show upgrade during active trial")

        // Suppress unused variable warning
        _ = app
    }

    func testMultipleAppInitializations() {
        // Given: Multiple app instances created (simulating app restart)

        // When: Creating multiple instances
        let app1 = EnglishSubtitlesApp()
        let firstTrialDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date

        // Small delay to ensure different timestamps if bug exists
        Thread.sleep(forTimeInterval: 0.001)

        let app2 = EnglishSubtitlesApp()
        let secondTrialDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date

        // Then: Trial date should remain the same
        XCTAssertNotNil(firstTrialDate)
        XCTAssertEqual(firstTrialDate, secondTrialDate, "Trial date should not change on subsequent app initializations")

        // Both instances should see the same trial state
        let purchaseManager = TranslationPurchaseManager.shared
        XCTAssertTrue(purchaseManager.isTrialActive, "Trial should remain active across app initializations")

        // Suppress unused variable warnings
        _ = app1
        _ = app2
    }
}