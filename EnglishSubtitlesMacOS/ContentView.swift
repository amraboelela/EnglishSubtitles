//
//  ContentView.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/20/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: SubtitlesViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Close button row
            HStack {
                Spacer()
                Button(action: {
                    NSApp.windows.first?.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .padding(6)
            }

            // Subtitle text centered
            Spacer()

            Text(viewModel.currentSubtitle)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Progress bar when downloading
            if viewModel.isDownloading {
                ProgressView(value: viewModel.downloadProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            // Error message if any
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .task {
            // Auto-start capture when view appears
            await viewModel.startCapture()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SubtitlesViewModel())
}
