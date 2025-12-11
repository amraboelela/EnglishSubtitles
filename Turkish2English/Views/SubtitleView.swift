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
            if vm.isModelLoading {
                // Use same gradient background as splash screen for loading
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.15, green: 0.35, blue: 0.75),  // Deep blue
                        Color(red: 0.35, green: 0.65, blue: 0.95)   // Light blue
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Show loading progress with logo
                VStack(spacing: 30) {
                    // App logo with fallback (same as splash screen)
                    Group {
                        if UIImage(named: "SplashLogo") != nil {
                            Image("SplashLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 28))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        } else {
                            // Fallback to a system icon with app-like styling
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(.white.opacity(0.1))
                                )
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                    }

                    Text("Loading...")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    ProgressView(value: vm.loadingProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .frame(width: 300)
                }
            } else if vm.english.isEmpty {
                // "Listening..." state - use same gradient as splash/loading
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.15, green: 0.35, blue: 0.75),  // Deep blue
                        Color(red: 0.35, green: 0.65, blue: 0.95)   // Light blue
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Show listening state with logo
                VStack(spacing: 30) {
                    // App logo with fallback (same as splash screen)
                    Group {
                        if UIImage(named: "SplashLogo") != nil {
                            Image("SplashLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 28))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        } else {
                            // Fallback to a system icon with app-like styling
                            Image(systemName: "bubble.left.and.text.bubble.right")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(.white.opacity(0.1))
                                )
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                    }

                    Text("Listening...")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                // Black background for actual subtitle display
                Color.black
                    .ignoresSafeArea()

                // Fullscreen English Subtitle
                VStack {
                    Spacer()
                    Text(vm.english)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(40)
                        .minimumScaleFactor(0.3)
                        .lineLimit(nil)
                    Spacer()
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            Task {
                //await vm.loadModel()
                vm.start()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            vm.unloadModel()
        }
    }
}

#Preview {
    SubtitleView()
}
