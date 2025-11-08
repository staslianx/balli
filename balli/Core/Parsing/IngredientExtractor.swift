//
//  IngredientExtractor.swift
//  balli
//
//  Handles ingredient extraction, categorization, and text splitting
//

import Foundation

public actor IngredientExtractor: IngredientExtracting {
    
    // MARK: - Category System
    
    private let categoryKeywords: [String: [String]] = [
        "meyve_sebze": ["elma", "armut", "muz", "portakal", "limon", "mandalina", "domates", "salatalık", "soğan", "patates", "havuç", "biber", "patlıcan", "kabak", "marul", "roka", "maydanoz", "dereotu", "tere"],
        "et_tavuk_balık": ["et", "tavuk", "balık", "dana", "kuzu", "köfte", "sosis", "jambon", "ton balığı", "somon", "levrek", "çupra", "hindi", "kıyma"],
        "süt_ürünleri": ["süt", "peynir", "yoğurt", "tereyağı", "kaymak", "krema", "labne", "beyaz peynir", "kaşar", "tulum", "çökelek", "lor"],
        "ekmek": ["ekmek", "pide", "simit", "poğaça", "lavaş", "bazlama", "naan", "somun", "francala"],
        "konserve": ["salça", "konserve", "turşu", "reçel", "bal", "pekmez", "sos", "ketçap", "mayonez", "hardal"],
        "bakliyat": ["pirinç", "bulgur", "nohut", "fasulye", "mercimek", "börülce", "barbunya", "makarna", "şehriye"],
        "yağ": ["zeytinyağı", "ayçiçek yağı", "tereyağı", "margarin", "sıvıyağ"],
        "içecek": ["su", "çay", "kahve", "meyve suyu", "kola", "gazoz", "ayran", "şalgam", "bira"],
        "temizlik": ["deterjan", "sabun", "şampuan", "diş macunu", "temizlik", "çamaşır suyu"],
        "atıştırmalık": ["çips", "bisküvi", "çikolata", "gofret", "kraker", "fıstık", "ceviz", "badem"]
    ]
    
    private let commonFoodEndings = [
        "domates", "salatalık", "patates", "soğan", "biber", "patlıcan", "havuç",
        "ekmek", "peynir", "yoğurt", "süt", "tereyağı",
        "et", "tavuk", "balık", "köfte",
        "pirinç", "bulgur", "makarna", "un",
        "tuz", "şeker", "yağ", "sirke",
        "elma", "muz", "portakal", "limon"
    ]
    
    public init() {}
    
    // MARK: - Text Splitting
    
    public func splitIntelligently(_ text: String) async -> [String] {
        // First, try explicit delimiter-based splitting
        var processed = text
        processed = processed.replacingOccurrences(of: " ve ", with: ", ")
        processed = processed.replacingOccurrences(of: " ile ", with: ", ")
        processed = processed.replacingOccurrences(of: " ayrıca ", with: ", ")
        processed = processed.replacingOccurrences(of: " hem ", with: ", ")
        
        // If we found explicit delimiters, use them
        if processed.contains(",") || processed.contains(";") || processed.contains("\n") {
            return processed.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        // Otherwise, try pattern-based splitting for cases like "2 kilo domates 1 kilo salatalık"
        return await splitByQuantityPatterns(text)
    }
    
    // MARK: - Pattern-Based Splitting
    
    private func splitByQuantityPatterns(_ text: String) async -> [String] {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // If too few words, treat as single item
        if words.count <= 3 {
            return [text]
        }
        
        var segments: [String] = []
        var currentSegment: [String] = []
        var i = 0
        
        while i < words.count {
            let word = words[i].lowercased()
            
            // Check if this word starts a new quantity pattern
            if await isQuantityStart(word, at: i, in: words) && !currentSegment.isEmpty {
                // Save the current segment and start a new one
                segments.append(currentSegment.joined(separator: " "))
                currentSegment = []
            }
            
            currentSegment.append(words[i])
            i += 1
        }
        
        // Add the final segment
        if !currentSegment.isEmpty {
            segments.append(currentSegment.joined(separator: " "))
        }
        
        // If we couldn't split meaningfully, return the original text
        if segments.count <= 1 {
            return [text]
        }
        
        return segments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    private func isQuantityStart(_ word: String, at index: Int, in words: [String]) async -> Bool {
        // Skip the first word (can't be a new pattern start)
        if index == 0 {
            return false
        }
        
        // Check if this word looks like a quantity
        if let _ = Double(word) {
            return true
        }
        
        // Check if it's a written number (basic check)
        let numberWords = ["bir", "iki", "üç", "dört", "beş", "altı", "yedi", "sekiz", "dokuz", "on"]
        if numberWords.contains(word) {
            return true
        }
        
        // Check if previous word could be the end of a food item
        if index > 0 {
            let prevWord = words[index - 1].lowercased()
            if await isLikelyFoodItemEnd(prevWord) && (Double(word) != nil || numberWords.contains(word)) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Food Item Recognition
    
    public func isLikelyFoodItemEnd(_ word: String) async -> Bool {
        // Check if word ends with common food suffixes
        for food in commonFoodEndings {
            if word.hasSuffix(food) || word == food {
                return true
            }
        }
        
        // Also check category-based foods
        for keywords in categoryKeywords.values {
            if keywords.contains(word) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Categorization
    
    public func categorizeIngredient(_ name: String) async -> String {
        let lowercaseName = name.lowercased()
        
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowercaseName.contains(keyword) {
                    return category
                }
            }
        }
        
        return "genel"
    }
    
    // MARK: - Confidence Calculation
    
    public func calculateConfidence(original: String, name: String, quantity: Double, unit: String) async -> Double {
        var confidence = 0.7 // Base confidence
        
        // Higher confidence for explicit quantities
        if quantity != 1.0 || unit != "adet" {
            confidence += 0.2
        }
        
        // Higher confidence for longer, more descriptive names
        if name.count >= 4 {
            confidence += 0.1
        }
        
        // Higher confidence for known categories
        if await categorizeIngredient(name) != "genel" {
            confidence += 0.1
        }
        
        // Lower confidence for very short names
        if name.count < 3 {
            confidence -= 0.3
        }
        
        return min(1.0, max(0.1, confidence))
    }
}