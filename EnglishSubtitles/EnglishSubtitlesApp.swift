//
//  EnglishSubtitlesApp.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import SwiftUI

@main
struct EnglishSubtitlesApp: App {
    init() {
        TranslationPurchaseManager.shared.startTrialIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
}
