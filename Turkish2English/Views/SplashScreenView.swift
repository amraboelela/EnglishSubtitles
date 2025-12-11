//
//  SplashScreenView.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/8/24.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var scale = 0.8
    @State private var opacity = 0.0

    var body: some View {
        Group {
            if isActive {
                ContentView()
            } else {
                VStack(spacing: 30) {
                    // App logo with fallback to system icon if SplashLogo doesn't exist
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
                    .scaleEffect(scale)
                    .opacity(opacity)

                    // App name with animation
                    VStack(spacing: 8) {
                        Text("English Subtitles")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Real-time Translation")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .opacity(opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    // Beautiful gradient background matching your app icon
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.15, green: 0.35, blue: 0.75),  // Deep blue
                            Color(red: 0.35, green: 0.65, blue: 0.95)   // Light blue
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // Animate the splash elements
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }

            // Transition to main app after splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
