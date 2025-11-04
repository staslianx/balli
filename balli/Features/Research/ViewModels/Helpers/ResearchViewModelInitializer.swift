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
    private let streamProcessor: ResearchStreamProcessor
    private let stageCoordinator: ResearchStageCoordinator
    private let searchCoordinator: ResearchSearchCoordinator
    private let persistenceManager: ResearchPersistenceManager
    private let currentUserId: String
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "ResearchViewModelInitializer")

    // MARK: - Initialization

    init(
        tokenBuffer: TokenBuffer,
        streamProcessor: ResearchStreamProcessor,
        stageCoordinator: ResearchStageCoordinator,
        searchCoordinator: ResearchSearchCoordinator,
        persistenceManager: ResearchPersistenceManager,
        currentUserId: String
    ) {
        self.tokenBuffer = tokenBuffer
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
        // Initialize session manager with ModelContainer, userId, and metadata generator
        let container: ModelContainer
        do {
            container = try ResearchSessionModelContainer.shared.makeContext().container
        } catch {
            logger.error("Failed to create persistent session container: \(error.localizedDescription)")

            // Fallback to in-memory container
            let schema = Schema([ResearchSession.self, SessionMessage.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                container = try ModelContainer(for: schema, configurations: [config])
                logger.info("Successfully created in-memory fallback container")
            } catch {
                logger.critical("CRITICAL: Failed to create in-memory fallback container: \(error.localizedDescription)")
                // This should never happen, but if it does, fail gracefully
                fatalError("Unable to initialize session storage. Please restart the app. Error: \(error)")
            }
        }

        let metadataGenerator = SessionMetadataGenerator()
        let sessionManager = ResearchSessionManager(
            modelContainer: container,
            userId: currentUserId,
            metadataGenerator: metadataGenerator
        )

        // Initialize extracted components
        let eventHandler = ResearchEventHandler(
            tokenBuffer: tokenBuffer,
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
