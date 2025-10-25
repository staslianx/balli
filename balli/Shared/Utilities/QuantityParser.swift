//
//  QuantityParser.swift
//  balli
//
//  Handles quantity and number parsing for ingredient parsing
//

import Foundation

public actor QuantityParser: QuantityParsing {
    
    // MARK: - Turkish Number System
    
    private let numberWords: [String: Double] = [
        "bir": 1, "iki": 2, "üç": 3, "dört": 4, "beş": 5,
        "altı": 6, "yedi": 7, "sekiz": 8, "dokuz": 9, "on": 10,
        "onbir": 11, "oniki": 12, "onüç": 13, "ondört": 14, "onbeş": 15,
        "yirmi": 20, "otuz": 30, "kırk": 40, "elli": 50,
        "yarım": 0.5, "çeyrek": 0.25, "üççeyrek": 0.75,
        "buçuk": 0.5 // as in "iki buçuk kilo" = 2.5 kg
    ]
    
    private let unitParser: UnitParser
    
    public init() {
        self.unitParser = UnitParser()
    }
    
    // MARK: - Quantity Extraction

    public func extractQuantity(from text: String) async -> (quantity: Double, unit: String, remainingWords: [String]) {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var quantity: Double = 1.0
        var unit = "adet"
        var nameWords: [String] = []
        var i = 0

        // Handle complex Turkish patterns
        while i < words.count {
            // Safe array access for current word
            guard let word = words[safe: i]?.lowercased() else {
                i += 1
                continue
            }

            // Pattern 1: Complex number patterns like "iki kilo üç yüz gram domates"
            if let num = await parseComplexNumber(startingAt: i, in: words) {
                quantity = num.value
                i = num.nextIndex

                // Look for unit after the number (check both single and multi-word units)
                if i < words.count {
                    // Try two-word unit first (e.g., "yemek kaşığı", "çay kaşığı")
                    if let currentWord = words[safe: i],
                       let nextWord = words[safe: i + 1] {
                        let potentialTwoWordUnit = (currentWord + " " + nextWord).lowercased()
                        if let unitType = await unitParser.classifyUnit(potentialTwoWordUnit) {
                            unit = unitType
                            i += 2
                            continue
                        }
                    }

                    // Try single-word unit
                    if let potentialUnit = words[safe: i]?.lowercased() {
                        if let unitType = await unitParser.classifyUnit(potentialUnit) {
                            unit = unitType
                            i += 1
                        }
                    }
                }
                continue
            }

            // Pattern 2: Direct unit recognition (check both single and multi-word units)
            // Try two-word unit first
            if let nextWord = words[safe: i + 1]?.lowercased() {
                let potentialTwoWordUnit = (word + " " + nextWord).lowercased()
                if let unitType = await unitParser.classifyUnit(potentialTwoWordUnit) {
                    unit = unitType
                    i += 2
                    continue
                }
            }

            // Try single-word unit
            if let unitType = await unitParser.classifyUnit(word) {
                unit = unitType
                i += 1
                continue
            }

            // Pattern 3: Everything else is part of the name
            if let currentWord = words[safe: i] {
                nameWords.append(currentWord)
            }
            i += 1
        }

        return (quantity: quantity, unit: unit, remainingWords: nameWords)
    }
    
    // MARK: - Complex Number Parsing
    
    public func parseComplexNumber(startingAt index: Int, in words: [String]) async -> (value: Double, nextIndex: Int)? {
        var currentIndex = index
        var totalValue: Double = 0
        var foundNumber = false
        
        // Handle cases like "iki kilo üç yüz gram" or "bir buçuk kilo"
        while currentIndex < words.count {
            let word = words[currentIndex].lowercased()
            
            // Direct number word
            if let numberValue = numberWords[word] {
                totalValue += numberValue
                foundNumber = true
                currentIndex += 1
                
                // Handle "buçuk" pattern: "iki buçuk" = 2.5
                if currentIndex < words.count && words[currentIndex].lowercased() == "buçuk" {
                    totalValue += 0.5
                    currentIndex += 1
                }
                continue
            }
            
            // Numeric digit
            if let numberValue = Double(word) {
                totalValue += numberValue
                foundNumber = true
                currentIndex += 1
                continue
            }
            
            // "yüz" (hundred) multiplier
            if word == "yüz" && foundNumber {
                totalValue *= 100
                currentIndex += 1
                continue
            }
            
            // If we haven't found any number yet, this might not be a number pattern
            if !foundNumber {
                return nil
            }
            
            // If we found numbers but this word isn't a number, we're done
            break
        }
        
        return foundNumber ? (value: totalValue, nextIndex: currentIndex) : nil
    }
    
    // MARK: - Quantity Pattern Recognition
    
    public func isQuantityStart(_ word: String, at index: Int, in words: [String]) async -> Bool {
        // Skip the first word (can't be a new pattern start)
        if index == 0 {
            return false
        }
        
        // Check if this word looks like a quantity
        if let _ = Double(word) {
            // It's a number, check if followed by a unit or food item
            return true
        }
        
        // Check if it's a written number
        if numberWords[word] != nil {
            return true
        }
        
        return false
    }
}