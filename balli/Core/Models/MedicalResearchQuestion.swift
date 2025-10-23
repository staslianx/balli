//
//  MedicalResearchQuestion.swift
//  balli
//
//  Medical research question flow models for targeted research
//

import Foundation

// MARK: - Medical Research Question Models

/// Represents a single research question with its category and answer
public struct MedicalResearchQuestion: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    let question: String
    let category: QuestionCategory
    var answer: String?
    
    public init(id: UUID = UUID(), question: String, category: QuestionCategory, answer: String? = nil) {
        self.id = id
        self.question = question
        self.category = category
        self.answer = answer
    }
    
    /// Question categories for targeted research
    public enum QuestionCategory: String, Codable, CaseIterable, Sendable {
        case kapsam = "kapsam"          // Scope: what aspect is most important
        case kişisel = "kişisel"        // Personal: user's specific situation
        case derinlik = "derinlik"      // Depth: level of information needed
        
        var displayName: String {
            switch self {
            case .kapsam: return "Kapsam"
            case .kişisel: return "Kişisel Durum"  
            case .derinlik: return "Bilgi Derinliği"
            }
        }
    }
}

/// Response structure from AI for generated questions
public struct MedicalQuestionResponse: Codable, Sendable {
    let questions: [QuestionData]
    
    struct QuestionData: Codable, Sendable {
        let question: String
        let category: String
    }
    
    /// Convert to MedicalResearchQuestion array
    func toResearchQuestions() -> [MedicalResearchQuestion] {
        return questions.compactMap { questionData in
            guard let category = MedicalResearchQuestion.QuestionCategory(rawValue: questionData.category) else {
                return nil
            }
            return MedicalResearchQuestion(
                question: questionData.question,
                category: category
            )
        }
    }
}

/// Complete research flow state
public struct MedicalResearchFlow: Codable, Sendable, Equatable {
    public let id: UUID
    let originalQuery: String
    let questions: [MedicalResearchQuestion]
    var currentQuestionIndex: Int
    let timestamp: Date
    
    public init(id: UUID = UUID(), originalQuery: String, questions: [MedicalResearchQuestion], currentQuestionIndex: Int = 0, timestamp: Date = Date()) {
        self.id = id
        self.originalQuery = originalQuery
        self.questions = questions
        self.currentQuestionIndex = currentQuestionIndex
        self.timestamp = timestamp
    }
    
    /// Check if all questions have been answered
    var isComplete: Bool {
        return questions.allSatisfy { $0.answer != nil }
    }
    
    /// Get current unanswered question
    var currentQuestion: MedicalResearchQuestion? {
        let unansweredQuestions = questions.filter { $0.answer == nil }
        return unansweredQuestions.first
    }
    
    /// Get progress as a ratio (0.0 to 1.0)
    var progress: Double {
        let answeredCount = questions.filter { $0.answer != nil }.count
        return Double(answeredCount) / Double(questions.count)
    }
    
    /// Generate enhanced search query using answers
    func enhancedSearchQuery() -> String {
        guard isComplete else { return originalQuery }
        
        var enhancedQuery = originalQuery
        let answers = questions.compactMap { $0.answer }.filter { !$0.isEmpty }
        
        if !answers.isEmpty {
            enhancedQuery += " " + answers.joined(separator: " ")
        }
        
        return enhancedQuery
    }
    
    /// Update with answer for a specific question
    func withAnswer(_ answer: String, for questionId: UUID) -> MedicalResearchFlow {
        let updatedQuestions = questions.map { question in
            var updated = question
            if question.id == questionId {
                updated.answer = answer
            }
            return updated
        }
        
        return MedicalResearchFlow(
            id: self.id,
            originalQuery: self.originalQuery,
            questions: updatedQuestions,
            currentQuestionIndex: self.currentQuestionIndex,
            timestamp: self.timestamp
        )
    }
}

// MARK: - Extensions

extension MedicalResearchFlow {
    /// Create a summary of the research context for AI
    var contextSummary: String {
        guard isComplete else { return originalQuery }
        
        var context = "Orijinal soru: \(originalQuery)\n\n"
        
        for question in questions {
            if let answer = question.answer, !answer.isEmpty {
                context += "\(question.category.displayName): \(answer)\n"
            }
        }
        
        return context
    }
}