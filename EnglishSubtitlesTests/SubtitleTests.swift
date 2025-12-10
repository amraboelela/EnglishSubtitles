//
//  SubtitleTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for data models (Subtitle)
struct SubtitleTests {
  
  @Test func testSubtitleModelCreation() async throws {
    let subtitle = Subtitle(
      originalText: "Haydi. Emret sultanım",
      translatedText: "Come on. As you order my sultan",
      language: "tr"
    )
    
    #expect(subtitle.originalText == "Haydi. Emret sultanım")
    #expect(subtitle.translatedText == "Come on. As you order my sultan")
    #expect(subtitle.language == "tr")
    #expect(subtitle.id != UUID(), "Should have a unique ID")
  }
  
  @Test func testSubtitleEquality() async throws {
    let subtitle1 = Subtitle(originalText: "Test", translatedText: "Test", language: "tr")
    let subtitle2 = Subtitle(originalText: "Test", translatedText: "Test", language: "tr")
    
    // They should not be equal because they have different UUIDs
    #expect(subtitle1.id != subtitle2.id)
  }
}
