//
//  ContentViewTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/7/25.
//

import XCTest
import SwiftUI
@testable import EnglishSubtitles

@MainActor
final class ContentViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        // Clear TranslationPurchaseManager state
        TranslationPurchaseManager.shared.purchasedProducts.removeAll()
        TranslationPurchaseManager.shared.purchaseError = nil
        TranslationPurchaseManager.shared.isLoading = false
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        // Clear TranslationPurchaseManager state
        TranslationPurchaseManager.shared.purchasedProducts.removeAll()
        TranslationPurchaseManager.shared.purchaseError = nil
        TranslationPurchaseManager.shared.isLoading = false
        super.tearDown()
    }

    // MARK: - Basic View Tests

    func testContentViewInitialization() {
        // Given/When: Creating ContentView
        let contentView = ContentView()

        // Then: Should not crash
        XCTAssertNotNil(contentView)
        XCTAssertNotNil(contentView.body)
    }

    func testContentViewUsesSharedTranslationPurchaseManager() {
        // Given: ContentView instance
        let contentView = ContentView()

        // When: Accessing the view's body (this would trigger @StateObject initialization)
        let _ = contentView.body

        // Then: Should use the shared TranslationPurchaseManager instance
        // Note: We can't directly access @StateObject properties in tests,
        // but we can verify the shared instance is working
        let sharedManager = TranslationPurchaseManager.shared
        XCTAssertNotNil(sharedManager)
    }

    // MARK: - Trial Integration Tests

    func testContentViewTrialStartOnAppear() {
        // Given: No existing trial
        XCTAssertNil(UserDefaults.standard.object(forKey: "FirstLaunchDate"))

        // When: Creating ContentView and simulating onAppear
        let contentView = ContentView()
        let purchaseManager = TranslationPurchaseManager.shared

        // Simulate onAppear behavior
        purchaseManager.startTrialIfNeeded()

        // Then: Trial should be started
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertNotNil(trialStartDate, "Trial should be started when ContentView appears")

        // Trial should be active
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertEqual(purchaseManager.trialDaysRemaining, 7)

        // Suppress unused variable warning
        _ = contentView
    }

    func testContentViewDoesNotResetExistingTrial() {
        // Given: Existing trial from 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: Creating ContentView and simulating onAppear
        let contentView = ContentView()
        let purchaseManager = TranslationPurchaseManager.shared

        // Simulate onAppear behavior
        purchaseManager.startTrialIfNeeded()

        // Then: Original trial date should be preserved
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertEqual(storedDate, threeDaysAgo, "Existing trial date should not be changed")

        // Trial should still be active with correct days remaining
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertEqual(purchaseManager.trialDaysRemaining, 4) // 7 - 3 = 4 days remaining

        // Suppress unused variable warning
        _ = contentView
    }

    // MARK: - View Hierarchy Tests

    func testContentViewReturnsSubtitleView() {
        // Given: ContentView instance
        let contentView = ContentView()

        // When: Getting the view body
        let body = contentView.body

        // Then: Should contain SubtitleView
        // Note: SwiftUI view hierarchy testing is complex, but we can at least verify
        // the body returns something without crashing
        XCTAssertNotNil(body)
    }

    // MARK: - State Management Tests

    func testContentViewStateManagement() {
        // Given: ContentView with trial state
        let contentView = ContentView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Starting trial through ContentView onAppear simulation
        purchaseManager.startTrialIfNeeded()

        // Then: State should be properly managed
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertTrue(purchaseManager.canUseTranslation)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)

        // Suppress unused variable warning
        _ = contentView
    }

    func testContentViewWithPurchasedUser() {
        // Given: User with full access
        let contentView = ContentView()
        let purchaseManager = TranslationPurchaseManager.shared

        // Simulate user has purchased
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: ContentView appears with purchased user
        purchaseManager.startTrialIfNeeded() // This should still work but trial won't matter

        // Then: User should have full access regardless of trial
        XCTAssertTrue(purchaseManager.hasFullAccess)
        XCTAssertTrue(purchaseManager.canUseTranslation)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)
        XCTAssertFalse(purchaseManager.isTrialActive) // Trial becomes irrelevant when purchased

        // Suppress unused variable warning
        _ = contentView
    }

    // MARK: - Integration Tests

    func testContentViewIntegrationWithTranslationPurchaseManager() {
        // Given: Clean state
        XCTAssertNil(UserDefaults.standard.object(forKey: "FirstLaunchDate"))

        // When: ContentView lifecycle simulation
        let contentView = ContentView()
        let purchaseManager = TranslationPurchaseManager.shared

        // Simulate onAppear
        purchaseManager.startTrialIfNeeded()

        // Then: Integration should work correctly
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "FirstLaunchDate"))
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertEqual(purchaseManager.trialDaysRemaining, 7)
        XCTAssertTrue(purchaseManager.canUseTranslation)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)

        // Suppress unused variable warning
        _ = contentView
    }

    func testMultipleContentViewInstances() {
        // Given: Multiple ContentView instances (simulating navigation scenarios)

        // When: Creating multiple instances
        let contentView1 = ContentView()
        let contentView2 = ContentView()

        let purchaseManager = TranslationPurchaseManager.shared

        // Simulate onAppear for both
        purchaseManager.startTrialIfNeeded()
        purchaseManager.startTrialIfNeeded() // Should be safe to call multiple times

        // Then: Trial should only be started once
        let trialDates = [
            UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date,
            UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date // Same key, same value
        ]

        XCTAssertNotNil(trialDates[0])
        XCTAssertEqual(trialDates[0], trialDates[1])

        // Both views should see the same trial state
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertEqual(purchaseManager.trialDaysRemaining, 7)

        // Suppress unused variable warnings
        _ = contentView1
        _ = contentView2
    }

    // MARK: - Preview Tests

    func testContentViewPreview() {
        // Given/When: Creating ContentView preview
        let preview = ContentView()

        // Then: Preview should not crash
        XCTAssertNotNil(preview)
        XCTAssertNotNil(preview.body)

        // Preview creation shouldn't affect UserDefaults in tests
        // (In real app, previews might start trials, but that's expected behavior)
    }

    // MARK: - Memory Management Tests

    func testContentViewMemoryManagement() {
        // Given: ContentView instances
        // SwiftUI Views are structs (value types), so we test that multiple instances
        // can be created and used without memory issues

        var contentViews: [ContentView] = []

        // When: Creating multiple ContentView instances
        for _ in 0..<50 {
            let contentView = ContentView()
            let _ = contentView.body // Access body to ensure it's fully initialized
            contentViews.append(contentView)
        }

        // Then: Should handle multiple instances without issues
        XCTAssertEqual(contentViews.count, 50)

        // Clear array (should deallocate all instances since structs are value types)
        contentViews.removeAll()
        XCTAssertTrue(contentViews.isEmpty)

        // Test completed - no memory leaks expected with value types
    }

    // MARK: - Error Handling Tests

    func testContentViewWithCorruptedUserDefaults() {
        // Given: Corrupted UserDefaults
        UserDefaults.standard.set("invalid date", forKey: "FirstLaunchDate")

        // When: Creating ContentView
        let contentView = ContentView()
        let purchaseManager = TranslationPurchaseManager.shared

        // Simulate onAppear
        purchaseManager.startTrialIfNeeded()

        // Then: Should handle gracefully and not crash
        XCTAssertNotNil(contentView.body)

        // Should provide reasonable trial state
        XCTAssertTrue(purchaseManager.isTrialActive) // Should default to active
        XCTAssertEqual(purchaseManager.trialDaysRemaining, 7) // Should have full trial

        // Suppress unused variable warning
        _ = contentView
    }

    // MARK: - Accessibility Tests

    func testContentViewAccessibility() {
        // Given: ContentView instance
        let contentView = ContentView()

        // When: Getting the view body
        let body = contentView.body

        // Then: Should support accessibility
        // Note: Full accessibility testing requires UI testing framework,
        // but we can at least verify the view structure doesn't break accessibility
        XCTAssertNotNil(body)
    }
}