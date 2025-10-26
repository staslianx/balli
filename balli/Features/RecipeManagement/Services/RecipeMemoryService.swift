//
//  RecipeMemoryService.swift
//  balli
//
//  Created by Claude Code
//  Recipe memory system - Business logic for memory management and ingredient analysis
//

import Foundation
import OSLog

/// Service providing business logic for recipe memory management
/// Handles ingredient analysis, frequency tracking, and recipe recording
@MainActor
final class RecipeMemoryService {
    // MARK: - Properties

    private let repository: RecipeMemoryRepository
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli.app",
        category: "RecipeMemory"
    )

    // MARK: - Ingredient Classification

    /// Common Turkish protein ingredients for classification
    private static let proteinIngredients: Set<String> = [
        "tavuk", "tavuk göğsü", "tavuk but", "hindi",
        "somon", "ton balığı", "levrek", "çipura", "hamsi", "sardalya", "karides",
        "dana eti", "kuzu eti", "kıyma", "köfte",
        "yumurta", "beyaz peynir", "lor peyniri", "süzme yoğurt", "kefir",
        "tofu", "tempeh", "edamame",
        "kırmızı mercimek", "yeşil mercimek", "nohut", "fasulye", "barbunya"
    ]

    /// Common Turkish vegetable ingredients for classification
    private static let vegetableIngredients: Set<String> = [
        "brokoli", "karnabahar", "lahana", "brüksel lahanası",
        "ıspanak", "roka", "marul", "semizotu", "tere",
        "domates", "salatalık", "biber", "sivri biber", "çarliston biber",
        "patlıcan", "kabak", "bal kabağı",
        "havuç", "kereviz", "kereviz sapı",
        "mantar", "kestane mantarı", "portobello",
        "kuşkonmaz", "pırasa", "soğan", "yeşil soğan", "sarımsak",
        "bamya", "taze fasulye", "bezelye", "mısır"
    ]

    // MARK: - Initialization

    init(repository: RecipeMemoryRepository = RecipeMemoryRepository()) {
        self.repository = repository
    }

    // MARK: - Public Methods

    /// Get recent ingredients from memory for a subcategory
    /// Returns up to the specified limit of most recent recipe ingredients
    /// - Parameters:
    ///   - subcategory: The subcategory to fetch from
    ///   - limit: Maximum number of recent recipes to consider (default: 10)
    /// - Returns: Array of ingredient arrays from recent recipes
    func getRecentIngredients(for subcategory: RecipeSubcategory, limit: Int = 10) async -> [[String]] {
        do {
            let recentEntries = try await repository.fetchRecentMemory(for: subcategory, limit: limit)
            logger.debug("Retrieved \(recentEntries.count) recent entries for \(subcategory.rawValue)")
            return recentEntries.map { $0.mainIngredients }
        } catch {
            logger.error("Failed to fetch recent ingredients: \(error.localizedDescription)")
            return []
        }
    }

    /// Analyze ingredient frequency across memory for a subcategory
    /// Returns ingredients sorted by usage frequency (least-used first)
    /// - Parameter subcategory: The subcategory to analyze
    /// - Returns: Dictionary mapping ingredient to usage count
    func analyzeIngredientFrequency(for subcategory: RecipeSubcategory) async -> [String: Int] {
        do {
            let allEntries = try await repository.fetchMemory(for: subcategory)
            var frequencyMap: [String: Int] = [:]

            for entry in allEntries {
                for ingredient in entry.mainIngredients {
                    frequencyMap[ingredient, default: 0] += 1
                }
            }

            logger.debug("Analyzed \(allEntries.count) entries, found \(frequencyMap.count) unique ingredients")
            return frequencyMap
        } catch {
            logger.error("Failed to analyze ingredient frequency: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Get least-used ingredients for variety suggestions
    /// - Parameters:
    ///   - subcategory: The subcategory to analyze
    ///   - proteinCount: Number of least-used proteins to return
    ///   - vegetableCount: Number of least-used vegetables to return
    /// - Returns: Tuple of (proteins, vegetables) sorted by usage (least-used first)
    func getLeastUsedIngredients(
        for subcategory: RecipeSubcategory,
        proteinCount: Int = 3,
        vegetableCount: Int = 3
    ) async -> (proteins: [String], vegetables: [String]) {
        logger.info("🎯 [VARIETY] Analyzing ingredient frequency for \(subcategory.rawValue)")
        let frequencyMap = await analyzeIngredientFrequency(for: subcategory)

        logger.info("🎯 [VARIETY] Found \(frequencyMap.count) unique ingredients in history")

        // Classify ingredients
        let proteinFrequencies = frequencyMap.filter { Self.isProtein($0.key) }
        let vegetableFrequencies = frequencyMap.filter { Self.isVegetable($0.key) }

        // Sort by frequency (ascending = least-used first)
        let leastUsedProteins = proteinFrequencies
            .sorted { $0.value < $1.value }
            .prefix(proteinCount)
            .map { $0.key }

        let leastUsedVegetables = vegetableFrequencies
            .sorted { $0.value < $1.value }
            .prefix(vegetableCount)
            .map { $0.key }

        logger.info("🎯 [VARIETY] ✅ Suggesting PROTEINS: \(leastUsedProteins.joined(separator: ", "))")
        logger.info("🎯 [VARIETY] ✅ Suggesting VEGETABLES: \(leastUsedVegetables.joined(separator: ", "))")

        return (Array(leastUsedProteins), Array(leastUsedVegetables))
    }

    /// Record a new recipe in memory
    /// - Parameters:
    ///   - subcategory: The subcategory to save to
    ///   - ingredients: Main ingredients of the recipe (will be normalized)
    ///   - recipeName: Optional name for debugging
    func recordRecipe(
        subcategory: RecipeSubcategory,
        ingredients: [String],
        recipeName: String? = nil
    ) async throws {
        logger.info("💾 [RECORD] Attempting to record recipe '\(recipeName ?? "Unknown")' in \(subcategory.rawValue)")
        logger.info("💾 [RECORD] Raw ingredients: \(ingredients.joined(separator: ", "))")

        guard !ingredients.isEmpty else {
            logger.error("💾 [RECORD] ❌ FAILED: Empty ingredients list")
            throw RecipeMemoryError.invalidMemoryEntry(reason: "Malzeme listesi boş olamaz")
        }

        guard ingredients.count <= 10 else {
            logger.error("💾 [RECORD] ❌ FAILED: Too many ingredients (\(ingredients.count))")
            throw RecipeMemoryError.invalidMemoryEntry(reason: "Çok fazla ana malzeme (maksimum 10)")
        }

        let entry = RecipeMemoryEntry(
            mainIngredients: ingredients,
            dateGenerated: Date(),
            subcategory: subcategory,
            recipeName: recipeName
        )

        logger.info("💾 [RECORD] Normalized ingredients: \(entry.mainIngredients.joined(separator: ", "))")

        try await repository.saveEntry(entry, for: subcategory)
        logger.info("💾 [RECORD] ✅ Successfully recorded in memory")
    }

    /// Get memory entries for Cloud Functions (serializable format)
    /// - Parameters:
    ///   - subcategory: The subcategory to fetch from
    ///   - limit: Maximum number of entries to return
    /// - Returns: Array of dictionaries ready for JSON serialization matching Cloud Functions schema
    func getMemoryForCloudFunctions(for subcategory: RecipeSubcategory, limit: Int = 10) async -> [[String: Any]] {
        do {
            let recentEntries = try await repository.fetchRecentMemory(for: subcategory, limit: limit)
            logger.debug("Retrieved \(recentEntries.count) entries for Cloud Functions")

            return recentEntries.map { entry in
                [
                    "mainIngredients": entry.mainIngredients,
                    "dateGenerated": ISO8601DateFormatter().string(from: entry.dateGenerated),
                    "subcategory": entry.subcategory.rawValue,
                    "recipeName": entry.recipeName as Any
                ]
            }
        } catch {
            logger.error("Failed to fetch memory for Cloud Functions: \(error.localizedDescription)")
            return []
        }
    }

    /// Clear memory for a specific subcategory or all subcategories
    /// - Parameter subcategory: The subcategory to clear, or nil for all
    func clearMemory(for subcategory: RecipeSubcategory? = nil) async throws {
        try await repository.clearMemory(for: subcategory)
        logger.info("Cleared memory for \(subcategory?.rawValue ?? "all subcategories")")
    }

    /// Get memory statistics for debugging
    /// - Returns: Dictionary mapping subcategory name to entry count
    func getMemoryStats() async throws -> [String: Int] {
        try await repository.getMemoryStats()
    }

    // MARK: - Private Classification Methods

    /// Checks if an ingredient is classified as a protein
    private static func isProtein(_ ingredient: String) -> Bool {
        let normalized = ingredient.lowercased()

        // Check against protein list
        if proteinIngredients.contains(normalized) {
            return true
        }

        // Check for common protein patterns
        let proteinKeywords = ["et", "balık", "tavuk", "peynir", "yoğurt", "mercimek", "fasulye", "nohut"]
        return proteinKeywords.contains { normalized.contains($0) }
    }

    /// Checks if an ingredient is classified as a vegetable
    private static func isVegetable(_ ingredient: String) -> Bool {
        let normalized = ingredient.lowercased()

        // Check against vegetable list
        return vegetableIngredients.contains(normalized)
    }
}

// MARK: - Testing Support

#if DEBUG
extension RecipeMemoryService {
    /// Creates a test service with in-memory repository
    static func testService() -> RecipeMemoryService {
        RecipeMemoryService(repository: RecipeMemoryRepository.testRepository())
    }
}
#endif
