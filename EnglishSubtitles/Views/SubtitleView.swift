//
//  SubtitleView.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import SwiftUI

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
                    Spacer()
                }
            }
        }
        .onAppear {
            vm.start()
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
            return 40
        } else {
            return 60
        }
    }
}

#Preview {
    SubtitleView()
}
