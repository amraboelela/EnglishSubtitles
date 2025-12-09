//
//  ContentView.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import SwiftUI

struct ContentView: View {
  @StateObject private var purchaseManager = TranslationPurchaseManager.shared

  var body: some View {
    // Always show the main app - no more paywall blocking
    SubtitleView()
      .onAppear {
        // Start trial timer on first launch
        purchaseManager.startTrialIfNeeded()
      }
  }
}

#Preview {
  ContentView()
}
