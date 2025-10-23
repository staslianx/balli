//
//  CaptureSessionManager.swift
//  balli
//
//  Session management for capture flow
//

import Foundation
import UIKit
import os.log

// MARK: - Capture Session Manager

@MainActor
public final class CaptureSessionManager: CaptureSessionManaging, ObservableObject {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureSessionManager")
    
    // MARK: - Published Properties
    @Published public private(set) var currentSession: CaptureSession?
    @Published public private(set) var recentSessions: [CaptureSession] = []
    
    // MARK: - Dependencies
    private let persistenceManager: CaptureSessionPersistence
    private let configuration: CaptureConfiguration
    
    // MARK: - Private Properties
    private var stateRestorationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    public init(
        persistenceManager: CaptureSessionPersistence,
        configuration: CaptureConfiguration = .default
    ) {
        self.persistenceManager = persistenceManager
        self.configuration = configuration
        
        restoreState()
    }
    
    // MARK: - Session Management
    
    public func createSession(with zoomLevel: String? = nil) async -> CaptureSession {
        logger.info("Creating new capture session")
        
        let session = CaptureSession(
            id: UUID(),
            timestamp: Date(),
            state: .capturing,
            imageData: nil,
            thumbnailData: nil,
            optimizedImageData: nil,
            aiResponse: nil,
            error: nil,
            retryCount: 0,
            processingStartTime: Date(),
            processingEndTime: nil,
            imageSize: nil,
            captureZoomLevel: zoomLevel
        )
        
        currentSession = session
        
        // Save initial session state
        do {
            try await persistenceManager.saveSession(session)
        } catch {
            logger.error("Failed to save initial session: \(error)")
        }
        
        return session
    }
    
    public func updateSession(_ sessionId: UUID, update: (inout CaptureSession) -> Void) async {
        guard var session = currentSession, session.id == sessionId else {
            logger.warning("Attempted to update non-current session: \(sessionId)")
            return
        }
        
        update(&session)
        currentSession = session
        
        // Persist changes
        do {
            try await persistenceManager.saveSession(session)
        } catch {
            logger.error("Failed to save session update: \(error)")
        }
    }
    
    public func saveSession(_ session: CaptureSession) async throws {
        try await persistenceManager.saveSession(session)
        
        // Update current session if it matches
        if session.id == currentSession?.id {
            currentSession = session
        }
        
        // Update history
        await updateHistory(with: session)
    }
    
    public func loadSession(id: UUID) async -> CaptureSession? {
        do {
            return try await persistenceManager.loadSession(id: id)
        } catch {
            logger.error("Failed to load session \(id): \(error)")
            return nil
        }
    }
    
    public func deleteSession(id: UUID) async {
        await persistenceManager.deleteSession(id: id)
        recentSessions.removeAll { $0.id == id }
        
        if currentSession?.id == id {
            currentSession = nil
        }
    }
    
    public func clearHistory() async {
        for session in recentSessions {
            await persistenceManager.deleteSession(id: session.id)
        }
        recentSessions.removeAll()
    }
    
    // MARK: - State Management
    
    public func markSessionCompleted(_ sessionId: UUID) async {
        await updateSession(sessionId) { session in
            session.state = .completed
            session.processingEndTime = Date()
        }
        
        if let completedSession = currentSession {
            await updateHistory(with: completedSession)
        }
    }
    
    public func markSessionFailed(_ sessionId: UUID, error: String) async {
        await updateSession(sessionId) { session in
            session.state = .failed
            session.error = error
            session.processingEndTime = Date()
        }
    }
    
    public func markSessionCancelled(_ sessionId: UUID) async {
        await updateSession(sessionId) { session in
            session.state = .cancelled
            session.processingEndTime = Date()
        }
    }
    
    // MARK: - Session Queries
    
    public func getActiveSession() async -> CaptureSession? {
        return await persistenceManager.loadActiveSession()
    }
    
    public func canRetrySession(_ session: CaptureSession) -> Bool {
        return session.canRetry && session.retryCount < configuration.maxRetryCount
    }
    
    public func isSessionExpired(_ session: CaptureSession) -> Bool {
        return Date().timeIntervalSince(session.timestamp) > configuration.sessionExpirationInterval
    }
    
    // MARK: - Cleanup
    
    public func cleanupExpiredSessions() async {
        await persistenceManager.cleanupExpiredSessions()
        
        // Remove expired sessions from history
        recentSessions.removeAll { isSessionExpired($0) }
    }
    
    // MARK: - Private Methods
    
    private func restoreState() {
        stateRestorationTask = Task {
            logger.info("Restoring session state")
            
            // Load active session
            if let activeSession = await persistenceManager.loadActiveSession() {
                logger.info("Found active session: \(activeSession.id), state: \(activeSession.state.rawValue)")
                self.currentSession = activeSession
            }
            
            // Load recent sessions
            let history = await persistenceManager.getSessionHistory()
            self.recentSessions = history
            
            // Cleanup expired sessions
            await cleanupExpiredSessions()
        }
    }
    
    private func updateHistory(with session: CaptureSession) async {
        // Remove if already exists
        recentSessions.removeAll { $0.id == session.id }
        
        // Add to beginning
        recentSessions.insert(session, at: 0)
        
        // Maintain max history count
        if recentSessions.count > configuration.maxHistoryCount {
            recentSessions = Array(recentSessions.prefix(configuration.maxHistoryCount))
        }
    }
}