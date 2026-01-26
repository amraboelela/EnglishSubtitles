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
                Text(viewModel.currentSubtitle)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
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

            // Control button
            Button(action: {
                Task {
                    if viewModel.isCapturing {
                        viewModel.stopCapture()
                    } else {
                        await viewModel.startCapture()
                    }
                }
            }) {
                Text(viewModel.isCapturing ? "Stop Capture" : "Start Capture")
                    .frame(width: 150)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.errorMessage != nil && viewModel.isCapturing)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
