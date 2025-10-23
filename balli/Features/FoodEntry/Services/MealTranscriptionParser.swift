//
//  MealTranscriptionParser.swift
//  balli
//
//  Local parser for extracting meal information from voice transcription
//  No network calls required - instant parsing
//

import Foundation

/// Parses Turkish voice transcription to extract meal data
struct MealTranscriptionParser {

    /// Parse transcription to extract carbs, time, and meal type
    static func parse(_ transcription: String) -> ParsedMealData {
        let text = transcription.lowercased()

        let carbsGrams = extractCarbs(from: text)
        let mealType = extractMealType(from: text)
        // Extract time with meal type context for smart AM/PM inference
        let timestamp = extractTime(from: text, mealType: mealType)

        return ParsedMealData(
            carbsGrams: carbsGrams,
            timestamp: timestamp,
            mealType: mealType
        )
    }

    // MARK: - Carbs Extraction

    private static func extractCarbs(from text: String) -> Int? {
        // Patterns: "30 gram", "30 gr", "30gram", "30g", "30 karbonhidrat"
        let patterns = [
            #"(\d+)\s*(?:gram|gr|g)\s*(?:karbonhidrat|karb)?"#,
            #"(\d+)\s*(?:karbonhidrat|karb)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let value = Int(text[range]) {
                return value
            }
        }

        return nil
    }

    // MARK: - Time Extraction

    private static func extractTime(from text: String, mealType: String?) -> Date? {
        // Patterns: "saat 9:15", "9:15", "saat 09:15", "9.15"
        let patterns = [
            #"(?:saat\s+)?(\d{1,2})[:.](\d{2})"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                if let hourRange = Range(match.range(at: 1), in: text),
                   let minuteRange = Range(match.range(at: 2), in: text),
                   var hour = Int(text[hourRange]),
                   let minute = Int(text[minuteRange]) {

                    // Smart AM/PM inference based on meal type context
                    if let mealType = mealType?.lowercased(), hour < 12 {
                        switch mealType {
                        case "akşam yemeği":
                            // Evening meal: convert to PM (e.g., 7 → 19)
                            hour += 12
                        case "öğle yemeği":
                            // Lunch: if hour is 1-11, it's likely PM (e.g., 1 → 13)
                            if hour > 0 && hour < 12 {
                                hour += 12
                            }
                        case "kahvaltı", "ara öğün":
                            // Breakfast/snack: use hour as-is (already AM)
                            break
                        default:
                            break
                        }
                    }

                    // Create date with adjusted time
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    components.hour = hour
                    components.minute = minute

                    return Calendar.current.date(from: components)
                }
            }
        }

        return nil
    }

    // MARK: - Meal Type Extraction

    private static func extractMealType(from text: String) -> String? {
        let mealTypes: [String: [String]] = [
            "kahvaltı": ["kahvaltı", "sabah"],
            "ara öğün": ["ara öğün", "öğle", "öğlen", "atıştırmalık", "snack"],
            "akşam yemeği": ["akşam", "akşam yemeği"]
        ]

        for (mealType, keywords) in mealTypes {
            for keyword in keywords {
                if text.contains(keyword) {
                    return mealType
                }
            }
        }

        return nil
    }
}
