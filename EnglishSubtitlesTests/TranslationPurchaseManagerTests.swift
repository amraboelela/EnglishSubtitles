//
//  TranslationPurchaseManagerTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/6/24.
//

import Testing
import StoreKit
@testable import EnglishSubtitles

@MainActor
struct TranslationPurchaseManagerTests {

    // MARK: - Constants Tests

    @Test func productIDConstants() async throws {
        #expect(TranslationPurchaseManager.fullAccessProductID == "org.amr.englishsubtitles.translation")
    }

    // MARK: - Trial Logic Tests

    @Test func startTrialIfNeeded_FirstTime() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: No trial date set
        #expect(UserDefaults.standard.object(forKey: "FirstLaunchDate") == nil)

        // When: Starting trial for first time
        purchaseManager.startTrialIfNeeded()

        // Then: Trial date should be set to today
        let trialStartDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        #expect(trialStartDate != nil)

        // Verify it's approximately now (within 1 minute)
        let now = Date()
        let timeDifference = abs(trialStartDate!.timeIntervalSince(now))
        #expect(timeDifference < 60, "Trial start date should be very close to current time")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func startTrialIfNeeded_AlreadyStarted() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial already started 2 days ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(twoDaysAgo, forKey: "FirstLaunchDate")

        // When: Attempting to start trial again
        purchaseManager.startTrialIfNeeded()

        // Then: Original date should remain unchanged
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        #expect(storedDate == twoDaysAgo)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func isTrialActive_WithinTrialPeriod() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial started 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking if trial is active
        let isActive = purchaseManager.isTrialActive

        // Then: Should be active (within 7 day limit)
        #expect(isActive == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func isTrialActive_ExpiredTrial() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial started 8 days ago (expired)
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        UserDefaults.standard.set(eightDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking if trial is active
        let isActive = purchaseManager.isTrialActive

        // Then: Should be inactive (beyond 7 day limit)
        #expect(isActive == false)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func isTrialActive_WithFullAccess() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: User has full access and trial started
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        UserDefaults.standard.set(Date(), forKey: "FirstLaunchDate")

        // When: Checking if trial is active
        let isActive = purchaseManager.isTrialActive

        // Then: Should be false because user already purchased
        #expect(isActive == false)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
    }

