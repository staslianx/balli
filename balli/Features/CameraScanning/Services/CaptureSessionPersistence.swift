//
//  CaptureSessionPersistence.swift
//  balli
//
//  Persistence manager for capture sessions
//

import Foundation
import os.log

/// Actor for thread-safe capture session persistence
public actor CaptureSessionPersistence {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CaptureSessionPersistence")
    
    // File manager and URLs
    private let fileManager = FileManager.default
    private nonisolated let documentsDirectory: URL
    private nonisolated let sessionsDirectory: URL
    private nonisolated let imagesDirectory: URL
    
    // Session storage
    private var activeSession: CaptureSession?
    private var sessionHistory: [CaptureSession] = []
    
    // Persistence queue
    private let persistenceQueue = DispatchQueue(label: "com.balli.capture.persistence", qos: .utility)
    
    // MARK: - Initialization

    /// Initialize with full persistence
    public init() throws {
        // Setup directories
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CaptureError.unknownError("Failed to access documents directory")
        }

        self.documentsDirectory = documentsURL
        self.sessionsDirectory = documentsURL.appendingPathComponent("CaptureSessions", isDirectory: true)
        self.imagesDirectory = documentsURL.appendingPathComponent("CaptureImages", isDirectory: true)

        // Create directories if needed
        try createDirectoriesIfNeeded()

        // Load existing sessions
        Task {
            await loadPersistedSessions()
        }
    }

    /// Initialize with in-memory fallback (no disk persistence)
    /// Used when file system is unavailable or corrupted
    private init(inMemoryOnly: Bool) {
        // Use temporary directory for in-memory mode
        let tempURL = FileManager.default.temporaryDirectory
        self.documentsDirectory = tempURL
        self.sessionsDirectory = tempURL.appendingPathComponent("CaptureSessions_temp", isDirectory: true)
        self.imagesDirectory = tempURL.appendingPathComponent("CaptureImages_temp", isDirectory: true)

        // Note: We don't create directories or load persisted sessions in fallback mode
    }

    /// Factory method to create in-memory fallback instance
    public static func inMemoryFallback() -> CaptureSessionPersistence {
        return CaptureSessionPersistence(inMemoryOnly: true)
    }
    
    // MARK: - Public Methods
    
    /// Save capture session
    public func saveSession(_ session: CaptureSession) async throws {
        logger.debug("Saving session: \(session.id)")
        
        // Update active session
        if session.isActive {
            activeSession = session
            UserDefaults.standard.set(session.id.uuidString, forKey: CaptureSessionKeys.activeSessionKey)
        }
        
        // Save session data
        let sessionURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Create session copy without image data for JSON
        var sessionForJSON = session
        sessionForJSON.imageData = nil
        sessionForJSON.thumbnailData = nil
        sessionForJSON.optimizedImageData = nil
        
        let sessionData = try encoder.encode(sessionForJSON)
        try sessionData.write(to: sessionURL)
        
        // Save image data separately
        if let imageData = session.imageData {
            let imageURL = imagesDirectory.appendingPathComponent("\(session.id.uuidString)_original.jpg")
            try imageData.write(to: imageURL)
        }
        
        if let thumbnailData = session.thumbnailData {
            let thumbnailURL = imagesDirectory.appendingPathComponent("\(session.id.uuidString)_thumbnail.jpg")
            try thumbnailData.write(to: thumbnailURL)
        }
        
        if let optimizedData = session.optimizedImageData {
            let optimizedURL = imagesDirectory.appendingPathComponent("\(session.id.uuidString)_optimized.jpg")
            try optimizedData.write(to: optimizedURL)
        }
        
        // Update history
        await updateHistory(with: session)
        
        logger.info("Session saved successfully: \(session.id)")
    }
    
    /// Load active session
    public func loadActiveSession() async -> CaptureSession? {
        // Check for active session ID
        guard let activeIDString = UserDefaults.standard.string(forKey: CaptureSessionKeys.activeSessionKey),
              let activeID = UUID(uuidString: activeIDString) else {
            return nil
        }
        
        // Load session
        do {
            let session = try await loadSession(id: activeID)
            
            // Check if session is still valid
            if !session.isExpired && session.isActive {
                activeSession = session
                return session
            } else {
                // Clear expired active session
                UserDefaults.standard.removeObject(forKey: CaptureSessionKeys.activeSessionKey)
                await deleteSession(id: activeID)
                return nil
            }
        } catch {
            logger.error("Failed to load active session: \(error)")
            return nil
        }
    }
    
    /// Load session by ID
    public func loadSession(id: UUID) async throws -> CaptureSession {
        let sessionURL = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        
        guard fileManager.fileExists(atPath: sessionURL.path) else {
            throw CaptureError.sessionExpired
        }
        
        // Load session JSON
        let sessionData = try Data(contentsOf: sessionURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var session = try decoder.decode(CaptureSession.self, from: sessionData)
        
        // Load image data
        let originalURL = imagesDirectory.appendingPathComponent("\(id.uuidString)_original.jpg")
        if fileManager.fileExists(atPath: originalURL.path) {
            session.imageData = try? Data(contentsOf: originalURL)
        }
        
        let thumbnailURL = imagesDirectory.appendingPathComponent("\(id.uuidString)_thumbnail.jpg")
        if fileManager.fileExists(atPath: thumbnailURL.path) {
            session.thumbnailData = try? Data(contentsOf: thumbnailURL)
        }
        
        let optimizedURL = imagesDirectory.appendingPathComponent("\(id.uuidString)_optimized.jpg")
        if fileManager.fileExists(atPath: optimizedURL.path) {
            session.optimizedImageData = try? Data(contentsOf: optimizedURL)
        }
        
        return session
    }
    
    /// Get session history
    public func getSessionHistory() async -> [CaptureSession] {
        return sessionHistory
    }
    
    /// Delete session
    public func deleteSession(id: UUID) async {
        logger.debug("Deleting session: \(id)")
        
        // Remove from active session
        if activeSession?.id == id {
            activeSession = nil
            UserDefaults.standard.removeObject(forKey: CaptureSessionKeys.activeSessionKey)
        }
        
        // Remove from history
        sessionHistory.removeAll { $0.id == id }
        
        // Delete files
        let sessionURL = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: sessionURL)
        
        let imageFiles = [
            "\(id.uuidString)_original.jpg",
            "\(id.uuidString)_thumbnail.jpg",
            "\(id.uuidString)_optimized.jpg"
        ]
        
        for filename in imageFiles {
            let url = imagesDirectory.appendingPathComponent(filename)
            try? fileManager.removeItem(at: url)
        }
    }
    
    /// Clean up expired sessions
    public func cleanupExpiredSessions() async {
        logger.info("Cleaning up expired sessions")
        
        var expiredCount = 0
        
        // Check all session files
        do {
            let sessionFiles = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
            
            for file in sessionFiles where file.pathExtension == "json" {
                if let session = try? await loadSession(id: UUID(uuidString: file.deletingPathExtension().lastPathComponent) ?? UUID()) {
                    if session.isExpired {
                        await deleteSession(id: session.id)
                        expiredCount += 1
                    }
                }
            }
        } catch {
            logger.error("Failed to cleanup sessions: \(error)")
        }
        
        logger.info("Cleaned up \(expiredCount) expired sessions")
    }
    
    // MARK: - Private Methods
    
    private nonisolated func createDirectoriesIfNeeded() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: sessionsDirectory.path) {
            try fm.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        }
        
        if !fm.fileExists(atPath: imagesDirectory.path) {
            try fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func loadPersistedSessions() async {
        // Load session history
        do {
            let sessionFiles = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            // Sort by creation date
            let sortedFiles = sessionFiles.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            // Load recent sessions
            var loadedSessions: [CaptureSession] = []
            for file in sortedFiles.prefix(CaptureSessionKeys.maxHistoryCount) where file.pathExtension == "json" {
                if let idString = file.deletingPathExtension().lastPathComponent.components(separatedBy: "_").first,
                   let id = UUID(uuidString: idString),
                   let session = try? await loadSession(id: id) {
                    loadedSessions.append(session)
                }
            }
            
            sessionHistory = loadedSessions
            
        } catch {
            logger.error("Failed to load session history: \(error)")
        }
    }
    
    private func updateHistory(with session: CaptureSession) async {
        // Remove if already exists
        sessionHistory.removeAll { $0.id == session.id }
        
        // Add to beginning
        sessionHistory.insert(session, at: 0)
        
        // Maintain max history count
        if sessionHistory.count > CaptureSessionKeys.maxHistoryCount {
            let toRemove = sessionHistory.suffix(from: CaptureSessionKeys.maxHistoryCount)
            for session in toRemove {
                await deleteSession(id: session.id)
            }
            sessionHistory = Array(sessionHistory.prefix(CaptureSessionKeys.maxHistoryCount))
        }
    }
}