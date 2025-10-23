//
//  AIMemoryProcessor.swift
//  balli
//
//  Actor responsible for AI-powered memory processing
//  Handles fact extraction, summarization, and pattern analysis
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - AI Memory Processor Actor

actor AIMemoryProcessor {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync

    // MARK: - Initialization

    init() {
        logger.info("AIMemoryProcessor initialized")
    }

    // MARK: - Fact Extraction

    func extractFactsFromConversation(_ content: String) -> [String] {
        // Extract potential facts using pattern matching
        var facts: [String] = []

        // Pattern: "I am/have/use X"
        let patterns = [
            "ben .*? kullanıyorum",  // I use X
            "benim .*? var",          // I have X
            "ben .*? hastasıyım",     // I am X patient
            ".*? alerjim var",        // I'm allergic to X
            "günde .*? öğün",         // X meals per day
            "kahvaltıda .*? gram"     // X grams at breakfast
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let fact = String(content[range])
                        facts.append(fact)
                    }
                }
            }
        }

        return facts
    }

    // MARK: - Message Summarization

    /// Use AI to summarize a message for the recent tier
    func summarizeMessage(_ entry: MemoryEntry) -> String {
        // For now, use simple truncation
        // Could be enhanced with a dedicated Genkit summarization flow later
        let truncated = entry.content.prefix(100)
        return truncated.count < entry.content.count ? "\(truncated)..." : String(truncated)
    }

    // MARK: - Key Fact Extraction

    /// Extract key facts from a summary for historical tier
    func extractKeyFacts(_ entry: MemoryEntry) -> [String] {
        // Use pattern matching to extract key facts
        // Could be enhanced with Genkit AI-powered fact extraction later
        return extractFactsFromConversation(entry.content)
    }

    // MARK: - Recipe Detection

    func isRecipeContent(_ content: String) -> Bool {
        return content.contains("Malzemeler:") ||
               content.contains("Ingredients:") ||
               content.contains("Hazırlanışı:") ||
               content.contains("Instructions:")
    }

    func extractRecipeTitle(_ content: String) -> String? {
        // Extract first line as title or look for specific patterns
        let lines = content.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    // MARK: - Conversation Analysis

    /// Analyze conversation for important facts
    func analyzeConversationForFacts(_ messages: [MemoryEntry]) -> [(fact: String, confidence: Double)] {
        var facts: [(String, Double)] = []

        for message in messages {
            let extractedFacts = extractFactsFromConversation(message.content)

            for fact in extractedFacts {
                // Inferred facts have lower confidence
                facts.append((fact, 0.7))
            }
        }

        return facts
    }
}
