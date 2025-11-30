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
            Text(vm.english.isEmpty ? "Listening..." : vm.english)
                .font(.system(size: vm.english.isEmpty ? 40 : 60, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            vm.start()
        }
    }
}

#Preview {
    SubtitleView()
}
