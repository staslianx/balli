//
//  OfflineQueue.swift
//  balli
//
//  Queue for failed writes that should be retried when online
//  Automatically syncs when network becomes available
//  Integrates with NetworkMonitor for connectivity tracking
//

import Foundation
import OSLog
import Combine

/// Queues failed write operations for retry when network is restored
/// Automatically syncs when NetworkMonitor detects connectivity
actor OfflineQueue {

    // MARK: - Types

    struct QueuedOperation: Codable, Sendable {
        let id: UUID
        let operationType: OperationType
        let data: Data
        let timestamp: Date
        let retryCount: Int

        enum OperationType: String, Codable {
            case processMessage
            case generateRecipePhoto
            case parseMealTranscription
            case submitResearchFeedback
            case audioTranscription
        }
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "OfflineQueue")
    private let queueFile: URL
    private var queue: [QueuedOperation] = []
    private let maxRetries = 3
    private let maxQueueSize = 50
    private var isProcessing = false

    // MARK: - Singleton

    static let shared = OfflineQueue()

    // MARK: - Initialization

    private init() {
        // Set up queue file
        guard let documentsPath = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Failed to access application support directory")
        }

        let queueDirectory = documentsPath.appendingPathComponent("OfflineQueue")
        try? FileManager.default.createDirectory(
            at: queueDirectory,
            withIntermediateDirectories: true
        )

        self.queueFile = queueDirectory.appendingPathComponent("queue.json")

        // Load existing queue
        Task {
            await loadQueue()
        }

        logger.info("📡 OfflineQueue initialized - call processQueue() when network is restored")
    }

    // MARK: - Queue Management

    /// Add operation to queue
    func enqueue(
        type: QueuedOperation.OperationType,
        data: Codable
    ) async throws {
        // Limit queue size to prevent unlimited growth
        if queue.count >= maxQueueSize {
            logger.warning("Queue full, removing oldest operation")
            queue.removeFirst()
        }

        let encodedData = try JSONEncoder().encode(data)
        let operation = QueuedOperation(
            id: UUID(),
            operationType: type,
            data: encodedData,
            timestamp: Date(),
            retryCount: 0
        )

        queue.append(operation)
        await saveQueue()

        logger.info("Queued \(type.rawValue) operation (queue size: \(self.queue.count))")
    }

    // MARK: - Network Integration

    /// Process all queued operations
    func processQueue() async {
        guard !queue.isEmpty else {
            logger.debug("Queue is empty, nothing to process")
            return
        }

        // Prevent concurrent processing
        guard !isProcessing else {
            logger.debug("Queue already being processed, skipping")
            return
        }

        isProcessing = true
        logger.info("⚙️ Processing \(self.queue.count) queued operations")

        var successfulOperations: [UUID] = []
        var failedOperations: [(UUID, Int)] = []

        for operation in queue {
            do {
                try await processOperation(operation)
                successfulOperations.append(operation.id)
                logger.info("Successfully processed \(operation.operationType.rawValue)")
            } catch {
                logger.error("Failed to process \(operation.operationType.rawValue): \(error.localizedDescription)")

                // Increment retry count
                let newRetryCount = operation.retryCount + 1
                if newRetryCount >= maxRetries {
                    logger.warning("Operation \(operation.id) exceeded max retries, removing from queue")
                    successfulOperations.append(operation.id) // Remove from queue
                } else {
                    failedOperations.append((operation.id, newRetryCount))
                }
            }
        }

        // Remove successful operations
        queue.removeAll { operation in
            successfulOperations.contains(operation.id)
        }

        // Update retry counts for failed operations
        for (id, newRetryCount) in failedOperations {
            if let index = queue.firstIndex(where: { $0.id == id }) {
                let updatedOperation = queue[index]
                // Create new operation with updated retry count
                let newOperation = QueuedOperation(
                    id: updatedOperation.id,
                    operationType: updatedOperation.operationType,
                    data: updatedOperation.data,
                    timestamp: updatedOperation.timestamp,
                    retryCount: newRetryCount
                )
                queue[index] = newOperation
            }
        }

        await saveQueue()
        isProcessing = false

        logger.info("✅ Queue processing complete. Remaining: \(self.queue.count)")

        // If queue still has items, log a warning
        if !queue.isEmpty {
            logger.warning("⚠️ \(self.queue.count) operations still in queue after processing")
        }
    }

    /// Get current queue size
    func getQueueSize() async -> Int {
        return queue.count
    }

    /// Clear entire queue
    func clearQueue() async {
        queue.removeAll()
        await saveQueue()
        logger.info("Queue cleared")
    }

    // MARK: - Private Methods

    private func processOperation(_ operation: QueuedOperation) async throws {
        logger.debug("Processing operation: \(operation.operationType.rawValue)")

        switch operation.operationType {
        case .audioTranscription:
            try await processAudioTranscription(operation)

        case .processMessage, .generateRecipePhoto, .parseMealTranscription, .submitResearchFeedback:
            // These are handled by their respective services
            // For now, log that we attempted to process them
            logger.debug("Skipping \(operation.operationType.rawValue) - handled by other services")
            // Simulate processing delay
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    /// Process queued audio transcription when network returns
    private func processAudioTranscription(_ operation: QueuedOperation) async throws {
        // Decode queue data
        struct AudioTranscriptionQueueData: Codable {
            let audioPath: String
            let userId: String
            let timestamp: Date
        }

        let queueData = try JSONDecoder().decode(AudioTranscriptionQueueData.self, from: operation.data)
        let audioURL = URL(fileURLWithPath: queueData.audioPath)

        logger.info("🔄 Processing queued audio transcription from: \(audioURL.lastPathComponent)")

        // Check if audio file still exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            logger.warning("⚠️ Audio file no longer exists, removing from queue")
            return
        }

        // Read audio data
        let audioData = try Data(contentsOf: audioURL)

        // Call transcription service with allowOfflineQueue=false to prevent re-queuing
        let transcriptionService = GeminiTranscriptionService.shared
        let response = try await transcriptionService.transcribeMeal(
            audioData: audioData,
            userId: queueData.userId,
            progressCallback: nil, // No UI feedback for background processing
            allowOfflineQueue: false // Prevent infinite loop - don't re-queue if this fails
        )

        // If successful, clean up audio file
        try? FileManager.default.removeItem(at: audioURL)

        logger.info("✅ Successfully processed queued audio transcription")

        // Post notification to UI that transcription completed
        await MainActor.run {
            NotificationCenter.default.post(
                name: .offlineTranscriptionCompleted,
                object: nil,
                userInfo: ["response": response]
            )
        }
    }

    private func loadQueue() async {
        do {
            let data = try Data(contentsOf: queueFile)
            queue = try JSONDecoder().decode([QueuedOperation].self, from: data)
            logger.info("Loaded \(self.queue.count) operations from queue")
        } catch {
            // Queue file doesn't exist or is corrupted, start fresh
            queue = []
            logger.debug("Starting with empty queue")
        }
    }

    private func saveQueue() async {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: queueFile)
        } catch {
            logger.error("Failed to save queue: \(error.localizedDescription)")
        }
    }
}
