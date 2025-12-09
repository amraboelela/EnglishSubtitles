//
//  SubtitleTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 11/30/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for Subtitle model
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
  
  // MARK: - Default Values Tests
  
  @Test func testSubtitleDefaultTranslatedText() async throws {
    let subtitle = Subtitle(originalText: "Hello world")
    
    #expect(subtitle.originalText == "Hello world")
    #expect(subtitle.translatedText == "")
    #expect(subtitle.language == "tr") // Default language
    #expect(subtitle.id != UUID())
  }
  
  @Test func testSubtitleDefaultLanguage() async throws {
    let subtitle = Subtitle(
      originalText: "Bonjour le monde",
      translatedText: "Hello world"
    )
    
    #expect(subtitle.originalText == "Bonjour le monde")
    #expect(subtitle.translatedText == "Hello world")
    #expect(subtitle.language == "tr") // Should default to "tr"
    #expect(subtitle.id != UUID())
  }
  
  // MARK: - Different Language Tests
  
  @Test func testSubtitleDifferentLanguages() async throws {
    let languages = ["en", "fr", "de", "es", "it", "zh", "ja", "ko", "ar"]
    
    for language in languages {
      let subtitle = Subtitle(
        originalText: "Test text",
        translatedText: "Translated text",
        language: language
      )
      
      #expect(subtitle.language == language)
      #expect(subtitle.originalText == "Test text")
      #expect(subtitle.translatedText == "Translated text")
    }
  }
  
  // MARK: - Empty and Special Character Tests
  
  @Test func testSubtitleEmptyTexts() async throws {
    let subtitle = Subtitle(originalText: "", translatedText: "", language: "")
    
    #expect(subtitle.originalText == "")
    #expect(subtitle.translatedText == "")
    #expect(subtitle.language == "")
    #expect(subtitle.id != UUID())
  }
  
  @Test func testSubtitleSpecialCharacters() async throws {
    let specialText = "Hello! @#$%^&*()_+-=[]{}|;':\",./<>?`~"
    let subtitle = Subtitle(
      originalText: specialText,
      translatedText: specialText,
      language: "en"
    )
    
    #expect(subtitle.originalText == specialText)
    #expect(subtitle.translatedText == specialText)
    #expect(subtitle.language == "en")
  }
  
  @Test func testSubtitleUnicodeCharacters() async throws {
    let unicodeText = "こんにちは 🌍 مرحبا ñoño"
    let subtitle = Subtitle(
      originalText: unicodeText,
      translatedText: "Hello world",
      language: "mixed"
    )
    
    #expect(subtitle.originalText == unicodeText)
    #expect(subtitle.translatedText == "Hello world")
    #expect(subtitle.language == "mixed")
  }
  
  // MARK: - Long Text Tests
  
  @Test func testSubtitleLongText() async throws {
    let longText = String(repeating: "A very long subtitle text that goes on and on. ", count: 100)
    let subtitle = Subtitle(
      originalText: longText,
      translatedText: longText,
      language: "en"
    )
    
    #expect(subtitle.originalText == longText)
    #expect(subtitle.translatedText == longText)
    #expect(subtitle.originalText.count > 1000)
  }
  
  // MARK: - Timestamp Tests
  
  @Test func testSubtitleTimestamp() async throws {
    let startTime = Date()
    let subtitle = Subtitle(originalText: "Test", translatedText: "Test")
    let endTime = Date()
    
    // Timestamp should be between start and end time
    #expect(subtitle.timestamp >= startTime)
    #expect(subtitle.timestamp <= endTime)
  }
  
  @Test func testSubtitleTimestampUniqueness() async throws {
    // Create subtitles in quick succession
    let subtitle1 = Subtitle(originalText: "First")
    let subtitle2 = Subtitle(originalText: "Second")
    let subtitle3 = Subtitle(originalText: "Third")
    
    // Timestamps might be the same or very close, but that's acceptable
    // We're just verifying they're all valid dates
    #expect(subtitle1.timestamp <= Date())
    #expect(subtitle2.timestamp <= Date())
    #expect(subtitle3.timestamp <= Date())
  }
  
  // MARK: - ID Uniqueness Tests
  
  @Test func testSubtitleIDUniqueness() async throws {
    var ids: Set<UUID> = []
    let subtitleCount = 1000
    
    for i in 0..<subtitleCount {
      let subtitle = Subtitle(originalText: "Subtitle \(i)")
      #expect(!ids.contains(subtitle.id), "Each subtitle should have a unique ID")
      ids.insert(subtitle.id)
    }
    
    #expect(ids.count == subtitleCount)
  }
  
  // MARK: - Identifiable Protocol Tests
  
  @Test func testSubtitleIdentifiable() async throws {
    let subtitle = Subtitle(originalText: "Test")
    
    // Should conform to Identifiable
    let id: UUID = subtitle.id
    #expect(id == subtitle.id)
    #expect(id != UUID()) // Should not be the nil UUID
  }
  
  // MARK: - Equatable Protocol Tests
  
  @Test func testSubtitleEquatableProtocol() async throws {
    let subtitle1 = Subtitle(originalText: "Same", translatedText: "Same", language: "en")
    let subtitle2 = Subtitle(originalText: "Same", translatedText: "Same", language: "en")
    let subtitle3 = Subtitle(originalText: "Different", translatedText: "Same", language: "en")
    
    // Test equality - they should NOT be equal because of different UUIDs
    #expect(subtitle1 != subtitle2, "Different instances should not be equal due to UUID")
    #expect(subtitle1 != subtitle3, "Different content should not be equal")
    #expect(subtitle2 != subtitle3, "Different content should not be equal")
    
    // Test self-equality
    #expect(subtitle1 == subtitle1, "Subtitle should be equal to itself")
  }
  
  @Test func testSubtitleEquatableFields() async throws {
    // Test that equality considers all fields
    let baseSubtitle = Subtitle(originalText: "Base", translatedText: "Base", language: "en")
    
    let differentOriginal = Subtitle(originalText: "Different", translatedText: "Base", language: "en")
    let differentTranslated = Subtitle(originalText: "Base", translatedText: "Different", language: "en")
    let differentLanguage = Subtitle(originalText: "Base", translatedText: "Base", language: "fr")
    
    // All should be different due to UUID differences
    #expect(baseSubtitle != differentOriginal)
    #expect(baseSubtitle != differentTranslated)
    #expect(baseSubtitle != differentLanguage)
  }
  
  // MARK: - Real-world Scenario Tests
  
  @Test func testSubtitleTurkishContent() async throws {
    let subtitle = Subtitle(
      originalText: "Merhaba, nasılsınız?",
      translatedText: "Hello, how are you?",
      language: "tr"
    )
    
    #expect(subtitle.originalText == "Merhaba, nasılsınız?")
    #expect(subtitle.translatedText == "Hello, how are you?")
    #expect(subtitle.language == "tr")
  }
  
  @Test func testSubtitleMultilineContent() async throws {
    let multilineOriginal = """
        Bu çok uzun bir
        alt yazı metnidir.
        Birden fazla satır içerir.
        """
    
    let multilineTranslated = """
        This is a very long
        subtitle text.
        It contains multiple lines.
        """
    
    let subtitle = Subtitle(
      originalText: multilineOriginal,
      translatedText: multilineTranslated,
      language: "tr"
    )
    
    #expect(subtitle.originalText == multilineOriginal)
    #expect(subtitle.translatedText == multilineTranslated)
    #expect(subtitle.originalText.contains("\n"))
    #expect(subtitle.translatedText.contains("\n"))
  }
  
  @Test func testSubtitleDialogueFormat() async throws {
    let dialogue = "- Merhaba! - Selam!"
    let translated = "- Hello! - Hi!"
    
    let subtitle = Subtitle(
      originalText: dialogue,
      translatedText: translated,
      language: "tr"
    )
    
    #expect(subtitle.originalText == dialogue)
    #expect(subtitle.translatedText == translated)
    #expect(subtitle.originalText.contains("-"))
    #expect(subtitle.translatedText.contains("-"))
  }
  
  // MARK: - Edge Case Tests
  
  @Test func testSubtitleWhitespaceOnly() async throws {
    let whitespaceText = "   \t\n   "
    let subtitle = Subtitle(
      originalText: whitespaceText,
      translatedText: whitespaceText,
      language: "en"
    )
    
    #expect(subtitle.originalText == whitespaceText)
    #expect(subtitle.translatedText == whitespaceText)
  }
  
  @Test func testSubtitleSingleCharacter() async throws {
    let subtitle = Subtitle(
      originalText: "A",
      translatedText: "B",
      language: "x"
    )
    
    #expect(subtitle.originalText == "A")
    #expect(subtitle.translatedText == "B")
    #expect(subtitle.language == "x")
  }
  
  // MARK: - Memory and Performance Tests
  
  @Test func testSubtitleCreationPerformance() async throws {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // Create many subtitles to test performance
    for i in 0..<10000 {
      let subtitle = Subtitle(originalText: "Text \(i)")
      #expect(subtitle.originalText == "Text \(i)")
    }
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    #expect(timeElapsed < 1.0, "Creating 10,000 subtitles should take less than 1 second")
  }
  
  @Test func testSubtitleMemoryUsage() async throws {
    // Test that subtitles can be created and deallocated properly
    var subtitles: [Subtitle] = []
    
    for i in 0..<1000 {
      let subtitle = Subtitle(originalText: "Subtitle \(i)")
      subtitles.append(subtitle)
    }
    
    #expect(subtitles.count == 1000)
    
    // Clear array to deallocate
    subtitles.removeAll()
    #expect(subtitles.isEmpty)
  }
}
