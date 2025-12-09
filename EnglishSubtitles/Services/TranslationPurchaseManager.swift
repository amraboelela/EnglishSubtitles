//
//  TranslationPurchaseManager.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/6/24.
//

import Foundation
import StoreKit

@MainActor
class TranslationPurchaseManager: ObservableObject {
    static let shared = TranslationPurchaseManager()

    // Product ID - this must match exactly what you create in App Store Connect
    static let fullAccessProductID = "org.amr.englishsubtitles.translation"

    // UserDefaults keys to prevent typos
    private enum Keys {
        static let firstLaunch = "FirstLaunchDate"
    }

    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Error>? = nil

    init() {
        // Start the trial immediately if needed
        startTrialIfNeeded()

        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await requestProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func requestProducts() async {
        do {
            let storeProducts = try await Product.products(for: [Self.fullAccessProductID])
            products = storeProducts
            print("✅ Loaded products: \(products.map { $0.id })")
        } catch {
            print("❌ Failed to load products: \(error)")
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase Logic

    func purchase(product: Product) async {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Successful purchase
                    purchasedProducts.insert(transaction.productID)
                    await transaction.finish()
                    print("✅ Purchase successful: \(transaction.productID)")

                case .unverified(_, let error):
                    purchaseError = "Purchase could not be verified: \(error)"
                    print("❌ Unverified purchase: \(error)")
                }

            case .userCancelled:
                // User cancelled - not an error
                print("ℹ️ Purchase cancelled by user")

            case .pending:
                // Purchase is pending (e.g., awaiting parental approval)
                print("⏳ Purchase pending")

            @unknown default:
                purchaseError = "Unknown purchase result"
                print("❌ Unknown purchase result")
            }

        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            print("✅ Purchases restored")
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Restore error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Purchase Status

    func updatePurchasedProducts() async {
        var purchasedProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIDs.insert(transaction.productID)
                print("✅ Verified entitlement: \(transaction.productID)")
            }
        }

        purchasedProducts = purchasedProductIDs
    }

    var hasFullAccess: Bool {
        purchasedProducts.contains(Self.fullAccessProductID)
    }

    var translationProduct: Product? {
        products.first
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }
}

// MARK: - Trial Logic

extension TranslationPurchaseManager {
  
  private static let trialDays = 7
  
  var isTrialActive: Bool {
    if hasFullAccess {
      return false // Trial doesn't matter if they already purchased
    }
    
    let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunch) as? Date ?? Date()
    let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
    
    return daysSinceLaunch < Self.trialDays
  }
  
  var trialDaysRemaining: Int {
    if hasFullAccess {
      return 0
    }
    
    let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunch) as? Date ?? Date()
    let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
    let remaining = max(0, Self.trialDays - daysSinceLaunch)
    
    print("Trial days remaining: \(remaining)")
    return remaining
  }
  
  func startTrialIfNeeded() {
    if UserDefaults.standard.object(forKey: Keys.firstLaunch) == nil {
      UserDefaults.standard.set(Date(), forKey: Keys.firstLaunch)
      print("✅ Trial started: \(Self.trialDays) days remaining")
    } else {
      print("ℹ️ Trial already started. Days remaining: \(trialDaysRemaining)")
    }
  }
  
  // MARK: - Translation Feature Logic
  
  var canUseTranslation: Bool {
    hasFullAccess || isTrialActive
  }
  
  var shouldShowTranslationUpgrade: Bool {
    !canUseTranslation
  }
}
