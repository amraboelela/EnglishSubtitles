//
//  AppleTranslationService.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/11/25.
//

import Foundation
import Translation

/// Service that handles Turkish-to-English translation using Apple's Translation framework
/// Implements the actual Translation API for iOS 17.4+
@available(iOS 17.4, *)
class AppleTranslationService {
    /// Translate text from Turkish to English using Apple's Translation framework
    /// - Parameter text: Turkish text to translate
    /// - Returns: English translation
    func translate(text: String) async throws -> String {
        print("🇹🇷➡️🇬🇧 Translating: '\(text)'")

        let session = TranslationSession(
            installedSource: .init(identifier: "tr"),
            target: .init(identifier: "en")
        )
        do {
            let response = try await session.translate(text)
            let translatedText = response.targetText
            print("🇹🇷➡️🇬🇧 Result: '\(text)' → '\(translatedText)'")
            return translatedText
        } catch {
            print("❌ Translation failed: \(error)")
            print("ℹ️ Falling back to original text")
            return text
        }
    }
}
