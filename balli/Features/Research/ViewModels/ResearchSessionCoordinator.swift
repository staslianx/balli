//
//  ResearchSessionCoordinator.swift
//  balli
//
//  Coordinates session lifecycle and persistence for medical research
//  Extracted from MedicalResearchViewModel for single responsibility
//

import Foundation
import OSLog

/// Coordinates research session management and persistence operations
@MainActor
final class ResearchSessionCoordinator {
    private let logger = AppLoggers.Research.search

    // Dependencies
    private let persistenceManager: ResearchPersistenceManager
    private let sessionManager: ResearchSessionManager

    init(
        persistenceManager: ResearchPersistenceManager,
        sessionManager: ResearchSessionManager
    ) {
        self.persistenceManager = persistenceManager
        self.sessionManager = sessionManager
    }

    // MARK: - Session Lifecycle

    func recoverActiveSession() async {
        await persistenceManager.recoverActiveSession(using: sessionManager)
    }

    func saveCurrentSession() async {
        await persistenceManager.saveCurrentSession(using: sessionManager)
    }

    func endCurrentSession() async {
        await persistenceManager.endCurrentSession(using: sessionManager)
    }

    // MARK: - History Management

    func loadSessionHistory(
        setSearchState: @escaping (ViewState<Void>) -> Void,
        setAnswers: @escaping ([SearchAnswer]) -> Void,
        rebuildLookup: @escaping () -> Void
    ) async {
        let loadedAnswers = await persistenceManager.loadSessionHistory()
        if !loadedAnswers.isEmpty {
            setSearchState(.loading)
            setAnswers(loadedAnswers)
            rebuildLookup()
            setSearchState(.loaded(()))
        }
    }

    func syncAnswersToPersistence(_ answers: [SearchAnswer]) async {
        await persistenceManager.syncAnswersToPersistence(answers)
    }
}
