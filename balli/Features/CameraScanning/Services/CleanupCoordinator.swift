//
//  CleanupCoordinator.swift
//  balli
//
//  Manages proper cleanup of camera resources and observers
//

import Foundation
import AVFoundation
import os.log

/// Coordinates cleanup of camera resources to prevent memory leaks
public actor CleanupCoordinator {
    private let logger = os.Logger(subsystem: "com.balli.diabetes", category: "CleanupCoordinator")
    
    // MARK: - Cleanup Registry
    private struct CleanupItem {
        let id: UUID
        let type: CleanupType
        let description: String
        let cleanup: @Sendable () async -> Void
        let priority: CleanupPriority
    }
    
    public enum CleanupType {
        case observer
        case continuation
        case session
        case delegate
        case resource
    }
    
    public enum CleanupPriority: Int, Comparable {
        case critical = 0  // Must clean immediately (continuations)
        case high = 1      // Clean soon (observers)
        case normal = 2    // Regular cleanup (sessions)
        case low = 3       // Can defer (resources)
        
        public static func < (lhs: CleanupPriority, rhs: CleanupPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Properties
    private var cleanupRegistry: [UUID: CleanupItem] = [:]
    private var isCleaningUp = false
    private var continuationRegistry: [UUID: Any] = [:] // Stores CheckedContinuation references
    
    // MARK: - Registration
    
    /// Register an observer for cleanup
    public func registerObserver(
        _ observer: Any,
        description: String,
        cleanup: @escaping @Sendable () async -> Void
    ) -> UUID {
        let id = UUID()
        let item = CleanupItem(
            id: id,
            type: .observer,
            description: description,
            cleanup: cleanup,
            priority: .high
        )
        cleanupRegistry[id] = item
        logger.debug("Registered observer for cleanup: \(description)")
        return id
    }
    
    /// Register a continuation for tracking
    public func registerContinuation<T>(
        _ continuation: CheckedContinuation<T, Error>,
        description: String
    ) -> UUID {
        let id = UUID()
        continuationRegistry[id] = continuation
        
        let item = CleanupItem(
            id: id,
            type: .continuation,
            description: description,
            cleanup: { [weak self] in
                await self?.cancelContinuation(id: id)
            },
            priority: .critical
        )
        cleanupRegistry[id] = item
        logger.debug("Registered continuation: \(description)")
        return id
    }
    
    /// Register a session for cleanup
    public func registerSession(
        _ session: AVCaptureSession,
        description: String,
        cleanup: @escaping @Sendable () async -> Void
    ) -> UUID {
        let id = UUID()
        let item = CleanupItem(
            id: id,
            type: .session,
            description: description,
            cleanup: cleanup,
            priority: .normal
        )
        cleanupRegistry[id] = item
        logger.debug("Registered session for cleanup: \(description)")
        return id
    }
    
    /// Register a generic resource for cleanup
    public func registerResource(
        description: String,
        priority: CleanupPriority = .normal,
        cleanup: @escaping @Sendable () async -> Void
    ) -> UUID {
        let id = UUID()
        let item = CleanupItem(
            id: id,
            type: .resource,
            description: description,
            cleanup: cleanup,
            priority: priority
        )
        cleanupRegistry[id] = item
        logger.debug("Registered resource for cleanup: \(description)")
        return id
    }
    
    // MARK: - Unregistration
    
    /// Unregister a cleanup item (it was cleaned up manually)
    public func unregister(_ id: UUID) {
        if let item = cleanupRegistry.removeValue(forKey: id) {
            logger.debug("Unregistered \(String(describing: item.type)) cleanup: \(item.description)")
        }
        continuationRegistry.removeValue(forKey: id)
    }
    
    /// Unregister and complete a continuation successfully
    public func completeContinuation<T: Sendable>(_ id: UUID, with value: T) {
        if let continuation = continuationRegistry.removeValue(forKey: id) as? CheckedContinuation<T, Error> {
            continuation.resume(returning: value)
            cleanupRegistry.removeValue(forKey: id)
            logger.debug("Completed continuation: \(id)")
        }
    }
    
    /// Unregister and fail a continuation
    public func failContinuation(_ id: UUID, with error: Error) {
        if let continuation = continuationRegistry.removeValue(forKey: id) {
            if let typedContinuation = continuation as? CheckedContinuation<Any, Error> {
                typedContinuation.resume(throwing: error)
            }
            cleanupRegistry.removeValue(forKey: id)
            logger.debug("Failed continuation: \(id), error: \(error)")
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Perform cleanup for a specific type
    public func cleanup(type: CleanupType) async {
        logger.info("Starting cleanup for type: \(String(describing: type))")
        
        let itemsToClean = cleanupRegistry.values
            .filter { $0.type == type }
            .sorted { $0.priority < $1.priority }
        
        for item in itemsToClean {
            await performCleanup(item)
        }
    }
    
    /// Perform all cleanup operations
    public func cleanupAll() async {
        guard !isCleaningUp else {
            logger.warning("Cleanup already in progress")
            return
        }
        
        isCleaningUp = true
        defer { isCleaningUp = false }
        
        logger.info("Starting full cleanup with \(self.cleanupRegistry.count) items")
        
        // Sort by priority
        let sortedItems = cleanupRegistry.values.sorted { $0.priority < $1.priority }
        
        // Perform cleanup in priority order
        for item in sortedItems {
            await performCleanup(item)
        }
        
        // Clear registries
        cleanupRegistry.removeAll()
        continuationRegistry.removeAll()
        
        logger.info("Cleanup complete")
    }
    
    /// Perform emergency cleanup (fast path)
    public func emergencyCleanup() async {
        logger.warning("Performing emergency cleanup")
        
        // First, cancel all continuations to prevent leaks
        for (id, _) in continuationRegistry {
            await cancelContinuation(id: id)
        }
        
        // Then clean critical and high priority items only
        let criticalItems = cleanupRegistry.values
            .filter { $0.priority <= .high }
            .sorted { $0.priority < $1.priority }
        
        for item in criticalItems {
            await performCleanup(item)
        }
        
        // Clear registries
        cleanupRegistry.removeAll()
        continuationRegistry.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func performCleanup(_ item: CleanupItem) async {
        logger.debug("Cleaning up \(String(describing: item.type)): \(item.description)")
        
        await item.cleanup()
        cleanupRegistry.removeValue(forKey: item.id)
    }
    
    private func cancelContinuation(id: UUID) async {
        if let continuation = continuationRegistry.removeValue(forKey: id) {
            // Try to resume with cancellation error
            if let typedContinuation = continuation as? CheckedContinuation<Any, Error> {
                typedContinuation.resume(throwing: CameraError.backgrounded)
            }
            logger.debug("Cancelled continuation: \(id)")
        }
    }
    
    // MARK: - Diagnostics
    
    /// Get current cleanup status
    public func getStatus() -> CleanupStatus {
        let itemsByType = Dictionary(grouping: cleanupRegistry.values) { $0.type }
        
        return CleanupStatus(
            totalItems: cleanupRegistry.count,
            continuations: continuationRegistry.count,
            observers: itemsByType[.observer]?.count ?? 0,
            sessions: itemsByType[.session]?.count ?? 0,
            resources: itemsByType[.resource]?.count ?? 0,
            isCleaningUp: isCleaningUp
        )
    }
    
    /// Check for potential leaks
    public func checkForLeaks() -> [String] {
        var leaks: [String] = []
        
        // Check for orphaned continuations
        if continuationRegistry.count > 10 {
            leaks.append("Potential continuation leak: \(continuationRegistry.count) pending")
        }
        
        // Check for excessive observers
        let observerCount = cleanupRegistry.values.filter { $0.type == .observer }.count
        if observerCount > 20 {
            leaks.append("Potential observer leak: \(observerCount) registered")
        }
        
        // Check for old items
        // Note: In a real implementation, we'd track registration time
        
        return leaks
    }
}

// MARK: - Cleanup Status
public struct CleanupStatus: Sendable {
    let totalItems: Int
    let continuations: Int
    let observers: Int
    let sessions: Int
    let resources: Int
    let isCleaningUp: Bool
    
    var description: String {
        """
        Cleanup Status:
        - Total items: \(totalItems)
        - Continuations: \(continuations)
        - Observers: \(observers)
        - Sessions: \(sessions)
        - Resources: \(resources)
        - Cleaning up: \(isCleaningUp)
        """
    }
}

// MARK: - Cleanup Protocols
public protocol CleanupCoordinatorClient {
    var cleanupCoordinator: CleanupCoordinator { get }
    func registerForCleanup() async
    func performCleanup() async
}