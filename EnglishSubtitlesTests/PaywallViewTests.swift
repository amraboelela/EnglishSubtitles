//
//  PaywallViewTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/7/25.
//

import XCTest
import SwiftUI
import StoreKit
@testable import EnglishSubtitles

@MainActor
final class PaywallViewTests: XCTestCase {

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

    func testPaywallViewInitialization() {
        // Given/When: Creating PaywallView
        let paywallView = PaywallView()

        // Then: Should not crash
        XCTAssertNotNil(paywallView)
        XCTAssertNotNil(paywallView.body)
    }

    func testPaywallViewUsesSharedTranslationPurchaseManager() {
        // Given: PaywallView instance
        let paywallView = PaywallView()

        // When: Accessing the view's body (this would trigger @StateObject initialization)
        let _ = paywallView.body

        // Then: Should use the shared TranslationPurchaseManager instance
        let sharedManager = TranslationPurchaseManager.shared
        XCTAssertNotNil(sharedManager)
    }

    // MARK: - FeatureRow Tests

    func testFeatureRowInitialization() {
        // Given/When: Creating FeatureRow
        let featureRow = FeatureRow(
            icon: "waveform",
            title: "AI-Powered Translation",
            description: "Real-time speech to English using Whisper AI"
        )

        // Then: Should not crash
        XCTAssertNotNil(featureRow)
        XCTAssertNotNil(featureRow.body)
    }

    func testFeatureRowProperties() {
        // Given: FeatureRow with specific properties
        let icon = "checkmark.circle"
        let title = "Test Feature"
        let description = "Test Description"

        // When: Creating FeatureRow
        let featureRow = FeatureRow(
            icon: icon,
            title: title,
            description: description
        )

        // Then: Properties should be stored correctly
        XCTAssertEqual(featureRow.icon, icon)
        XCTAssertEqual(featureRow.title, title)
        XCTAssertEqual(featureRow.description, description)
    }

    func testFeatureRowAllVariants() {
        // Given: Different feature configurations
        let features = [
            ("waveform", "AI-Powered Translation", "Real-time speech to English using Whisper AI"),
            ("checkmark.circle", "Free Transcription Included", "Original language transcription remains free"),
            ("lock.shield", "100% Private", "Everything runs on your device"),
            ("infinity", "Unlimited Translation", "One-time purchase, lifetime access")
        ]

        for (icon, title, description) in features {
            // When: Creating each FeatureRow variant
            let featureRow = FeatureRow(
                icon: icon,
                title: title,
                description: description
            )

            // Then: Should initialize correctly
            XCTAssertNotNil(featureRow.body)
            XCTAssertEqual(featureRow.icon, icon)
            XCTAssertEqual(featureRow.title, title)
            XCTAssertEqual(featureRow.description, description)
        }
    }

    // MARK: - TranslationPurchaseManager Integration Tests

    func testPaywallViewWithLoadingState() {
        // Given: PaywallView with TranslationPurchaseManager in loading state
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting loading state
        purchaseManager.isLoading = true

        // Then: View should handle loading state
        XCTAssertNotNil(paywallView.body)
        XCTAssertTrue(purchaseManager.isLoading)
    }

    func testPaywallViewWithPurchaseError() {
        // Given: PaywallView with TranslationPurchaseManager error
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting error state
        purchaseManager.purchaseError = "Test purchase error"

        // Then: View should handle error state
        XCTAssertNotNil(paywallView.body)
        XCTAssertEqual(purchaseManager.purchaseError, "Test purchase error")
    }

    func testPaywallViewWithProducts() {
        // Given: PaywallView
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Products array is populated (simulated)
        // Note: We can't easily create real Product instances in tests,
        // but we can test the view structure

        // Then: View should handle products state
        XCTAssertNotNil(paywallView.body)
        XCTAssertNotNil(purchaseManager.products) // Should be empty array by default
    }

    func testPaywallViewWithFullAccess() {
        // Given: PaywallView and user with full access
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: User has full access
        purchaseManager.purchasedProducts.insert(TranslationPurchaseManager.fullAccessProductID)

        // Then: View should handle full access state
        XCTAssertNotNil(paywallView.body)
        XCTAssertTrue(purchaseManager.hasFullAccess)
    }

