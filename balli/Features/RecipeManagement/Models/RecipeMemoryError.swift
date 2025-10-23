//
//  RecipeMemoryError.swift
//  balli
//
//  Created by Claude Code
//  Recipe memory system - Custom error types with Turkish user-facing messages
//

import Foundation

/// Errors that can occur in the recipe memory system
enum RecipeMemoryError: LocalizedError, Sendable {
    /// Failed to read from UserDefaults
    case storageReadFailure(underlying: Error?)

    /// Failed to write to UserDefaults
    case storageWriteFailure(underlying: Error?)

    /// Failed to encode data for storage
    case encodingFailure(underlying: Error)

    /// Failed to decode data from storage
    case decodingFailure(underlying: Error)

    /// Invalid subcategory provided
    case invalidSubcategory(name: String)

    /// Memory entry validation failed
    case invalidMemoryEntry(reason: String)

    /// Failed to extract ingredients from recipe
    case ingredientExtractionFailure(underlying: Error?)

    /// Similarity check failed
    case similarityCheckFailure(underlying: Error)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        case .storageReadFailure:
            return "Tarif geçmişi yüklenirken bir sorun oluştu."

        case .storageWriteFailure:
            return "Tarif geçmişi kaydedilirken bir sorun oluştu."

        case .encodingFailure, .decodingFailure:
            return "Veri işlenirken bir sorun oluştu."

        case .invalidSubcategory(let name):
            return "Geçersiz yemek kategorisi: \(name)"

        case .invalidMemoryEntry(let reason):
            return "Geçersiz tarif kaydı: \(reason)"

        case .ingredientExtractionFailure:
            return "Tarif malzemeleri analiz edilirken bir sorun oluştu."

        case .similarityCheckFailure:
            return "Tarif benzerliği kontrol edilirken bir sorun oluştu."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storageReadFailure, .storageWriteFailure, .decodingFailure, .encodingFailure:
            return "Lütfen uygulamayı yeniden başlatıp tekrar deneyin."

        case .invalidSubcategory:
            return "Lütfen geçerli bir yemek kategorisi seçin."

        case .invalidMemoryEntry:
            return "Bu tarif geçmişe kaydedilemedi, ancak yeni tarif oluşturmaya devam edebilirsiniz."

        case .ingredientExtractionFailure:
            return "Tarif oluşturuldu ancak geçmişe eklenemedi. Yeni tarif oluşturmaya devam edebilirsiniz."

        case .similarityCheckFailure:
            return "Benzerlik kontrolü başarısız oldu, ancak tarif oluşturuldu."
        }
    }

    var failureReason: String? {
        switch self {
        case .storageReadFailure(let error), .storageWriteFailure(let error),
             .ingredientExtractionFailure(let error):
            return error?.localizedDescription

        case .encodingFailure(let error), .decodingFailure(let error), .similarityCheckFailure(let error):
            return error.localizedDescription

        case .invalidSubcategory(let name):
            return "Kategori bulunamadı: \(name)"

        case .invalidMemoryEntry(let reason):
            return reason
        }
    }
}

// MARK: - Error Recovery

extension RecipeMemoryError {
    /// Determines if the operation should continue despite this error
    /// Recipe generation should not be blocked by memory system failures
    var shouldContinue: Bool {
        switch self {
        case .storageReadFailure, .storageWriteFailure,
             .ingredientExtractionFailure, .similarityCheckFailure:
            return true  // Fail open - don't block user

        case .invalidSubcategory, .invalidMemoryEntry,
             .encodingFailure, .decodingFailure:
            return false  // These indicate programming errors
        }
    }

    /// Whether this error should be logged at error level
    var isLoggableError: Bool {
        switch self {
        case .storageReadFailure, .storageWriteFailure,
             .encodingFailure, .decodingFailure:
            return true  // Storage issues are errors

        case .ingredientExtractionFailure, .similarityCheckFailure:
            return false  // These are warnings, not errors

        case .invalidSubcategory, .invalidMemoryEntry:
            return true  // Programming errors
        }
    }
}
