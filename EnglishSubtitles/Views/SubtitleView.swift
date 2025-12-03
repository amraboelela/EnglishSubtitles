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

    var body: some View {
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
                // Fullscreen English Subtitle
                VStack {
                    Spacer()
                    Text(displayText)
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(40)
                        .minimumScaleFactor(0.5)
                        .lineLimit(nil)
                    Spacer()
                }
            }
        }
        .onAppear {
            // Prevent screen from sleeping while app is in foreground
            UIApplication.shared.isIdleTimerDisabled = true
            vm.start()
        }
        .onDisappear {
            // Re-enable auto-lock when leaving the view
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var displayText: String {
        if vm.english.isEmpty {
            return "Listening..."
        } else {
            return vm.english
        }
    }

    private var fontSize: CGFloat {
        if vm.english.isEmpty {
            return 30
        } else {
            return 48
        }
    }
}

#Preview {
    SubtitleView()
}