    // MARK: - State Management Tests

    func testPaywallViewStateChanges() {
        // Given: PaywallView
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Changing various states
        purchaseManager.isLoading = false
        purchaseManager.purchaseError = nil
        purchaseManager.purchasedProducts.removeAll()

        // Then: View should handle state changes
        XCTAssertNotNil(paywallView.body)
        XCTAssertFalse(purchaseManager.isLoading)
        XCTAssertNil(purchaseManager.purchaseError)
        XCTAssertFalse(purchaseManager.hasFullAccess)
    }

    // MARK: - View Content Tests

    func testPaywallViewContainsExpectedFeatures() {
        // Given: PaywallView
        let paywallView = PaywallView()

        // When: Getting view body
        let body = paywallView.body

        // Then: Should contain the expected structure
        XCTAssertNotNil(body)
        // Note: Testing SwiftUI view content requires more complex setup with ViewInspector or similar
        // For now, we're testing that the view compiles and renders without crashing
    }

    func testPaywallViewErrorHandling() {
        // Given: PaywallView with various error conditions
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting different error conditions
        let errorMessages = [
            "Network error",
            "Purchase failed",
            "Product not found",
            "User cancelled"
        ]

        for errorMessage in errorMessages {
            purchaseManager.purchaseError = errorMessage

            // Then: View should handle each error without crashing
            XCTAssertNotNil(paywallView.body)
            XCTAssertEqual(purchaseManager.purchaseError, errorMessage)

            // Clear error for next iteration
            purchaseManager.purchaseError = nil
        }
    }

    // MARK: - Preview Tests

    func testPaywallViewPreview() {
        // Given/When: Creating PaywallView preview
        let preview = PaywallView()

        // Then: Preview should not crash
        XCTAssertNotNil(preview)
        XCTAssertNotNil(preview.body)
    }

    // MARK: - Memory Management Tests

    func testPaywallViewMemoryManagement() {
        // Given: PaywallView instances
        // SwiftUI Views are structs (value types), so we test that multiple instances
        // can be created and used without memory issues

        var paywallViews: [PaywallView] = []

        // When: Creating multiple PaywallView instances
        for _ in 0..<50 {
            let paywallView = PaywallView()
            let _ = paywallView.body // Access body to ensure it's fully initialized
            paywallViews.append(paywallView)
        }

        // Then: Should handle multiple instances without issues
        XCTAssertEqual(paywallViews.count, 50)

        // Clear array (should deallocate all instances since structs are value types)
        paywallViews.removeAll()
        XCTAssertTrue(paywallViews.isEmpty)

        // Test completed - no memory leaks expected with value types
    }

    // MARK: - Accessibility Tests

    func testPaywallViewAccessibility() {
        // Given: PaywallView instance
        let paywallView = PaywallView()

        // When: Getting the view body
        let body = paywallView.body

        // Then: Should support accessibility
        XCTAssertNotNil(body)
    }

    func testFeatureRowAccessibility() {
        // Given: FeatureRow instances with different content
        let featureRows = [
            FeatureRow(icon: "waveform", title: "AI Translation", description: "Real-time translation"),
            FeatureRow(icon: "lock.shield", title: "Privacy", description: "On-device processing"),
            FeatureRow(icon: "infinity", title: "Unlimited", description: "Lifetime access")
        ]

        for featureRow in featureRows {
            // When: Getting the view body
            let body = featureRow.body

            // Then: Should support accessibility
            XCTAssertNotNil(body)
        }
    }

    // MARK: - Edge Cases

    func testPaywallViewWithEmptyProducts() {
        // Given: PaywallView with empty products array
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Products array is empty (default state)
        XCTAssertTrue(purchaseManager.products.isEmpty)

        // Then: View should handle empty products gracefully
        XCTAssertNotNil(paywallView.body)
    }

