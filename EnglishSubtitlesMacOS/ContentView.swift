//
//  ContentView.swift
//  EnglishSubtitlesMacOS
//
//  Created by Amr Aboelela on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SubtitlesViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Subtitle display area
            ScrollView {
                VStack(spacing: 12) {
                    Text(viewModel.currentSubtitle)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)

                    // Show progress bar when downloading
                    if viewModel.isDownloading {
                        ProgressView(value: viewModel.downloadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 600)
                            .padding(.horizontal, 40)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Error message if any
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            // Auto-start capture when view appears
            await viewModel.startCapture()
        }
    }
}

#Preview {
    ContentView()
}
