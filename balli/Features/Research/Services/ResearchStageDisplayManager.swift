//
//  ResearchStageDisplayManager.swift
//  balli
//
//  Manages user-friendly research stage display with minimum duration enforcement
//  Ensures each stage is visible long enough for users to read
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// User-facing research stages with simplified, conversational messages
enum ResearchDisplayStage: Sendable {
    case planning              // Stage 1: "Araştırma planını yapıyorum"
    case startingResearch      // Stage 2: "Araştırmaya başlıyorum"
    case collectingSources     // Stage 3: "Kaynakları topluyorum"
    case evaluatingSources     // Stage 4: "Kaynakları değerlendiriyorum"
    case searchingAdditional   // Stage 5: "Ek kaynaklar arıyorum"
    case examiningAdditional   // Stage 6: "Ek kaynakları inceliyorum"
    case selectingBest         // Stage 7: "En ilgili kaynakları seçiyorum"
    case gatheringInfo         // Stage 8: "Bilgileri bir araya getiriyorum"
    case writingReport         // Stage 9: "Kapsamlı bir rapor yazıyorum"

    /// User-friendly message in Turkish
    var userMessage: String {
        switch self {
        case .planning: return "Araştırma planını yapıyorum"
        case .startingResearch: return "Araştırmaya başlıyorum"
        case .collectingSources: return "Kaynakları topluyorum"
        case .evaluatingSources: return "Kaynakları değerlendiriyorum"
        case .searchingAdditional: return "Ek kaynaklar arıyorum"
        case .examiningAdditional: return "Ek kaynakları inceliyorum"
        case .selectingBest: return "En ilgili kaynakları seçiyorum"
        case .gatheringInfo: return "Bilgileri bir araya getiriyorum"
        case .writingReport: return "Kapsamlı bir rapor yazıyorum"
        }
    }

    /// Minimum display duration in seconds to ensure readability
    var minimumDisplayDuration: TimeInterval {
        switch self {
        case .planning: return 2.0
        case .startingResearch: return 1.5      // ⚠️ Needs artificial delay (natural: ~0s)
        case .collectingSources: return 2.0
        case .evaluatingSources: return 2.0
        case .searchingAdditional: return 1.5   // ⚠️ Needs artificial delay (natural: ~0s)
        case .examiningAdditional: return 2.0
        case .selectingBest: return 2.5
        case .gatheringInfo: return 2.0         // ⚠️ Might need delay (natural: 1-2s)
        case .writingReport: return 2.0
        }
    }
}

/// Manages research stage display with minimum duration enforcement using a queue
@MainActor
class ResearchStageDisplayManager {

    // MARK: - Logger

    private let logger = AppLoggers.Research.streaming

    // MARK: - State

    /// Currently displayed stage (UI reads this)
    private(set) var currentStage: ResearchDisplayStage?

    /// When current stage started displaying
    private var currentStageStartTime: Date?

    /// Queue of pending stages waiting to be displayed
    private var pendingStages: [ResearchDisplayStage] = []

    /// Processing task for stage queue
    private var queueProcessingTask: Task<Void, Never>?

    /// Flag to indicate if queue is being processed
    private var isProcessingQueue = false

    // MARK: - Public API

    /// Get current display stage
    var stage: ResearchDisplayStage? {
        currentStage
    }

    /// Get current stage message
    var stageMessage: String? {
        currentStage?.userMessage
    }

    /// Queue a new stage for display with minimum duration enforcement
    /// - Parameter newStage: The new stage to queue
    /// - Parameter coordinator: The stage coordinator to check view readiness
    /// - Parameter answerId: The answer ID for view readiness check
    /// - Note: Stages are displayed sequentially with enforced minimum durations
    func transitionToStage(_ newStage: ResearchDisplayStage, coordinator: ResearchStageCoordinator, answerId: String) async {
        logger.info("🔄 Queuing stage: \(newStage.userMessage)")

        // Add stage to queue
        pendingStages.append(newStage)

        // Start processing queue if not already running
        if !isProcessingQueue {
            startQueueProcessing(answerId: answerId, coordinator: coordinator)
        }
    }

    /// Start processing the stage queue
    private func startQueueProcessing(answerId: String, coordinator: ResearchStageCoordinator) {
        // Cancel any existing processing task
        queueProcessingTask?.cancel()

        // Create new processing task
        queueProcessingTask = Task { @MainActor in
            isProcessingQueue = true
            defer { isProcessingQueue = false }

            logger.info("▶️ Starting stage queue processing")

            // 🔧 CRITICAL FIX: Wait for view to signal it's ready
            logger.info("⏸️ Waiting for view to be ready...")

            while coordinator.viewReadySignals[answerId] != true {
                try? await Task.sleep(nanoseconds: 50_000_000)  // Check every 50ms
            }

            logger.info("✅ View is ready, starting stage display")

            while !pendingStages.isEmpty {
                // Check if task was cancelled
                if Task.isCancelled {
                    logger.info("⏹️ Stage queue processing cancelled")
                    break
                }

                // Ensure current stage displayed for minimum duration
                if let currentStage = currentStage,
                   let startTime = currentStageStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let minDuration = currentStage.minimumDisplayDuration
                    let remaining = max(0, minDuration - elapsed)

                    if remaining > 0 {
                        logger.info("⏳ Holding '\(currentStage.userMessage)' for \(String(format: "%.1f", remaining))s more")
                        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    }
                }

                // Get next stage from queue
                let nextStage = pendingStages.removeFirst()

                // Display next stage
                logger.info("✅ Now displaying: \(nextStage.userMessage)")
                self.currentStage = nextStage
                self.currentStageStartTime = Date()
            }

            logger.info("⏸️ Stage queue empty, pausing processing")
        }
    }

    /// Stop queue processing and clear all pending stages
    func stopProcessing() {
        logger.info("🛑 Stopping stage queue processing")
        queueProcessingTask?.cancel()
        queueProcessingTask = nil
        pendingStages.removeAll()
        isProcessingQueue = false
    }

    /// Map backend SSE event to user-facing stage
    /// - Parameter event: The SSE event received from backend
    /// - Returns: The corresponding display stage, or nil if event doesn't map to a stage
    func mapEventToStage(_ event: ResearchSSEEvent) -> ResearchDisplayStage? {
        switch event {
        case .planningStarted:
            return .planning

        case .roundStarted(let round, _, _, _):
            // Round 1 = starting, Round 2+ = searching additional
            return round == 1 ? .startingResearch : .searchingAdditional

        case .apiStarted:
            // First API in round 1 = collecting, others = examining additional
            if currentStage == .startingResearch {
                return .collectingSources
            } else if currentStage == .searchingAdditional {
                return .examiningAdditional
            }
            return nil

        case .reflectionStarted:
            return .evaluatingSources

        case .sourceSelectionStarted:
            return .selectingBest

        case .synthesisPreparation:
            return .gatheringInfo

        case .synthesisStarted:
            return .writingReport

        default:
            // Don't change stage for other events
            return nil
        }
    }

    /// Reset manager state (for new search)
    func reset() {
        logger.info("Resetting stage display manager")
        stopProcessing()
        currentStage = nil
        currentStageStartTime = nil
    }
}
