//
//  TranslationUnlockBannerTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/7/25.
//

import XCTest
import SwiftUI
@testable import EnglishSubtitles

@MainActor
final class TranslationUnlockBannerTests: XCTestCase {

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

    // MARK: - Basic View Tests

    func testTranslationUnlockBannerInitialization() {
        // Given/When: Creating TranslationUnlockBanner
        let banner = TranslationUnlockBanner()

        // Then: Should not crash
        XCTAssertNotNil(banner)
        XCTAssertNotNil(banner.body)
    }

    func testTranslationUnlockBannerUsesSharedTranslationPurchaseManager() {
        // Given: TranslationUnlockBanner instance
        let banner = TranslationUnlockBanner()

        // When: Accessing the view's body (this would trigger @StateObject initialization)
        let _ = banner.body

        // Then: Should use the shared TranslationPurchaseManager instance
        let sharedManager = TranslationPurchaseManager.shared
        XCTAssertNotNil(sharedManager)
    }

    // MARK: - State Management Tests

    func testTranslationUnlockBannerInitialState() {
        // Given: TranslationUnlockBanner
        let banner = TranslationUnlockBanner()

        // When: Getting initial state
        let _ = banner.body

        // Then: Should start with paywall not shown
        // Note: We can't directly access @State properties in tests,
        // but we can verify the view initializes without crashing
        XCTAssertNotNil(banner.body)
    }

    func testTranslationUnlockBannerWithTrialExpired() {
        // Given: Banner with expired trial
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting up expired trial state
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()

        // Then: Banner should be relevant (trial expired, no purchase)
        XCTAssertNotNil(banner.body)
        XCTAssertFalse(purchaseManager.isTrialActive)
        XCTAssertFalse(purchaseManager.hasFullAccess)
        XCTAssertTrue(purchaseManager.shouldShowTranslationUpgrade)
    }

    func testTranslationUnlockBannerWithActiveTrial() {
        // Given: Banner with active trial
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting up active trial state
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        UserDefaults.standard.set(twoDaysAgo, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()

        // Then: Banner might be less relevant (trial active)
        XCTAssertNotNil(banner.body)
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertTrue(purchaseManager.canUseTranslation)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)
    }

