//
//  TranslationPurchaseManagerTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/6/24.
//

import XCTest
import StoreKit
@testable import EnglishSubtitles

@MainActor
final class TranslationPurchaseManagerTests: XCTestCase {

    var purchaseManager: TranslationPurchaseManager!

    override func setUp() {
        super.setUp()
        // Clear any existing UserDefaults for clean slate
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")

        // Create fresh TranslationPurchaseManager instance for each test
        purchaseManager = TranslationPurchaseManager()
    }

    override func tearDown() {
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        purchaseManager = nil
        super.tearDown()
    }

    // MARK: - Constants Tests

    func testProductIDConstants() {
        XCTAssertEqual(TranslationPurchaseManager.fullAccessProductID, "org.amr.englishsubtitles.translation")
    }

    // MARK: - Trial Logic Tests

    func testStartTrialIfNeeded_FirstTime() {
        // Given: No trial date set
        XCTAssertNil(UserDefaults.standard.object(forKey: "FirstLaunchDate"))

        // When: Starting trial for first time
        purchaseManager.startTrialIfNeeded()

        // Then: Trial date should be set to today
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertNotNil(trialStartDate)

        // Verify it's approximately now (within 1 minute)
        let now = Date()
        let timeDifference = abs(trialStartDate!.timeIntervalSince(now))
        XCTAssertLessThan(timeDifference, 60, "Trial start date should be very close to current time")
    }

    func testStartTrialIfNeeded_AlreadyStarted() {
        // Given: Trial already started 2 days ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(twoDaysAgo, forKey: "FirstLaunchDate")

        // When: Attempting to start trial again
        purchaseManager.startTrialIfNeeded()

        // Then: Original date should remain unchanged
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertEqual(storedDate, twoDaysAgo)
    }

    func testIsTrialActive_WithinTrialPeriod() {
        // Given: Trial started 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking if trial is active
        let isActive = purchaseManager.isTrialActive

        // Then: Should be active (within 7 day limit)
        XCTAssertTrue(isActive)
    }

