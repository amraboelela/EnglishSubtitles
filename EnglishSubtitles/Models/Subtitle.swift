//
//  Subtitle.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 11/28/25.
//

import Foundation

/// Represents a subtitle entry with original and translated text
struct Subtitle: Identifiable, Equatable {
  let id = UUID()
  let originalText: String
  let translatedText: String
  let timestamp: Date
  let language: String
  
  init(originalText: String, translatedText: String = "", language: String = "tr") {
    self.originalText = originalText
    self.translatedText = translatedText
    self.timestamp = Date()
    self.language = language
  }
}
