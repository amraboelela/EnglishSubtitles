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
        .onAppear {
            vm.start()
        }
    }

    private var displayText: String {
        if vm.isModelLoading {
            return "Loading..."
        } else if vm.english.isEmpty {
            return "Listening..."
        } else {
            return vm.english
        }
    }

    private var fontSize: CGFloat {
        if vm.isModelLoading {
            return 50
        } else if vm.english.isEmpty {
            return 40
        } else {
            return 60
        }
    }
}

#Preview {
    SubtitleView()
}
