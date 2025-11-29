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
        VStack(spacing: 20) {
            // Title
            Text("EnglishSubtitles")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)

            Spacer()

            // Original Language Subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("Original:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(vm.original.isEmpty ? "Listening..." : vm.original)
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            // English Translation
            VStack(alignment: .leading, spacing: 8) {
                Text("English:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(vm.english.isEmpty ? "Waiting for translation..." : vm.english)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()

            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    vm.start()
                }) {
                    Label("Start", systemImage: "mic.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.isRecording ? Color.gray : Color.green)
                        .cornerRadius(10)
                }
                .disabled(vm.isRecording)

                Button(action: {
                    vm.stop()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.isRecording ? Color.red : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!vm.isRecording)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    SubtitleView()
}
