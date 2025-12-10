//
//  StringTests.swift
//  EnglishSubtitlesTests
//
//  Created by Amr Aboelela on 12/4/25.
//

import Testing
import Foundation
@testable import EnglishSubtitles

/// Tests for String extensions
struct StringTests {
  
  // MARK: - YouTube-style Hallucinations
  
  @Test func testYouTubeStyleHallucinations() {
    let youtubeHallucinations = [
      "Subscribe",
      "Don't forget to subscribe",
      "Like and subscribe",
      "Thanks for watching",
      "Thank you for watching",
      "See you in the next video", // Should be caught by "see you in the next"
      "See you in the next episode", // Should be caught by "see you in the next"
      "See you in the next"
    ]
    
    for hallucination in youtubeHallucinations {
      #expect(hallucination.isLikelyHallucination, "'\(hallucination)' should be detected as hallucination")
      #expect(hallucination.uppercased().isLikelyHallucination, "'\(hallucination.uppercased())' should be detected as hallucination")
      #expect(hallucination.lowercased().isLikelyHallucination, "'\(hallucination.lowercased())' should be detected as hallucination")
    }
  }
  
  @Test func testEndingPhraseHallucinations() {
    let endingPhrases = [
      "Bye",
      "Bye bye",
      "Goodbye",
      "See you later",
      "See you next time",
      "The end"
    ]
    
    for phrase in endingPhrases {
      #expect(phrase.isLikelyHallucination, "'\(phrase)' should be detected as hallucination")
    }
  }
  
  // MARK: - Credit Text Hallucinations
  
  @Test func testCreditTextHallucinations() {
    let creditTexts = [
      "Translated by XYZ Company",
      "Translation by AI Services",
      "Subtitle by Professional Team",
      "Subtitled by Expert Translators"
    ]
    
    for credit in creditTexts {
      #expect(credit.isLikelyHallucination, "'\(credit)' should be detected as hallucination")
    }
  }
  
  // MARK: - Bracketed Annotations
  
  @Test func testParenthesesAnnotations() {
    let parenthesesAnnotations = [
      "(music)",
      "(footsteps)",
      "(door opens)",
      "(applause)",
      "(laughter)",
      "(coughs)",
      "(silence)"
    ]
    
    for annotation in parenthesesAnnotations {
      #expect(annotation.isLikelyHallucination, "'\(annotation)' should be detected as hallucination")
    }
  }
  
  @Test func testSquareBracketAnnotations() {
    let squareBracketAnnotations = [
      "[music]",
      "[laughter]",
      "[applause]",
      "[phone rings]",
      "[door closes]"
    ]
    
    for annotation in squareBracketAnnotations {
      #expect(annotation.isLikelyHallucination, "'\(annotation)' should be detected as hallucination")
    }
  }
  
  @Test func testAsteriskAnnotations() {
    let asteriskAnnotations = [
      "*music playing*",
      "*door closes*",
      "*footsteps*",
      "*applause*",
      "*phone rings*"
    ]
    
    for annotation in asteriskAnnotations {
      #expect(annotation.isLikelyHallucination, "'\(annotation)' should be detected as hallucination")
    }
  }
  
  @Test func testDashAnnotations() {
    let dashAnnotations = [
      "-The End-",
      "-Credits-",
      "-Coming Soon-",
      "-To Be Continued-"
    ]
    
    for annotation in dashAnnotations {
      #expect(annotation.isLikelyHallucination, "'\(annotation)' should be detected as hallucination")
    }
  }
  
  // MARK: - Repetitive Patterns
  
  @Test func testRepetitiveDialoguePatterns() {
    let repetitivePatterns = [
      "I'm sorry, I'm sorry",
      "-Come on. -Come on.",
      "-Turkish. -Turkish.",
      "-I'm sorry. -It's okay.",
      "-Let's go. -Let's go."
    ]
    
    for pattern in repetitivePatterns {
      #expect(pattern.isLikelyHallucination, "'\(pattern)' should be detected as hallucination")
    }
  }
  
  @Test func testRepetitiveWordPatterns() {
    let repetitiveWords = [
      "a a a a",
      "the the the",
      "hello hello hello hello",
      "yes yes yes yes yes"
    ]
    
    for pattern in repetitiveWords {
      #expect(pattern.isLikelyHallucination, "'\(pattern)' should be detected as hallucination")
    }
  }
  
  // MARK: - Short Text Filter
  
  @Test func testVeryShortTextFilter() {
    let shortTexts = [
      ".",
      "?",
      "!",
      "a",
      "I",
      "..",
      "??",
      "!!"
    ]
    
    for text in shortTexts {
      #expect(text.isLikelyHallucination, "'\(text)' should be detected as hallucination")
    }
  }
  
  // MARK: - Valid Speech (Should NOT be filtered)
  
  @Test func testValidSpeechNotFiltered() {
    let validSpeech = [
      "Hello, how are you?",
      "I need to go to the store.",
      "The weather is nice today.",
      "Can you help me with this problem?",
      "This is a normal conversation.",
      "What time is the meeting?",
      "I'm working on the project.",
      "The movie was really good.",
      "Let's have dinner at six.",
      "Thank you for your help with the assignment."
    ]
    
    for speech in validSpeech {
      #expect(!speech.isLikelyHallucination, "'\(speech)' should NOT be detected as hallucination")
    }
  }
  
