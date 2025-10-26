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

    /// Current display stage for answer (answerId -> Stage message)
    @Published var currentStages: [String: String] = [:]

    /// Flag to hold stream display until "writing report" stage completes (answerId -> Bool)
    @Published var shouldHoldStream: [String: Bool] = [:]

    /// Per-answer research plans (answerId -> ResearchPlan)
    @Published var currentPlans: [String: ResearchPlan] = [:]

    /// Completed research rounds (answerId -> [ResearchRound])
    @Published var completedRounds: [String: [ResearchRound]] = [:]

    // MARK: - Stage Management

    /// Process stage transition from SSE event
    func processStageTransition(event: ResearchSSEEvent, answerId: String) async {
        // Get or create stage manager for this answer
        let manager = stageManagers[answerId] ?? ResearchStageDisplayManager()
        stageManagers[answerId] = manager

        // Map event to stage
        guard let newStage = manager.mapEventToStage(event) else {
            return // Event doesn't map to a stage change
        }

        // 🎯 SYNTHESIS STAGE TIMING FIX: Split time between gathering and writing stages
        // User wants to see BOTH stages before stream appears
        // Solution: When gatheringInfo arrives, show it for HALF the normal time,
        // then auto-switch to writingReport for the other half

        if newStage == .gatheringInfo {
            // Hold stream during BOTH synthesis stages
            shouldHoldStream[answerId] = true
            logger.info("🚫 Stream display HELD - starting synthesis sequence")

            // Show "Bilgileri bir araya getiriyorum" for 1.0 seconds
            currentStages[answerId] = "Bilgileri bir araya getiriyorum"
            logger.info("📊 Stage 1/2: Bilgileri bir araya getiriyorum (1.0s)")
            try? await Task.sleep(for: .seconds(1.0))

            // Auto-switch to "Kapsamlı bir rapor yazıyorum" and keep it visible
            // The stage will stay visible until the first token arrives and triggers fade
            currentStages[answerId] = "Kapsamlı bir rapor yazıyorum"
            logger.info("📊 Stage 2/2: Kapsamlı bir rapor yazıyorum (staying until first token arrives)")

            // DON'T fade out here - the onToken callback will fade it out when the first token arrives!
            // This ensures the progress card stays visible until content is actually ready
            logger.info("⏳ Waiting for first token to trigger fade & release...")

            // Don't process stage transition normally - we handled it above
            return
        }

        // For writingReport event (if it arrives), just ignore it since we already handled it
        if newStage == .writingReport {
            logger.info("⏩ Skipping writingReport event - already handled in gatheringInfo")
            return
        }

        // Normal stage transition for all other stages
        await manager.transitionToStage(newStage)
        currentStages[answerId] = manager.stageMessage
    }

    /// Handle first token arrival - triggers stage fade and releases hold
    func handleFirstTokenArrival(answerId: String) async {
        guard shouldHoldStream[answerId] == true else { return }

        logger.info("🎬 First token arrived - fading out progress card")

        // Clear stage to trigger fade out animation
        currentStages[answerId] = nil

        // Small delay for fade animation to complete (0.3s)
        try? await Task.sleep(for: .seconds(0.3))

        logger.info("🚀 Releasing hold - showing content!")
        shouldHoldStream[answerId] = false
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
        currentStages.removeValue(forKey: answerId)
        shouldHoldStream.removeValue(forKey: answerId)
        stageManagers.removeValue(forKey: answerId)
        currentPlans.removeValue(forKey: answerId)
        // Note: Don't remove completedRounds - they're preserved for the final answer
    }
}