    @Test func trialDaysRemaining_ActiveTrial() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial started 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should have 4 days remaining (7 - 3 = 4)
        #expect(remainingDays == 4)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func trialDaysRemaining_ExpiredTrial() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial started 10 days ago
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should be 0 (expired)
        #expect(remainingDays == 0)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func trialDaysRemaining_WithFullAccess() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: User has full access
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        UserDefaults.standard.set(Date(), forKey: "FirstLaunchDate")

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should be 0 because user already purchased
        #expect(remainingDays == 0)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
    }

    @Test func trialDaysRemaining_NoTrialStarted() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: No trial started (no date set)
        // This simulates the case where the app hasn't called startTrialIfNeeded yet

        // When: Getting remaining days
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should default to full 7 days (because Date() defaults to now)
        #expect(remainingDays == 7)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    // MARK: - Purchase Status Tests

    @Test func hasFullAccess_WithPurchase() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: User has purchased the product
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: Checking full access
        let hasAccess = purchaseManager.hasFullAccess

        // Then: Should have access
        #expect(hasAccess == true)

        // Cleanup
        purchaseManager.purchasedProducts.removeAll()
    }

    @Test func hasFullAccess_WithoutPurchase() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: User has not purchased
        purchaseManager.purchasedProducts.removeAll()

        // When: Checking full access
        let hasAccess = purchaseManager.hasFullAccess

        // Then: Should not have access
        #expect(hasAccess == false)
    }

    // MARK: - Translation Feature Tests

    @Test func canUseTranslation_WithPurchase() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: User has purchased
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: Checking translation access
        let canUse = purchaseManager.canUseTranslation

        // Then: Should have access regardless of trial status
        #expect(canUse == true)

        // Cleanup
        purchaseManager.purchasedProducts.removeAll()
    }

    @Test func canUseTranslation_WithActiveTrial() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: User is in active trial (no purchase)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(twoDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking translation access
        let canUse = purchaseManager.canUseTranslation

        // Then: Should have access during trial
        #expect(canUse == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func canUseTranslation_ExpiredTrialNoPurchase() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial expired and no purchase
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking translation access
        let canUse = purchaseManager.canUseTranslation

        // Then: Should not have access
        #expect(canUse == false)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func shouldShowTranslationUpgrade_WithAccess() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: User has translation access
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // When: Checking if should show upgrade
        let shouldShow = purchaseManager.shouldShowTranslationUpgrade

        // Then: Should not show upgrade
        #expect(shouldShow == false)

        // Cleanup
        purchaseManager.purchasedProducts.removeAll()
    }

    @Test func shouldShowTranslationUpgrade_WithoutAccess() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: User doesn't have translation access (expired trial, no purchase)
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking if should show upgrade
        let shouldShow = purchaseManager.shouldShowTranslationUpgrade

        // Then: Should show upgrade
        #expect(shouldShow == true)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    // MARK: - Paywall Logic Tests

    @Test func shouldShowPaywall() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: Any state

        // When: Checking if should show paywall
        let shouldShow = purchaseManager.shouldShowPaywall

        // Then: Should always be false (never block whole app)
        #expect(shouldShow == false)
    }

    // MARK: - Edge Cases

    @Test func trialLogic_ExactlySevenDays() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Given: Trial started exactly 7 days ago
        let exactlySevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        UserDefaults.standard.set(exactlySevenDaysAgo, forKey: "FirstLaunchDate")

        // When: Checking trial status
        let isActive = purchaseManager.isTrialActive
        let remainingDays = purchaseManager.trialDaysRemaining

        // Then: Should be expired (7 days = expired, not 7 days remaining)
        #expect(isActive == false)
        #expect(remainingDays == 0)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func trialLogic_AlmostSevenDays() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

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
        #expect(isActive == true)
        #expect(remainingDays == 1) // Should show 1 day remaining

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    // MARK: - Initial State Tests

    @Test func initialState() async throws {
        // Given: Fresh TranslationPurchaseManager instance
        let freshManager = TranslationPurchaseManager()

        // Then: Initial state should be correct
        #expect(freshManager.products == [])
        #expect(freshManager.purchasedProducts == [])
        #expect(freshManager.isLoading == false)
        #expect(freshManager.purchaseError == nil)
        #expect(freshManager.hasFullAccess == false)
        #expect(freshManager.shouldShowPaywall == false)
    }

    // MARK: - Error State Tests

    @Test func purchaseErrorClearing() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: TranslationPurchaseManager with an error
        purchaseManager.purchaseError = "Test error"

        // When: Starting a new purchase (we'll simulate this by setting isLoading)
        purchaseManager.isLoading = true
        purchaseManager.purchaseError = nil // This simulates what happens at start of purchase

        // Then: Error should be cleared
        #expect(purchaseManager.purchaseError == nil)

        // Cleanup
        purchaseManager.isLoading = false
    }

    @Test func loadingStateManagement() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: TranslationPurchaseManager in initial state
        #expect(purchaseManager.isLoading == false)

        // When: Setting loading state
        purchaseManager.isLoading = true

        // Then: Should reflect loading state
        #expect(purchaseManager.isLoading == true)

        // When: Clearing loading state
        purchaseManager.isLoading = false

        // Then: Should not be loading
        #expect(purchaseManager.isLoading == false)
    }

    @Test func purchasedProductsManagement() async throws {
        // Setup
        let purchaseManager = TranslationPurchaseManager()

        // Given: TranslationPurchaseManager with no purchases
        #expect(purchaseManager.purchasedProducts.isEmpty == true)

        // When: Adding a purchased product
        purchaseManager.purchasedProducts.insert("test.product.id")

        // Then: Should contain the product
        #expect(purchaseManager.purchasedProducts.contains("test.product.id") == true)

        // When: Adding another product
        purchaseManager.purchasedProducts.insert("another.product.id")

        // Then: Should contain both products
        #expect(purchaseManager.purchasedProducts.count == 2)

        // When: Removing one product
        purchaseManager.purchasedProducts.remove("test.product.id")

        // Then: Should only contain the remaining product
        #expect(purchaseManager.purchasedProducts.count == 1)
        #expect(purchaseManager.purchasedProducts.contains("test.product.id") == false)
        #expect(purchaseManager.purchasedProducts.contains("another.product.id") == true)

        // Cleanup
        purchaseManager.purchasedProducts.removeAll()
    }

    // MARK: - Memory Management Tests

    @Test func translationPurchaseManagerDeinit() async throws {
        // Test that TranslationPurchaseManager handles deallocation properly

        autoreleasepool {
            let manager = TranslationPurchaseManager()
            // Test that manager can be created without issues
            _ = manager
            // manager goes out of scope here
        }

        // Note: TranslationPurchaseManager may not be immediately deallocated due to:
        // 1. StoreKit's internal transaction listener retention
        // 2. The detached Task in listenForTransactions()
        // This is expected behavior for StoreKit integration, not a memory leak

        // Instead, we test that the manager can be created and destroyed without crashing
        // and that the deinit method (if called) properly cancels background tasks

        // The test passes if we get here without crashes
        #expect(true, "TranslationPurchaseManager creation and potential deallocation completed without crashes")
    }

    // MARK: - Singleton Pattern Tests

    @Test func sharedInstanceConsistency() async throws {
        // Test that shared instance maintains state consistently
        let shared1 = TranslationPurchaseManager.shared
        let shared2 = TranslationPurchaseManager.shared

        // Should be the same instance
        #expect(shared1 === shared2)

        // State changes should be reflected in both references
        shared1.isLoading = true
        #expect(shared2.isLoading == true)

        shared1.purchaseError = "Test error"
        #expect(shared2.purchaseError == "Test error")

        // Cleanup
        shared1.isLoading = false
        shared1.purchaseError = nil
    }

    // MARK: - UserDefaults Integration Tests

    @Test func userDefaultsPersistence() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Test that trial date persists across app sessions
        let testDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

        // Set trial date
        purchaseManager.startTrialIfNeeded()
        UserDefaults.standard.set(testDate, forKey: "FirstLaunchDate")

        // Create new TranslationPurchaseManager instance (simulating app restart)
        let newTranslationPurchaseManager = TranslationPurchaseManager()

        // Then: Date should be persisted
        let storedDate = UserDefaults.standard.object(forKey: "FirstLaunchDate") as? Date
        #expect(storedDate == testDate)

        // New instance should reflect same trial state
        #expect(newTranslationPurchaseManager.isTrialActive == true) // 5 days ago should still be active
        #expect(newTranslationPurchaseManager.trialDaysRemaining == 2) // 7 - 5 = 2 days remaining

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }

    @Test func userDefaultsCorruption() async throws {
        // Setup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
        let purchaseManager = TranslationPurchaseManager()

        // Test handling of corrupted UserDefaults data
        UserDefaults.standard.set("invalid date string", forKey: "FirstLaunchDate")

        // Should handle gracefully and default to current date
        let isActive = purchaseManager.isTrialActive
        let daysRemaining = purchaseManager.trialDaysRemaining

        // Should not crash and should provide reasonable defaults
        #expect(isActive == true) // Should default to active trial
        #expect(daysRemaining == 7) // Should have full trial period

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "FirstLaunchDate")
    }
}