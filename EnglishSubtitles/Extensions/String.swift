//
//  String.swift
//  EnglishSubtitles
//
//  Created by Amr Aboelela on 12/4/25.
//

import Foundation

extension String {
    /// Filter out common WhisperKit hallucinations (YouTube phrases, credits, sound annotations, repetitive text)
    /// - Returns: True if text should be filtered out, false if likely real speech
    var isLikelyHallucination: Bool {
        let lowercased = self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Common hallucination patterns for silence/background noise
        let hallucinations = [
            "see you in next video",
            "see you in the next",
            "subscribe",
            "don't forget to subscribe",
            "like and subscribe",
            "thanks for watching",
            "thank you",
            "bye bye",
            "- bye.",
            "bye.",
            "-i'm going.",
            "for example.",
            "see you.",
            "-what? -what?",
            "wow.",
            "see you later",
            "see you next time",
            "music",
            "applause",
            "laughter",
            "silence",
            "translated by",
            "-thank you.",
            "translation by",
            "subtitle by",
            "subtitled by",
            "-goodbye.",
            "bye!",
            "please subscribe",
            "i'm sorry, i'm sorry",
            "-come on. -come on.",
            "-turkish. -turkish.",
            "-i'm sorry. -it's okay.",
            "-let's go. -let's go.",
            ".",
            "?",
            "!",
            "...",
            "subtitle",
            "subtitles",
            "captions"
        ]

        // Exact matches only for potentially ambiguous words
        let exactMatches = [
            "bye",
            "goodbye",
            "the end"
        ]

        // Check for exact matches or if text starts with common patterns
        for hallucination in hallucinations {
            if lowercased == hallucination || lowercased.hasPrefix(hallucination) {
                return true
            }
        }

        // Check for exact matches only (not prefix)
        for exactMatch in exactMatches {
            if lowercased == exactMatch {
                return true
            }
        }

        // Filter very short outputs (likely hallucinations)
        if lowercased.count <= 2 {
            return true
        }

        // Filter repetitive patterns (e.g., "a a a a")
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)
        if words.count > 1 {
            let uniqueWords = Set(words)
            // If most words are the same, likely a hallucination
            if Double(uniqueWords.count) / Double(words.count) < 0.5 {
                return true
            }
        }

        // Filter bracketed annotations like (music), [laughter], (footsteps), *door closes*, -The End-
        let trimmed = lowercased.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("(") && trimmed.hasSuffix(")")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) ||
           (trimmed.hasPrefix("*") && trimmed.hasSuffix("*")) ||
           (trimmed.hasPrefix("-") && trimmed.hasSuffix("-")) {
            return true
        }

        return false
    }
}
