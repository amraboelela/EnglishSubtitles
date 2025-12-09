//
//  TrialBannerView.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/6/24.
//

import SwiftUI

struct TrialBannerView: View {
    @StateObject private var purchaseManager = TranslationPurchaseManager.shared
    @State private var showPaywall = false

    var body: some View {
        if purchaseManager.isTrialActive && !purchaseManager.hasFullAccess {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Translation Trial")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        let days = purchaseManager.trialDaysRemaining
                        Text("\(days) day\(days == 1 ? "" : "s") remaining")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Button("Unlock Now") {
                        showPaywall = true
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    TrialBannerView()
}