  @Test func testValidSpeechWithCommonWords() {
    // Test phrases that contain some filter words but in valid context
    let validPhrases = [
      "I need to subscribe to the newsletter", // Contains "subscribe" but in valid context
      "The music in the background was beautiful", // Contains "music" but not bracketed
      "He said goodbye to his friends", // Contains "goodbye" but in sentence
      "The end of the movie was surprising" // Contains "the end" but in sentence
    ]
    
    for phrase in validPhrases {
      #expect(!phrase.isLikelyHallucination, "'\(phrase)' should NOT be detected as hallucination")
    }
  }
  
  // MARK: - Edge Cases
  
  @Test func testWhitespaceHandling() {
    let whitespaceTests = [
      "  (music)  ", // Should still be detected with whitespace
      "\t[laughter]\n", // Should handle tabs and newlines
      "   bye   ", // Should handle whitespace around short hallucinations
      "  \n  "  // Only whitespace should not crash
    ]
    
    #expect(whitespaceTests[0].isLikelyHallucination, "Bracketed text with whitespace should be detected")
    #expect(whitespaceTests[1].isLikelyHallucination, "Bracketed text with tabs/newlines should be detected")
    #expect(whitespaceTests[2].isLikelyHallucination, "Short hallucination with whitespace should be detected")
    #expect(whitespaceTests[3].isLikelyHallucination, "Only whitespace should be detected as hallucination")
  }
  
  @Test func testEmptyAndNilHandling() {
    let emptyText = ""
    #expect(emptyText.isLikelyHallucination, "Empty string should be detected as hallucination")
  }
  
  @Test func testCaseInsensitivity() {
    // Test that detection works regardless of case
    let testCases = [
      ("SUBSCRIBE", true),
      ("Subscribe", true),
      ("subscribe", true),
      ("SuBsCrIbE", true),
      ("(MUSIC)", true),
      ("[LAUGHTER]", true),
      ("*DOOR CLOSES*", true),
      ("VALID SPEECH HERE", false)
    ]
    
    for (text, shouldBeHallucination) in testCases {
      if shouldBeHallucination {
        #expect(text.isLikelyHallucination, "'\(text)' should be detected as hallucination")
      } else {
        #expect(!text.isLikelyHallucination, "'\(text)' should NOT be detected as hallucination")
      }
    }
  }
  
  @Test func testPrefixMatching() {
    // Test that prefix matching works correctly
    let prefixTests = [
      ("Subscribe to my channel", true), // Starts with "subscribe"
      ("Translated by OpenAI and team", true), // Starts with "translated by"
      ("The subscription service", false), // Contains but doesn't start with "subscribe"
      ("I was translated by friends", false) // Contains but doesn't start with "translated by"
    ]
    
    for (text, shouldBeHallucination) in prefixTests {
      if shouldBeHallucination {
        #expect(text.isLikelyHallucination, "'\(text)' should be detected as hallucination")
      } else {
        #expect(!text.isLikelyHallucination, "'\(text)' should NOT be detected as hallucination")
      }
    }
  }
  
  // MARK: - Additional String Extension Tests
  
  @Test func testSubtitleSpecificHallucinations() {
    let subtitleHallucinations = [
      "subtitle",
      "subtitles",
      "captions",
      "Subtitle by Professional Team",
      "Subtitles provided by AI"
    ]
    
    for hallucination in subtitleHallucinations {
      #expect(hallucination.isLikelyHallucination, "'\(hallucination)' should be detected as hallucination")
    }
  }
  
  @Test func testPunctuationOnlyFilter() {
    let punctuationOnly = [
      ".",
      "?",
      "!",
      "...",
      "???",
      "!!!"
    ]
    
    for punctuation in punctuationOnly {
      #expect(punctuation.isLikelyHallucination, "'\(punctuation)' should be detected as hallucination")
    }
  }
  
  @Test func testMixedValidAndInvalidContent() {
    // Test strings that mix valid content with potential hallucination markers
    let mixedContent = [
      "Hello (music) world", // Contains bracketed annotation but also valid content
      "I want to subscribe and also buy something", // Contains "subscribe" but in valid sentence
      "The music was beautiful", // Contains "music" but not bracketed
      "Goodbye my friend", // Contains "goodbye" but in valid sentence
      "At the end of the day" // Contains "the end" but in valid phrase
    ]
    
    for content in mixedContent {
      // These should NOT be filtered as they contain substantial valid content
      #expect(!content.isLikelyHallucination, "'\(content)' should NOT be detected as hallucination")
    }
  }
  
  @Test func testRepeatedWordsThreshold() {
    let repeatedWords = [
      "hello hello", // 50% unique (1/2) - should not be filtered
      "hello hello hello", // 33% unique (1/3) - should be filtered
      "good morning good morning", // 50% unique (2/4) - should not be filtered
      "yes yes yes yes", // 25% unique (1/4) - should be filtered
      "a a a a a" // 20% unique (1/5) - should be filtered
    ]
    
    #expect(!repeatedWords[0].isLikelyHallucination, "50% unique words should not be filtered")
    #expect(repeatedWords[1].isLikelyHallucination, "33% unique words should be filtered")
    #expect(!repeatedWords[2].isLikelyHallucination, "50% unique words should not be filtered")
    #expect(repeatedWords[3].isLikelyHallucination, "25% unique words should be filtered")
    #expect(repeatedWords[4].isLikelyHallucination, "20% unique words should be filtered")
  }
}