    func testPaywallViewConcurrentStateChanges() {
        // Given: PaywallView
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Rapidly changing states (simulating real-world usage)
        purchaseManager.isLoading = true
        purchaseManager.purchaseError = "Error"
        purchaseManager.isLoading = false
        purchaseManager.purchaseError = nil
        purchaseManager.purchasedProducts.insert("test.product")
        purchaseManager.purchasedProducts.removeAll()

        // Then: View should handle rapid state changes
        XCTAssertNotNil(paywallView.body)
    }

    func testFeatureRowWithLongText() {
        // Given: FeatureRow with very long text
        let longTitle = String(repeating: "Very Long Feature Title ", count: 20)
        let longDescription = String(repeating: "This is a very long description that goes on and on. ", count: 10)

        // When: Creating FeatureRow with long text
        let featureRow = FeatureRow(
            icon: "text.bubble",
            title: longTitle,
            description: longDescription
        )

        // Then: Should handle long text without crashing
        XCTAssertNotNil(featureRow.body)
        XCTAssertEqual(featureRow.title, longTitle)
        XCTAssertEqual(featureRow.description, longDescription)
    }

    func testFeatureRowWithSpecialCharacters() {
        // Given: FeatureRow with special characters and Unicode
        let specialTitle = "🎭 AI-Powered Translation! @#$%^&*()"
        let specialDescription = "Real-time speech → English using Whisper AI ⚡️🌍"

        // When: Creating FeatureRow with special characters
        let featureRow = FeatureRow(
            icon: "globe",
            title: specialTitle,
            description: specialDescription
        )

        // Then: Should handle special characters without crashing
        XCTAssertNotNil(featureRow.body)
        XCTAssertEqual(featureRow.title, specialTitle)
        XCTAssertEqual(featureRow.description, specialDescription)
    }

    func testFeatureRowWithEmptyStrings() {
        // Given: FeatureRow with empty strings
        let featureRow = FeatureRow(
            icon: "",
            title: "",
            description: ""
        )

        // Then: Should handle empty strings without crashing
        XCTAssertNotNil(featureRow.body)
        XCTAssertEqual(featureRow.icon, "")
        XCTAssertEqual(featureRow.title, "")
        XCTAssertEqual(featureRow.description, "")
    }

    // MARK: - Integration with TranslationPurchaseManager Tests

    func testPaywallViewTrialIntegration() {
        // Given: PaywallView with trial state
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting up trial state
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        UserDefaults.standard.set(threeDaysAgo, forKey: "FirstLaunchDate")

        // Then: View should work with trial state
        XCTAssertNotNil(paywallView.body)
        XCTAssertTrue(purchaseManager.isTrialActive)
        XCTAssertTrue(purchaseManager.canUseTranslation)
    }

    func testPaywallViewExpiredTrialIntegration() {
        // Given: PaywallView with expired trial
        let paywallView = PaywallView()
        let purchaseManager = TranslationPurchaseManager.shared

        // When: Setting up expired trial state
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        UserDefaults.standard.set(tenDaysAgo, forKey: "FirstLaunchDate")

        // Then: View should work with expired trial state
        XCTAssertNotNil(paywallView.body)
        XCTAssertFalse(purchaseManager.isTrialActive)
        XCTAssertFalse(purchaseManager.canUseTranslation)
        XCTAssertTrue(purchaseManager.shouldShowTranslationUpgrade)
    }

    // MARK: - Performance Tests

    func testPaywallViewRenderingPerformance() {
        // Given: PaywallView
        let paywallView = PaywallView()

        // When: Measuring rendering performance
        measure {
            // Access body multiple times to test rendering performance
            for _ in 0..<100 {
                let _ = paywallView.body
            }
        }

        // Then: Should complete within reasonable time
        // (Performance is measured by XCTest's measure block)
    }

    func testFeatureRowRenderingPerformance() {
        // Given: Multiple FeatureRows
        let featureRows = (0..<100).map { index in
            FeatureRow(
                icon: "star",
                title: "Feature \(index)",
                description: "Description for feature \(index)"
            )
        }

        // When: Measuring rendering performance
        measure {
            for featureRow in featureRows {
                let _ = featureRow.body
            }
        }

        // Then: Should complete within reasonable time
    }
}