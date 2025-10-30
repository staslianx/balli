//
//  ResearchStageCoordinator.swift
//  balli
//
//  Handles multi-round research stage management and display
//  Split from MedicalResearchViewModel for better organization
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI
import OSLog

/// Coordinates multi-round research stages and progress display
@MainActor
final class ResearchStageCoordinator {
    // MARK: - Properties

    private let logger = AppLoggers.Research.search

    /// Stage display manager for user-friendly progress (answerId -> Manager)
    private var stageManagers: [String: ResearchStageDisplayManager] = [:]

    /// Current display stage for each answer (answerId -> current stage message)
    /// This is the SINGLE stage currently being displayed to the user
    /// NOT an array - only one stage is visible at a time with smooth transitions
    @Published var currentStages: [String: String] = [:]

    /// Flag to hold stream display until "writing report" stage completes (answerId -> Bool)
    @Published var shouldHoldStream: [String: Bool] = [:]

    /// Per-answer research plans (answerId -> ResearchPlan)
    @Published var currentPlans: [String: ResearchPlan] = [:]

    /// Completed research rounds (answerId -> [ResearchRound])
    @Published var completedRounds: [String: [ResearchRound]] = [:]

    /// Signals when a view is ready to display stages for an answer
    @Published var viewReadySignals: [String: Bool] = [:]

    // MARK: - Stage Management

    /// Signal that view is ready to display stages
    func signalViewReady(for answerId: String) {
        logger.info("📺 View ready signal received for answer: \(answerId)")
        viewReadySignals[answerId] = true
    }

    /// Process stage transition from SSE event
    func processStageTransition(event: ResearchSSEEvent, answerId: String) async {
        // Get or create stage manager for this answer
        let manager: ResearchStageDisplayManager
        let isNewManager: Bool
        if let existing = stageManagers[answerId] {
            manager = existing
            isNewManager = false
        } else {
            manager = ResearchStageDisplayManager()
            stageManagers[answerId] = manager
            isNewManager = true
        }

        // Map event to stage
        guard let newStage = manager.mapEventToStage(event) else {
            return // Event doesn't map to a stage change
        }

        logger.info("📨 Received stage event: \(newStage.userMessage)")

        // Don't hold stream for any stages - let content appear naturally
        shouldHoldStream[answerId] = false

        // Queue stage for display with enforced minimum duration
        // The manager will display stages sequentially with proper timing
        await manager.transitionToStage(newStage, coordinator: self, answerId: answerId)

        // Start observing AFTER first stage is queued to avoid race condition
        // This ensures the observer is active when the stage actually displays
        if isNewManager {
            logger.info("🔍 Starting stage observer for new answer: \(answerId)")
            startObservingStageChanges(for: answerId, manager: manager)
        }
    }

    /// Start observing stage changes from manager and updating UI
    private func startObservingStageChanges(for answerId: String, manager: ResearchStageDisplayManager) {
        // Create a repeating timer to poll manager's currentStage
        // This is necessary because ResearchStageDisplayManager doesn't use @Published
        Task { @MainActor in
            logger.info("👀 Observer started for answer: \(answerId)")
            var pollCount = 0

            while stageManagers[answerId] != nil {
                pollCount += 1

                // Check if manager has a stage to display
                if let currentStageMessage = manager.stageMessage {
                    // Update UI if stage changed
                    if currentStages[answerId] != currentStageMessage {
                        logger.info("📊 Stage displayed: \(currentStageMessage) (poll #\(pollCount))")
                        currentStages[answerId] = currentStageMessage
                    }
                } else if pollCount % 10 == 0 {
                    // Log every 1 second when no stage is available
                    logger.debug("⏳ Observer polling: no stage yet (poll #\(pollCount))")
                }

                // Poll every 100ms for smooth updates
                try? await Task.sleep(nanoseconds: 100_000_000)

                // Exit if task is cancelled
                if Task.isCancelled {
                    logger.info("🛑 Observer cancelled for answer: \(answerId)")
                    break
                }
            }

            logger.info("👋 Observer stopped for answer: \(answerId)")
        }
    }

    /// Handle first token arrival - triggers stage fade and stops queue processing
    func handleFirstTokenArrival(answerId: String) async {
        guard currentStages[answerId] != nil else { return }

        logger.info("🎬 First token arrived - clearing stages to show content")

        // Stop queue processing - no more stages needed
        if let manager = stageManagers[answerId] {
            manager.stopProcessing()
            logger.info("🛑 Stopped stage queue processing (content started)")
        }

        // Clear stages immediately to trigger fade out animation
        // SwiftUI's transition handles the visual fade
        currentStages[answerId] = nil

        logger.info("✅ Stages cleared, content is now visible")
    }

    // MARK: - Plan & Round Management

    /// Store research plan for answer
    func storePlan(_ plan: ResearchPlan, for answerId: String) {
        currentPlans[answerId] = plan
        logger.info("Stored research plan: \(plan.estimatedRounds) rounds")
    }

    /// Add completed round for answer
    func addCompletedRound(_ round: ResearchRound, for answerId: String) {
        var rounds = completedRounds[answerId] ?? []
        rounds.append(round)
        completedRounds[answerId] = rounds
    }

    /// Update round with reflection
    func updateRoundWithReflection(_ updatedRounds: [ResearchRound], for answerId: String) {
        completedRounds[answerId] = updatedRounds
    }

    /// Get completed rounds for answer
    func getCompletedRounds(for answerId: String) -> [ResearchRound] {
        return completedRounds[answerId] ?? []
    }

    // MARK: - Cleanup

    /// Cleanup state for completed search
    func cleanupSearchState(for answerId: String) {
        // Stop queue processing before removing manager
        if let manager = stageManagers[answerId] {
            manager.stopProcessing()
        }

        currentStages.removeValue(forKey: answerId)
        shouldHoldStream.removeValue(forKey: answerId)
        stageManagers.removeValue(forKey: answerId)
        currentPlans.removeValue(forKey: answerId)
        viewReadySignals.removeValue(forKey: answerId)
        // Note: Don't remove completedRounds - they're preserved for the final answer
    }

    /// Clear all state when starting a new conversation
    func clearAllState() {
        // Stop all queue processing tasks
        for (_, manager) in stageManagers {
            manager.stopProcessing()
        }

        currentStages.removeAll()
        shouldHoldStream.removeAll()
        stageManagers.removeAll()
        currentPlans.removeAll()
        completedRounds.removeAll()
        viewReadySignals.removeAll()
        logger.info("✅ Cleared all stage coordinator state")
    }
}
