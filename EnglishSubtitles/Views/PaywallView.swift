//
//  PaywallView.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/6/24.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
  @StateObject private var purchaseManager = TranslationPurchaseManager.shared
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      // Beautiful background with launch image
      Image("LaunchImage")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .ignoresSafeArea()

      // Semi-transparent overlay
      Color.black.opacity(0.7)
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 30) {
          Spacer(minLength: 60)

          // Header
          VStack(spacing: 16) {
            Text("🎭")
              .font(.system(size: 60))

            Text("Unlock English Translation")
              .font(.title)
              .fontWeight(.bold)
              .foregroundColor(.white)

            Text("Continue getting real-time English translations")
              .font(.headline)
              .foregroundColor(.gray)
              .multilineTextAlignment(.center)
          }

          // Features
          VStack(spacing: 20) {
            FeatureRow(
              icon: "waveform",
              title: "AI-Powered Translation",
              description: "Real-time speech to English using Whisper AI"
            )

            FeatureRow(
              icon: "checkmark.circle",
              title: "Free Transcription Included",
              description: "Original language transcription remains free"
            )

            FeatureRow(
              icon: "lock.shield",
              title: "100% Private",
              description: "Everything runs on your device"
            )

            FeatureRow(
              icon: "infinity",
              title: "Unlimited Translation",
              description: "One-time purchase, lifetime access"
            )
          }
          .padding(.horizontal, 20)

          // Purchase Button
          VStack(spacing: 16) {
            if let product = purchaseManager.products.first {
              Button(action: {
                Task {
                  await purchaseManager.purchase(product: product)
                }
              }) {
                HStack {
                  if purchaseManager.isLoading {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .black))
                  } else {
                    Text("Unlock Translation for \(product.displayPrice)")
                  }
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 5)
              }
              .disabled(purchaseManager.isLoading)
            } else {
              // Loading products
              Button(action: {}) {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .black))
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.gray.opacity(0.3))
                  .cornerRadius(12)
              }
              .disabled(true)
            }

            // Restore button
            Button("Restore Purchases") {
              Task {
                await purchaseManager.restorePurchases()
              }
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .disabled(purchaseManager.isLoading)

            // Error message
            if let error = purchaseManager.purchaseError {
              Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            }
          }
          .padding(.horizontal, 20)

          // Fine print
          VStack(spacing: 8) {
            Text("• One-time purchase")
            Text("• No subscriptions or recurring charges")
            Text("• Lifetime access on all your devices")
            Text("• 100% secure through App Store")
          }
          .font(.caption)
          .foregroundColor(.gray)
          .multilineTextAlignment(.center)

          Spacer(minLength: 40)
        }
        .padding()
      }
    }
    .onAppear {
      if purchaseManager.products.isEmpty {
        Task {
          await purchaseManager.requestProducts()
        }
      }
    }
    .onChange(of: purchaseManager.hasFullAccess) { _, hasAccess in
      if hasAccess {
        dismiss()
      }
    }
  }
}

struct FeatureRow: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(.blue)
        .frame(width: 24, height: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundColor(.white)

        Text(description)
          .font(.subheadline)
          .foregroundColor(.gray)
      }

      Spacer()
    }
  }
}

#Preview {
  PaywallView()
}
