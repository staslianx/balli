//
//  ResearchViewModelInitializer.swift
//  balli
//
//  Extracts initialization logic for MedicalResearchViewModel
//  Handles ModelContainer setup, notification observers, and Combine publishers
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import OSLog

/// Result type containing core initialized components (before observers)
struct ResearchViewModelCoreComponents {
    let sessionManager: ResearchSessionManager
    let eventHandler: ResearchEventHandler
    let sessionCoordinator: ResearchSessionCoordinator
}

/// Service responsible for initializing all components of MedicalResearchViewModel
/// Separates complex initialization logic from the view model
@MainActor
final class ResearchViewModelInitializer {
    // MARK: - Dependencies

    private let tokenBuffer: TokenBuffer
    private let tokenSmoother: TokenSmoother
    private let streamProcessor: ResearchStreamProcessor
    private let stageCoordinator: ResearchStageCoordinator
    private let searchCoordinator: ResearchSearchCoordinator
    private let persistenceManager: ResearchPersistenceManager
    private let currentUserId: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "ResearchViewModelInitializer")

    // MARK: - Initialization

    init(
        tokenBuffer: TokenBuffer,
        tokenSmoother: TokenSmoother,
        streamProcessor: ResearchStreamProcessor,
        stageCoordinator: ResearchStageCoordinator,
        searchCoordinator: ResearchSearchCoordinator,
        persistenceManager: ResearchPersistenceManager,
        currentUserId: String
    ) {
        self.tokenBuffer = tokenBuffer
        self.tokenSmoother = tokenSmoother
        self.streamProcessor = streamProcessor
        self.stageCoordinator = stageCoordinator
        self.searchCoordinator = searchCoordinator
        self.persistenceManager = persistenceManager
        self.currentUserId = currentUserId
    }

    // MARK: - Component Initialization

    /// Initialize core components (without observers that need `self`)
    /// Call this first, then setup observers after assigning to view model properties
    func initializeCoreComponents() -> ResearchViewModelCoreComponents {
        // Initialize session manager using storage configuration
        let storageState = ResearchStorageConfiguration.configureStorage()

        let sessionManager: ResearchSessionManager
        let metadataGenerator = SessionMetadataGenerator()

        switch storageState {
        case .persistent(let container), .inMemory(let container):
            // Storage available - create session manager
            sessionManager = ResearchSessionManager(
                modelContainer: container,
                userId: currentUserId,
                metadataGenerator: metadataGenerator
            )
            logger.info("✅ Session manager initialized with storage")

        case .unavailable(let error):
            // Storage unavailable - create session manager with in-memory-only container
            // This is a degraded mode where session history won't persist across app restarts
            logger.warning("⚠️ Creating session manager in degraded mode: \(error.localizedDescription)")

            // Create a minimal in-memory container for the session
            let schema = Schema([ResearchSession.self, SessionMessage.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            // This should always succeed since it's in-memory only
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                sessionManager = ResearchSessionManager(
                    modelContainer: container,
                    userId: currentUserId,
                    metadataGenerator: metadataGenerator
                )
                logger.info("✅ Session manager initialized in degraded mode (no persistence)")
            } else {
                // CRITICAL FIX: If even in-memory container fails, try one more time without config
                logger.critical("⚠️ CRITICAL: In-memory container with config failed - trying default configuration")

                do {
                    let defaultContainer = try ModelContainer(for: schema)
                    sessionManager = ResearchSessionManager(
                        modelContainer: defaultContainer,
                        userId: currentUserId,
                        metadataGenerator: metadataGenerator
                    )
                    logger.info("✅ Created session manager with default container as last resort")
                } catch {
                    // If this fails, SwiftData is completely broken
                    // Create a minimal container with no schema as absolute last fallback
                    logger.fault("💥 FAULT: Cannot create ModelContainer at all: \(error.localizedDescription)")
                    logger.fault("Research functionality will be severely degraded - sessions won't be saved")

                    // Use an empty schema as absolute minimum
                    let emptySchema = Schema([])
                    do {
                        let emergencyContainer = try ModelContainer(for: emptySchema)
                        sessionManager = ResearchSessionManager(
                            modelContainer: emergencyContainer,
                            userId: currentUserId,
                            metadataGenerator: metadataGenerator
                        )
                        logger.warning("Created emergency session manager with empty schema")
                    } catch {
                        // This should truly be impossible - if even empty schema fails, SwiftData is broken
                        fatalError("SwiftData completely broken - cannot create any ModelContainer: \(error)")
                    }
                }
            }
        }

        // Initialize extracted components
        let eventHandler = ResearchEventHandler(
            tokenBuffer: tokenBuffer,
            tokenSmoother: tokenSmoother,
            streamProcessor: streamProcessor,
            stageCoordinator: stageCoordinator,
            searchCoordinator: searchCoordinator,
            persistenceManager: persistenceManager,
            sessionManager: sessionManager
        )

        let sessionCoordinator = ResearchSessionCoordinator(
            persistenceManager: persistenceManager,
            sessionManager: sessionManager
        )

        return ResearchViewModelCoreComponents(
            sessionManager: sessionManager,
            eventHandler: eventHandler,
            sessionCoordinator: sessionCoordinator
        )
    }

    // MARK: - Observer Setup

    /// Setup notification observers for session management
    /// Call this after core components are assigned to view model properties
    func setupNotificationObservers(
        saveCurrentSession: @escaping @MainActor () async -> Void,
        syncAnswersToPersistence: @escaping @MainActor () async -> Void
    ) -> [NSObjectProtocol] {
        var observers: [NSObjectProtocol] = []

        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveActiveResearchSession"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await saveCurrentSession()
            }
        }
        observers.append(observer1)

        let observer2 = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await syncAnswersToPersistence()
            }
        }
        observers.append(observer2)

        return observers
    }

    /// Setup Combine observer for stage coordinator updates
    /// Call this after core components are assigned to view model properties
    func setupStageCoordinatorObserver(
        stageCoordinator: ResearchStageCoordinator,
        updateCurrentStages: @escaping @MainActor ([String: String]) -> Void
    ) -> AnyCancellable {
        stageCoordinator.$currentStages
            .receive(on: RunLoop.main)
            .sink { stages in
                updateCurrentStages(stages)
            }
    }
}
