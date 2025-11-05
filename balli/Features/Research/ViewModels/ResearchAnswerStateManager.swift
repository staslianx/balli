//
//  ResearchAnswerStateManager.swift
//  balli
//
//  Answer state management for research feature
//  Manages answers array, lookup indices, and derived state
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI

/// Manages answer state and provides O(1) lookups
/// Extracted from MedicalResearchViewModel to maintain single responsibility principle
@MainActor
final class ResearchAnswerStateManager: ObservableObject {
    // MARK: - Published State

    /// Data store accumulates answers over time (not replaced wholesale)
    /// Stored in reverse chronological order: [newest, older, oldest]
    @Published private(set) var answers: [SearchAnswer] = []

    /// Track source searching per answer
    @Published var searchingSourcesForAnswer: [String: Bool] = [:]

    // MARK: - Private State

    /// O(1) lookup dictionary for answer index (answerId -> array index)
    /// Eliminates O(n) linear search called 5-15x per response
    private var answerIndexLookup: [String: Int] = [:]

    /// Track which answers have already triggered first token arrival
    /// Prevents handleFirstTokenArrival from being called multiple times per answer
    private var firstTokenProcessed: Set<String> = []

    // MARK: - Computed Properties

    /// Answers in chronological order (oldest → newest) for UI display
    /// This eliminates the need for .reversed() in the view, improving performance
    var answersInChronologicalOrder: [SearchAnswer] {
        Array(answers.reversed())
    }

    /// History for library (alias for backward compatibility)
    var answerHistory: [SearchAnswer] {
        answers
    }

    // MARK: - Answer Management

    /// Insert a new answer at the specified index (default: prepend to beginning)
    func insertAnswer(_ answer: SearchAnswer, at index: Int = 0) {
        answers.insert(answer, at: index)
        rebuildLookup()
    }

    /// Update an answer at a specific index
    func updateAnswer(at index: Int, with answer: SearchAnswer) {
        guard answers.indices.contains(index) else { return }
        answers[index] = answer
        // STREAMING FIX: Explicitly trigger @Published update for array mutations
        // Swift 6: Subscript mutations don't always trigger @Published automatically
        objectWillChange.send()
    }

    /// Remove an answer at a specific index
    func removeAnswer(at index: Int) {
        guard answers.indices.contains(index) else { return }
        answers.remove(at: index)
        rebuildLookup()
    }

    /// Remove all answers
    func removeAllAnswers() {
        answers.removeAll()
        answerIndexLookup.removeAll()
        searchingSourcesForAnswer.removeAll()
        firstTokenProcessed.removeAll()
    }

    // MARK: - Lookup Operations

    /// Get answer index by ID (O(1) lookup)
    func getAnswerIndex(for answerId: String) -> Int? {
        answerIndexLookup[answerId]
    }

    /// Get answer by ID (O(1) lookup + array access)
    func getAnswer(for answerId: String) -> SearchAnswer? {
        guard let index = answerIndexLookup[answerId],
              answers.indices.contains(index) else {
            return nil
        }
        return answers[index]
    }

    // MARK: - First Token Tracking

    /// Mark that first token has been processed for this answer
    func markFirstTokenProcessed(for answerId: String) {
        firstTokenProcessed.insert(answerId)
    }

    /// Check if first token has been processed for this answer
    func isFirstTokenProcessed(for answerId: String) -> Bool {
        firstTokenProcessed.contains(answerId)
    }

    /// Clear first token tracking for an answer (used when clearing)
    func clearFirstTokenTracking(for answerId: String) {
        firstTokenProcessed.remove(answerId)
    }

    // MARK: - Source Search Tracking

    /// Set source searching state for an answer
    func setSearchingSource(for answerId: String, isSearching: Bool) {
        searchingSourcesForAnswer[answerId] = isSearching
    }

    /// Clear source searching state for an answer
    func clearSearchingSource(for answerId: String) {
        searchingSourcesForAnswer.removeValue(forKey: answerId)
    }

    // MARK: - Private Helpers

    /// Rebuild the answer index lookup dictionary for O(1) access
    /// Called after insertions or removals that change indices
    private func rebuildLookup() {
        answerIndexLookup.removeAll(keepingCapacity: true)
        for (index, answer) in answers.enumerated() {
            answerIndexLookup[answer.id] = index
        }
    }
}