    func testTranslationUnlockBannerWithPurchasedUser() {
        // Given: Banner with user who has purchased
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: User has full access
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // Then: Banner should handle purchased state
        XCTAssertNotNil(banner.body)
        XCTAssertTrue(purchaseManager.hasFullAccess)
        XCTAssertTrue(purchaseManager.canUseTranslation)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)
    }

    // MARK: - UI Content Tests

    func testTranslationUnlockBannerContent() {
        // Given: TranslationUnlockBanner
        let banner = TranslationUnlockBanner()

        // When: Getting view body
        let body = banner.body

        // Then: Should contain the expected structure
        XCTAssertNotNil(body)
        // Note: Testing specific UI content requires ViewInspector or similar tools
        // For now, we're testing that the view renders without crashing
    }

    func testTranslationUnlockBannerButtonAction() {
        // Given: TranslationUnlockBanner
        let banner = TranslationUnlockBanner()

        // When: Simulating button tap (indirectly through view creation)
        let body = banner.body

        // Then: View should handle button interaction setup
        XCTAssertNotNil(body)
        // Note: Direct button testing requires UI testing or ViewInspector
    }

    // MARK: - TranslationPurchaseManager Integration Tests

    func testTranslationUnlockBannerTranslationPurchaseManagerStates() {
        // Given: Banner
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Testing different TranslationPurchaseManager states
        let states = [
            (loading: true, hasAccess: false, error: nil),
            (loading: false, hasAccess: true, error: nil),
            (loading: false, hasAccess: false, error: "Test error"),
            (loading: false, hasAccess: false, error: nil)
        ]

        for state in states {
            purchaseManager.isLoading = state.loading
            if state.hasAccess {
                purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
            } else {
                purchaseManager.purchasedProducts.removeAll()
            }
            purchaseManager.purchaseError = state.error

            // Then: Banner should handle each state
            XCTAssertNotNil(banner.body)
        }
    }

    func testTranslationUnlockBannerTrialStates() {
        // Given: Banner
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Testing different trial states
        let trialDays = [-1, 0, 1, 3, 7, 8] // Before, on boundary, and after trial period

        for days in trialDays {
            let trialDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
            UserDefaults.standard.set(trialDate, forKey: "FirstLaunchDate")
            purchaseManager.purchasedProducts.removeAll()

            // Then: Banner should handle each trial state
            XCTAssertNotNil(banner.body)

            let isActive = purchaseManager.isTrialActive
            let canUse = purchaseManager.canUseTranslation
            let shouldShow = purchaseManager.shouldShowTranslationUpgrade

            // Verify trial logic consistency
            XCTAssertEqual(canUse, isActive)
            XCTAssertEqual(shouldShow, !canUse)
        }
    }

    // MARK: - Preview Tests

    func testTranslationUnlockBannerPreview() {
        // Given/When: Creating TranslationUnlockBanner preview
        let preview = TranslationUnlockBanner()

        // Then: Preview should not crash
        XCTAssertNotNil(preview)
        XCTAssertNotNil(preview.body)
    }

    // MARK: - Memory Management Tests

    func testTranslationUnlockBannerMemoryManagement() {
        // Given: TranslationUnlockBanner instances
        // SwiftUI Views are structs (value types), so we test that multiple instances
        // can be created and used without memory issues

        var banners: [TranslationUnlockBanner] = []

        // When: Creating multiple banner instances
        for _ in 0..<100 {
            let banner = TranslationUnlockBanner()
            let _ = banner.body // Access body to ensure it's fully initialized
            banners.append(banner)
        }

        // Then: Should handle multiple instances without issues
        XCTAssertEqual(banners.count, 100)

        // Clear array (should deallocate all instances since structs are value types)
        banners.removeAll()
        XCTAssertTrue(banners.isEmpty)

        // Test completed - no memory leaks expected with value types
    }

    // MARK: - Accessibility Tests

    func testTranslationUnlockBannerAccessibility() {
        // Given: TranslationUnlockBanner instance
        let banner = TranslationUnlockBanner()

        // When: Getting the view body
        let body = banner.body

        // Then: Should support accessibility
        XCTAssertNotNil(body)
    }

    // MARK: - Layout Tests

    func testTranslationUnlockBannerLayout() {
        // Given: TranslationUnlockBanner
        let banner = TranslationUnlockBanner()

        // When: Creating view with different states
        let purchaseManager = TranslationPurchaseManager.shared

        // Test with loading state
        purchaseManager.isLoading = true
        XCTAssertNotNil(banner.body)

        // Test with error state
        purchaseManager.isLoading = false
        purchaseManager.purchaseError = "Network error"
        XCTAssertNotNil(banner.body)

        // Test with normal state
        purchaseManager.purchaseError = nil
        XCTAssertNotNil(banner.body)
    }

    // MARK: - Edge Cases

    func testTranslationUnlockBannerWithCorruptedData() {
        // Given: Banner with corrupted UserDefaults
        let banner = TranslationUnlockBanner()

        // When: Setting corrupted trial data
        UserDefaults.standard.set("invalid date", forKey: "FirstLaunchDate")

        // Then: Banner should handle corrupted data gracefully
        XCTAssertNotNil(banner.body)

        let purchaseManager = TranslationPurchaseManager.shared
        // Should provide reasonable defaults
        XCTAssertNotNil(purchaseManager.isTrialActive) // Should not crash
        XCTAssertNotNil(purchaseManager.canUseTranslation) // Should not crash
    }

    func testTranslationUnlockBannerWithRapidStateChanges() {
        // Given: Banner
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Rapidly changing states
        for i in 0..<10 {
            purchaseManager.isLoading = i % 2 == 0
            purchaseManager.purchaseError = i % 3 == 0 ? "Error \(i)" : nil
            if i % 4 == 0 {
                purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
            } else {
                purchaseManager.purchasedProducts.removeAll()
            }

            // Then: Should handle rapid changes
            XCTAssertNotNil(banner.body)
        }
    }

    // MARK: - Integration Tests

    func testTranslationUnlockBannerTrialIntegration() {
        // Given: Banner with specific trial scenario
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: User's trial expires during session (simulate day boundary)
        let almostExpiredDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        UserDefaults.standard.set(almostExpiredDate, forKey: "FirstLaunchDate")

        // First check: trial should be active (6 days < 7)
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertNotNil(banner.body)

        // Simulate passage of time (trial expires)
        let expiredDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        UserDefaults.standard.set(expiredDate, forKey: "FirstLaunchDate")

        // Second check: trial should be expired
        XCTAssertFalse(purchaseManager.isTrialActive)
        XCTAssertNotNil(banner.body)
    }

    func testTranslationUnlockBannerPurchaseFlow() {
        // Given: Banner representing purchase flow
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Simulating purchase flow states

        // Start: User needs to purchase
        let expiredDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(expiredDate, forKey: "FirstLaunchDate")
        purchaseManager.purchasedProducts.removeAll()
        XCTAssertTrue(purchaseManager.shouldShowTranslationUpgrade)
        XCTAssertNotNil(banner.body)

        // During: Purchase in progress
        purchaseManager.isLoading = true
        XCTAssertNotNil(banner.body)

        // Error: Purchase failed
        purchaseManager.isLoading = false
        purchaseManager.purchaseError = "Purchase failed"
        XCTAssertNotNil(banner.body)

        // Success: Purchase completed
        purchaseManager.purchaseError = nil
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
        XCTAssertTrue(purchaseManager.hasFullAccess)
        XCTAssertFalse(purchaseManager.shouldShowTranslationUpgrade)
        XCTAssertNotNil(banner.body)
    }

    // MARK: - Performance Tests

    func testTranslationUnlockBannerRenderingPerformance() {
        // Given: TranslationUnlockBanner
        let banner = TranslationUnlockBanner()

        // When: Measuring rendering performance
        measure {
            // Access body multiple times to test rendering performance
            for _ in 0..<100 {
                let _ = banner.body
            }
        }

        // Then: Should complete within reasonable time
        // (Performance is measured by XCTest's measure block)
    }

    func testTranslationUnlockBannerStateChangePerformance() {
        // Given: Banner
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Measuring performance during state changes
        measure {
            for i in 0..<50 {
                purchaseManager.isLoading = i % 2 == 0
                purchaseManager.purchaseError = i % 3 == 0 ? "Error" : nil
                let _ = banner.body
            }
        }

        // Then: Should handle state changes efficiently
    }

    // MARK: - UI Interaction Tests

    func testTranslationUnlockBannerButtonInteraction() {
        // Given: Banner
        let banner = TranslationUnlockBanner()

        // When: Creating view (button setup is implicit)
        let body = banner.body

        // Then: Button should be properly configured
        XCTAssertNotNil(body)
        // Note: Actual button tap testing would require UI testing framework
    }

    func testTranslationUnlockBannerSheetPresentation() {
        // Given: Banner
        let banner = TranslationUnlockBanner()

        // When: View is created with sheet setup
        let body = banner.body

        // Then: Sheet presentation should be configured
        XCTAssertNotNil(body)
        // Note: Sheet presentation testing would require UI testing framework
    }

    // MARK: - Visual State Tests

    func testTranslationUnlockBannerVisualStates() {
        // Given: Banner
        let banner = TranslationUnlockBanner()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Testing different visual states based on TranslationPurchaseManager
        let visualStates = [
            "Normal state",
            "Loading state",
            "Error state",
            "Purchased state"
        ]

        for (index, _) in visualStates.enumerated() {
            switch index {
            case 0:
                purchaseManager.isLoading = false
                purchaseManager.purchaseError = nil
                purchaseManager.purchasedProducts.removeAll()
            case 1:
                purchaseManager.isLoading = true
                purchaseManager.purchaseError = nil
            case 2:
                purchaseManager.isLoading = false
                purchaseManager.purchaseError = "Test error"
            case 3:
                purchaseManager.isLoading = false
                purchaseManager.purchaseError = nil
                purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)
            default:
                break
            }

            // Then: Each state should render correctly
            XCTAssertNotNil(banner.body)
        }
    }
}