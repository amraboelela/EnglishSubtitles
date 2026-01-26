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
        ZStack {
            // Subtitle display area
            Text(viewModel.currentSubtitle)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Show progress bar when downloading
            if viewModel.isDownloading {
                VStack {
                    Spacer()
                    ProgressView(value: viewModel.downloadProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 600)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
            }

            // Error message if any
            if let error = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }
            }

            // Close button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        NSApp.windows.first?.close()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                Spacer()
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