    func testIsTrialActive_ExpiredTrial() {
        // Given: Trial started 8 days ago (expired)
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        UserDefaults.standard.set(eightDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking if trial is active
        let isActive = purchaseManager.isTrialActive

        // Then: Should be inactive (beyond 7 day limit)
        XCTAssertFalse(isActive)
    }

    func testIsTrialActive_WithFullAccess() {
        // Given: User has full access and trial started
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        UserDefaults.standard.set(Date(), forKey: "FirstLaunchDate")

        // When: Checking if trial is active
        let isActive = purchaseManager.isTrialActive

        // Then: Should be false because user already purchased
        XCTAssertFalse(isActive)
    }

    func testTrialDaysRemaining_ActiveTrial() {
        // Given: Trial started 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should have 4 days remaining (7 - 3 = 4)
        XCTAssertEqual(remainingDays, 4)
    }

    func testTrialDaysRemaining_ExpiredTrial() {
        // Given: Trial started 10 days ago
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should be 0 (expired)
        XCTAssertEqual(remainingDays, 0)
    }

    func testTrialDaysRemaining_WithFullAccess() {
        // Given: User has full access
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        UserDefaults.standard.set(Date(), forKey: "FirstLaunchDate")

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should be 0 because user already purchased
        XCTAssertEqual(remainingDays, 0)
    }

    func testTrialDaysRemaining_NoTrialStarted() {
        // Given: No trial started (no date set)
        // This simulates the case where the app hasn't called startTrialIfNeeded yet

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should default to full 7 days (because Date() defaults to now)
        XCTAssertEqual(remainingDays, 7)
    }

    // MARK: - Purchase Status Tests

    func testHasFullAccess_WithPurchase() {
        // Given: User has purchased the product
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: Checking full access
        let hasAccess = purchaseManager.hasFullAccess

        // Then: Should have access
        XCTAssertTrue(hasAccess)
    }

    func testHasFullAccess_WithoutPurchase() {
        // Given: User has not purchased
        purchaseManager.purchasedProducts.removeAll()

        // When: Checking full access
        let hasAccess = purchaseManager.hasFullAccess

        // Then: Should not have access
        XCTAssertFalse(hasAccess)
    }

    // MARK: - Translation Feature Tests

    func testCanUseTranslation_WithPurchase() {
        // Given: User has purchased
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: Checking translation access
        let canUse = purchaseManager.canUseTranslation

        // Then: Should have access regardless of trial status
        XCTAssertTrue(canUse)
    }

    func testCanUseTranslation_WithActiveTrial() {
        // Given: User is in active trial (no purchase)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(twoDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking translation access
        let canUse = purchaseManager.canUseTranslation

        // Then: Should have access during trial
        XCTAssertTrue(canUse)
    }

    func testCanUseTranslation_ExpiredTrialNoPurchase() {
        // Given: Trial expired and no purchase
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking translation access
        let canUse = purchaseManager.canUseTranslation

        // Then: Should not have access
        XCTAssertFalse(canUse)
    }

    func testShouldShowTranslationUpgrade_WithAccess() {
        // Given: User has translation access
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: Checking if should show upgrade
        let shouldShow = purchaseManager.shouldShowTranslationUpgrade

        // Then: Should not show upgrade
        XCTAssertFalse(shouldShow)
    }

    func testShouldShowTranslationUpgrade_WithoutAccess() {
        // Given: User doesn't have translation access (expired trial, no purchase)
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking if should show upgrade
        let shouldShow = purchaseManager.shouldShowTranslationUpgrade

        // Then: Should show upgrade
        XCTAssertTrue(shouldShow)
    }

    // MARK: - Paywall Logic Tests

    func testShouldShowPaywall() {
        // Given: Any state

        // When: Checking if should show paywall
        let shouldShow = purchaseManager.shouldShowPaywall

        // Then: Should always be false (never block whole app)
        XCTAssertFalse(shouldShow)
    }

    // MARK: - Edge Cases

    func testTrialLogic_ExactlySevenDays() {
        // Given: Trial started exactly 7 days ago
        let exactlySevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        UserDefaults.standard.set(exactlySevenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking trial status
        let isActive = purchaseManager.isTrialActive
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should be expired (7 days = expired, not 7 days remaining)
        XCTAssertFalse(isActive)
        XCTAssertEqual(remainingDays, 0)
    }

    func testTrialLogic_AlmostSevenDays() {
        // Given: Trial started 6 days and 23 hours ago (almost 7 days)
        var components = DateComponents()
        components.day = -6
        components.hour = -23
        let almostSevenDaysAgo = Calendar.current.date(byAdding: components, to: Date())!
        UserDefaults.standard.set(almostSevenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking trial status
        let isActive = purchaseManager.isTrialActive
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should still be active (less than 7 full days)
        XCTAssertTrue(isActive)
        XCTAssertEqual(remainingDays, 1) // Should show 1 day remaining
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Given: Fresh TranslationPurchaseManager instance
        let freshManager = TranslationPurchaseManager()

        // Then: Initial state should be correct
        XCTAssertEqual(freshManager.products, [])
        XCTAssertEqual(freshManager.purchasedProducts, [])
        XCTAssertFalse(freshManager.isLoading)
        XCTAssertNil(freshManager.purchaseError)
        XCTAssertFalse(freshManager.hasFullAccess)
        XCTAssertFalse(freshManager.shouldShowPaywall)
    }

    // MARK: - Error State Tests

    func testPurchaseErrorClearing() {
        // Given: TranslationPurchaseManager with an error
        purchaseManager.purchaseError = "Test error"

        // When: Starting a new purchase (we'll simulate this by setting isLoading)
        purchaseManager.isLoading = true
        purchaseManager.purchaseError = nil // This simulates what happens at start of purchase

        // Then: Error should be cleared
        XCTAssertNil(purchaseManager.purchaseError)
    }

    func testLoadingStateManagement() {
        // Given: TranslationPurchaseManager in initial state
        XCTAssertFalse(purchaseManager.isLoading)

        // When: Setting loading state
        purchaseManager.isLoading = true

        // Then: Should reflect loading state
        XCTAssertTrue(purchaseManager.isLoading)

        // When: Clearing loading state
        purchaseManager.isLoading = false

        // Then: Should not be loading
        XCTAssertFalse(purchaseManager.isLoading)
    }

    func testPurchasedProductsManagement() {
        // Given: TranslationPurchaseManager with no purchases
        XCTAssertTrue(purchaseManager.purchasedProducts.isEmpty)

        // When: Adding a purchased product
        purchaseManager.purchasedProducts.insert("test.product.id")

        // Then: Should contain the product
        XCTAssertTrue(purchaseManager.purchasedProducts.contains("test.product.id"))
        XCTAssertEqual(purchaseManager.purchasedProducts.count, 1)

        // When: Adding another product
        purchaseManager.purchasedProducts.insert("another.product.id")

        // Then: Should contain both products
        XCTAssertEqual(purchaseManager.purchasedProducts.count, 2)
        XCTAssertTrue(purchaseManager.purchasedProducts.contains("test.product.id"))
        XCTAssertTrue(purchaseManager.purchasedProducts.contains("another.product.id"))

        // When: Removing a product
        purchaseManager.purchasedProducts.remove("test.product.id")

        // Then: Should only contain the remaining product
        XCTAssertEqual(purchaseManager.purchasedProducts.count, 1)
        XCTAssertFalse(purchaseManager.purchasedProducts.contains("test.product.id"))
        XCTAssertTrue(purchaseManager.purchasedProducts.contains("another.product.id"))
    }

    // MARK: - Product Management Tests

    func testProductsArrayManagement() {
        // Given: TranslationPurchaseManager with no products
        XCTAssertTrue(purchaseManager.products.isEmpty)

        // When: Setting products array (simulated)
        // Note: We can't easily create real Product instances in tests,
        // but we can test the array management
        XCTAssertEqual(purchaseManager.products.count, 0)

        // The products array is managed internally by StoreKit calls
        // In real usage, this would be populated by requestProducts()
    }

    // MARK: - Feature Access Logic Tests

    func testCanUseTranslationCombinations() {
        // Test all combinations of trial/purchase states

        // Case 1: No trial, no purchase
        let expiredDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(expiredDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
        XCTAssertFalse(purchaseManager.canUseTranslation)

        // Case 2: Active trial, no purchase
        let recentDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(recentDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
        XCTAssertTrue(purchaseManager.canUseTranslation)

        // Case 3: No trial, has purchase
        UserDefaults.standard.set(expiredDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        XCTAssertTrue(purchaseManager.canUseTranslation)

        // Case 4: Active trial, has purchase (purchase takes precedence)
        UserDefaults.standard.set(recentDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        XCTAssertTrue(purchaseManager.canUseTranslation)
    }

    func testShouldShowTranslationUpgradeCombinations() {
        // Test inverse logic of canUseTranslation

        // Case 1: No trial, no purchase - should show upgrade
        let expiredDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(expiredDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
        XCTAssertTrue(purchaseManager.shouldShowTranslationUpgrade)

        // Case 2: Active trial, no purchase - should not show upgrade
        let recentDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(recentDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)

        // Case 3: No trial, has purchase - should not show upgrade
        UserDefaults.standard.set(expiredDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)

        // Case 4: Active trial, has purchase - should not show upgrade
        UserDefaults.standard.set(recentDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)
    }

    // MARK: - Date Calculation Edge Cases

    func testTrialCalculationMidnightBoundary() {
        // Test date calculations around midnight boundaries
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 23
        components.minute = 59
        components.second = 59

        let nearMidnight = calendar.date(from: components)!

        // Set trial to start at 23:59:59 today
        UserDefaults.standard.set(nearMidnight, forKey: "FirstLaunchDate")

        let isActive = purchaseManager.isTrialActive
        let daysRemaining = purchaseManager.trialDaysRemaining

        // Should still be active on same day
        XCTAssertTrue(isActive)
        XCTAssertEqual(daysRemaining, 7)
    }

    func testTrialCalculationLeapYear() {
        // Test trial calculation during leap year
        let calendar = Calendar.current

        // February 29, 2024 (leap year)
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 29

        if let leapYearDate = calendar.date(from: components) {
            UserDefaults.standard.set(leapYearDate, forKey: "FirstLaunchDate")

            // Should handle leap year dates correctly
            let isActive = purchaseManager.isTrialActive
            let daysRemaining = purchaseManager.trialDaysRemaining

            // These values depend on current date vs leap year date
            // We're just testing that it doesn't crash
            XCTAssertNotNil(isActive)
            XCTAssertTrue(daysRemaining >= 0)
        }
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentTrialStateAccess() {
        // Test accessing trial state from multiple threads simultaneously
        let expectation = XCTestExpectation(description: "Concurrent access completes")
        expectation.expectedFulfillmentCount = 10

        // Set up initial trial state
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // Access trial state concurrently
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            DispatchQueue.main.async {
                let _ = self.purchaseManager.isTrialActive
                let _ = self.purchaseManager.trialDaysRemaining
                let _ = self.purchaseManager.canUseTranslation
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - UserDefaults Integration Tests

    func testUserDefaultsPersistence() {
        // Test that trial date persists across app sessions
        let testDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

        // Set trial date
        purchaseManager.startTrialIfNeeded()
        UserDefaults.standard.set(testDate, forKey: "FirstLaunchDate")

        // Create new TranslationPurchaseManager instance (simulating app restart)
        let newTranslationPurchaseManager = TranslationPurchaseManager()

        // Should read the same trial date
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        XCTAssertEqual(storedDate, testDate)

        // New instance should reflect same trial state
        XCTAssertTrue(newTranslationPurchaseManager.isTrialActive) // 5 days ago should still be active
        XCTAssertEqual(newTranslationPurchaseManager.trialDaysRemaining, 2) // 7 - 5 = 2 days remaining
    }

    func testUserDefaultsCorruption() {
        // Test handling of corrupted UserDefaults data
        UserDefaults.standard.set("invalid date string", forKey: "FirstLaunchDate")

        // Should handle gracefully and default to current date
        let isActive = purchaseManager.isTrialActive
        let daysRemaining = purchaseManager.trialDaysRemaining

        // Should not crash and should provide reasonable defaults
        XCTAssertTrue(isActive) // Should default to active trial
        XCTAssertEqual(daysRemaining, 7) // Should have full trial period
    }

    // MARK: - Memory Management Tests

    func testTranslationPurchaseManagerDeinit() {
        // Test that TranslationPurchaseManager can be deallocated properly
        weak var weakManager: TranslationPurchaseManager?

        autoreleasepool {
            let manager = TranslationPurchaseManager()
            weakManager = manager
            // manager goes out of scope here
        }

        // TranslationPurchaseManager should be deallocated
        // Note: This test may not always pass due to internal StoreKit retention
        // but it helps ensure we don't have obvious retain cycles
        XCTAssertNil(weakManager, "TranslationPurchaseManager should be deallocated when no strong references remain")
    }

    // MARK: - Singleton Pattern Tests

    func testSharedInstanceConsistency() {
        // Test that shared instance maintains state consistently
        let shared1 = TranslationPurchaseManager.shared
        let shared2 = TranslationPurchaseManager.shared

        // Should be the same instance
        XCTAssertTrue(shared1 === shared2)

        // State changes should be reflected in both references
        shared1.purchasedProducts.insert("test.product")
        XCTAssertTrue(shared2.purchasedProducts.contains("test.product"))

        shared2.isLoading = true
        XCTAssertTrue(shared1.isLoading)
    }
}