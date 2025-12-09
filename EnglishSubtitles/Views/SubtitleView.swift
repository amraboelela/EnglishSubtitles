//
//  SubtitleView.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import SwiftUI
import UIKit

struct SubtitleView: View {
    @StateObject private var vm = SubtitlesViewModel()
    @StateObject private var purchaseManager = TranslationPurchaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Translation trial/unlock banner
            if purchaseManager.isTrialActive && !purchaseManager.hasFullAccess {
                // Show trial banner during trial period
                TrialBannerView()
            } else if purchaseManager.shouldShowTranslationUpgrade {
                // Show unlock banner after trial expires
                TranslationUnlockBanner()
            }

            // Main subtitle display
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if vm.isModelLoading {
                    // Show loading progress
                    VStack(spacing: 30) {
                        Text("Loading...")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        ProgressView(value: vm.loadingProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .frame(width: 300)
                    }
                } else {
                    // Display transcription and translation
                    VStack(spacing: 20) {
                        Spacer()

                        // Always show transcription (free)
                        if !vm.originalText.isEmpty {
                            VStack(spacing: 8) {
                                Text("Original")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(vm.originalText)
                                    .font(.system(size: originalTextFontSize, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .minimumScaleFactor(0.3)
                                    .lineLimit(nil)
                            }
                        }

                        // Conditionally show translation (premium feature)
                        if purchaseManager.canUseTranslation && !vm.englishText.isEmpty {
                            VStack(spacing: 8) {
                                Text("English Translation")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(vm.englishText)
                                    .font(.system(size: englishTextFontSize, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .minimumScaleFactor(0.3)
                                    .lineLimit(nil)
                            }
                        }

                        // Show "Listening..." if no text yet
                        if vm.originalText.isEmpty && vm.englishText.isEmpty {
                            Text("Listening...")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            Task {
                await vm.loadModel()
                vm.start()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            vm.unloadModel()
        }
    }

    private var originalTextFontSize: CGFloat {
        return 36
    }

    private var englishTextFontSize: CGFloat {
        return 48
    }
}

#Preview {
    SubtitleView()
}
