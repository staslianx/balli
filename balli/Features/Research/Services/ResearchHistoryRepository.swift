//
//  ResearchHistoryRepository.swift
//  balli
//
//  Swift 6 actor for thread-safe research answer persistence
//

import CoreData
import os.log

/// Thread-safe repository for persisting research answers to CoreData
actor ResearchHistoryRepository {
    private let logger = Logger(subsystem: "com.balli.diabetes", category: "research.persistence")
    private let persistence = Persistence.PersistenceController.shared

    // MARK: - CRUD Operations

    /// Save a single research answer (upsert: update if exists, insert if new)
    func save(_ answer: SearchAnswer) async throws {
        try await persistence.performBackgroundTask { context in
            // Try to fetch existing entity with this ID
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.predicate = NSPredicate(format: "id == %@", answer.id)
            request.fetchLimit = 1

            let existingEntities = try context.fetch(request)
            let entity: ResearchAnswer
            let isUpdate: Bool

            if let existing = existingEntities.first {
                // Update existing entity
                entity = existing
                isUpdate = true
            } else {
                // Create new entity
                entity = ResearchAnswer(context: context)
                isUpdate = false
            }

            // Set/update all properties
            entity.id = answer.id
            entity.query = answer.query
            entity.timestamp = answer.timestamp
            entity.content = answer.content
            entity.thinkingSummary = answer.thinkingSummary
            entity.tokenCount = Int32(answer.tokenCount ?? 0)
            entity.tierRawValue = answer.tier?.rawValue
            entity.processingTierRaw = answer.processingTierRaw

            // Encode JSON arrays
            entity.sourcesJSON = try self.encodeToJSON(answer.sources)
            entity.citationsJSON = try self.encodeToJSON(answer.citations)
            entity.relatedQuestionsJSON = try self.encodeToJSON(answer.completedRounds)
            entity.completedRoundsJSON = try self.encodeToJSON(answer.completedRounds)
            entity.highlightsJSON = try self.encodeToJSON(answer.highlights)

            try context.save()

            if isUpdate {
                self.logger.info("✅ Updated research answer: \(answer.query, privacy: .public)")
            } else {
                self.logger.info("✅ Created research answer: \(answer.query, privacy: .public)")
            }
        }
    }

    /// Save multiple research answers (upsert: update if exists, insert if new)
    func saveAll(_ answers: [SearchAnswer]) async throws {
        try await persistence.performBackgroundTask { context in
            var updateCount = 0
            var createCount = 0

            for answer in answers {
                // Try to fetch existing entity with this ID
                let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
                request.predicate = NSPredicate(format: "id == %@", answer.id)
                request.fetchLimit = 1

                let existingEntities = try context.fetch(request)
                let entity: ResearchAnswer

                if let existing = existingEntities.first {
                    // Update existing entity
                    entity = existing
                    updateCount += 1
                } else {
                    // Create new entity
                    entity = ResearchAnswer(context: context)
                    createCount += 1
                }

                // Set/update all properties
                entity.id = answer.id
                entity.query = answer.query
                entity.timestamp = answer.timestamp
                entity.content = answer.content
                entity.thinkingSummary = answer.thinkingSummary
                entity.tokenCount = Int32(answer.tokenCount ?? 0)
                entity.tierRawValue = answer.tier?.rawValue
                entity.processingTierRaw = answer.processingTierRaw

                // Encode JSON arrays
                entity.sourcesJSON = try self.encodeToJSON(answer.sources)
                entity.citationsJSON = try self.encodeToJSON(answer.citations)
                entity.relatedQuestionsJSON = try self.encodeToJSON(answer.completedRounds)
                entity.completedRoundsJSON = try self.encodeToJSON(answer.completedRounds)
                entity.highlightsJSON = try self.encodeToJSON(answer.highlights)
            }

            try context.save()
            self.logger.info("✅ Saved \(answers.count) research answers (created: \(createCount), updated: \(updateCount))")
        }
    }

    /// Load all persisted research answers
    func loadAll() async throws -> [SearchAnswer] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ResearchAnswer.timestamp, ascending: false)]

            let entities = try context.fetch(request)
            let answers = try entities.map { try self.convertToSearchAnswer($0) }

            self.logger.info("✅ Loaded \(answers.count) research answers")
            return answers
        }
    }

    /// Load recent research answers (limit: number to return)
    func loadRecent(limit: Int = 50) async throws -> [SearchAnswer] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ResearchAnswer.timestamp, ascending: false)]
            request.fetchLimit = limit

            let entities = try context.fetch(request)
            let answers = try entities.map { try self.convertToSearchAnswer($0) }

            self.logger.info("✅ Loaded \(answers.count) recent research answers")
            return answers
        }
    }

    /// Delete a specific research answer by ID
    func delete(id: String) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.predicate = NSPredicate(format: "id == %@", id)

            let results = try context.fetch(request)
            for entity in results {
                context.delete(entity)
            }

            try context.save()
            self.logger.info("✅ Deleted research answer: \(id, privacy: .public)")
        }
    }

    /// Delete all research answers (clear history)
    func deleteAll() async throws {
        try await persistence.performBackgroundTask { context in
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ResearchAnswer")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeCount

            _ = try context.execute(deleteRequest)
            try context.save()

            self.logger.info("✅ Cleared all research answers")
        }
    }

    // MARK: - JSON Encoding/Decoding

    nonisolated private func encodeToJSON<T: Encodable>(_ value: T) throws -> String? {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8)
    }

    nonisolated private func decodeFromJSON<T: Decodable>(_ json: String?) throws -> T? {
        guard let json = json else { return nil }
        guard let data = json.data(using: .utf8) else { return nil }

        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: - Entity Conversion

    nonisolated private func convertToSearchAnswer(_ entity: ResearchAnswer) throws -> SearchAnswer {
        let sources: [ResearchSource] = try decodeFromJSON(entity.sourcesJSON) ?? []
        let citations: [InlineCitation] = try decodeFromJSON(entity.citationsJSON) ?? []
        let completedRounds: [ResearchRound] = try decodeFromJSON(entity.completedRoundsJSON) ?? []
        let highlights: [TextHighlight] = try decodeFromJSON(entity.highlightsJSON) ?? []

        let tier: ResponseTier?
        if let tierRaw = entity.tierRawValue {
            tier = ResponseTier(rawValue: tierRaw)
        } else {
            tier = nil
        }

        return SearchAnswer(
            id: entity.id ?? UUID().uuidString,
            query: entity.query ?? "",
            content: entity.content ?? "",
            sources: sources,
            citations: citations,
            timestamp: entity.timestamp ?? Date(),
            tokenCount: entity.tokenCount > 0 ? Int(entity.tokenCount) : nil,
            tier: tier,
            thinkingSummary: entity.thinkingSummary,
            processingTierRaw: entity.processingTierRaw,
            completedRounds: completedRounds,
            highlights: highlights
        )
    }

    // MARK: - Highlight Operations

    /// Save highlights for a specific answer ID
    func saveHighlights(_ highlights: [TextHighlight], for answerId: String) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.predicate = NSPredicate(format: "id == %@", answerId)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                self.logger.error("❌ ResearchAnswer not found for highlight save: \(answerId)")
                throw RepositoryError.answerNotFound
            }

            // Delete existing highlight entities for this answer
            if let existingHighlights = entity.highlights as? Set<TextHighlightEntity> {
                for highlight in existingHighlights {
                    context.delete(highlight)
                }
            }

            // Create new TextHighlightEntity objects from TextHighlight structs
            for highlight in highlights {
                let highlightEntity = TextHighlightEntity(context: context)
                highlightEntity.id = highlight.id
                highlightEntity.createdAt = highlight.createdAt
                highlightEntity.colorRawValue = highlight.color.rawValue
                highlightEntity.startOffset = Int32(highlight.startOffset)
                highlightEntity.length = Int32(highlight.length)
                highlightEntity.text = highlight.text
                highlightEntity.researchAnswer = entity
            }

            // Also keep JSON backup for migration fallback (can remove in future release)
            entity.highlightsJSON = try self.encodeToJSON(highlights)

            try context.save()

            self.logger.info("✅ Saved \(highlights.count) highlights for answer: \(answerId)")
        }
    }

    /// Load highlights for a specific answer ID
    func loadHighlights(for answerId: String) async throws -> [TextHighlight] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.predicate = NSPredicate(format: "id == %@", answerId)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                self.logger.error("❌ ResearchAnswer not found for highlight load: \(answerId)")
                return []
            }

            // Try loading from Core Data relationship first
            if let highlightEntities = entity.highlights as? Set<TextHighlightEntity>, !highlightEntities.isEmpty {
                let highlights = highlightEntities.map { highlightEntity in
                    TextHighlight(
                        id: highlightEntity.id ?? UUID(),
                        color: TextHighlight.HighlightColor(rawValue: highlightEntity.colorRawValue ?? "") ?? .green,
                        startOffset: Int(highlightEntity.startOffset),
                        length: Int(highlightEntity.length),
                        text: highlightEntity.text ?? "",
                        createdAt: highlightEntity.createdAt ?? Date()
                    )
                }.sorted { $0.createdAt < $1.createdAt } // Sort by creation date

                self.logger.info("✅ Loaded \(highlights.count) highlights from Core Data for answer: \(answerId)")
                return highlights
            }

            // Fallback to JSON for migration (old data)
            if let jsonHighlights: [TextHighlight] = try self.decodeFromJSON(entity.highlightsJSON), !jsonHighlights.isEmpty {
                self.logger.info("⚠️ Loaded \(jsonHighlights.count) highlights from JSON fallback (migrating...)")

                // Auto-migrate: save to Core Data for next time
                Task {
                    try? await self.saveHighlights(jsonHighlights, for: answerId)
                }

                return jsonHighlights
            }

            self.logger.debug("ℹ️ No highlights found for answer: \(answerId)")
            return []
        }
    }

    /// Load all highlights across all research answers
    /// Returns tuples of (question, answerId, highlight) sorted by highlight creation date (newest first)
    func loadAllHighlights() async throws -> [(question: String, answerId: String, highlight: TextHighlight)] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            // No need to sort answers by timestamp - we'll sort by highlight creation date instead

            let entities = try context.fetch(request)
            var results: [(String, String, TextHighlight)] = []

            // Collect all highlights from all answers
            for entity in entities {
                guard let highlightsJSON = entity.highlightsJSON,
                      let highlights: [TextHighlight] = try? self.decodeFromJSON(highlightsJSON),
                      !highlights.isEmpty else { continue }

                let question = entity.query ?? ""
                let answerId = entity.id ?? ""

                // Add each highlight to results
                for highlight in highlights {
                    results.append((question, answerId, highlight))
                }
            }

            // Sort ALL highlights by creation date (newest highlight first, regardless of which research it's from)
            results.sort { $0.2.createdAt > $1.2.createdAt }

            self.logger.info("✅ Loaded \(results.count) total highlights across all answers, sorted by creation date")
            return results
        }
    }

    /// Delete a specific highlight from an answer
    func deleteHighlight(_ highlightId: UUID, from answerId: String) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<ResearchAnswer>(entityName: "ResearchAnswer")
            request.predicate = NSPredicate(format: "id == %@", answerId)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                self.logger.error("❌ ResearchAnswer not found for highlight deletion: \(answerId)")
                throw RepositoryError.answerNotFound
            }

            // CRITICAL: Delete from CoreData relationship (primary storage)
            if let highlightEntities = entity.highlights as? Set<TextHighlightEntity> {
                // Find and delete the specific highlight entity
                if let entityToDelete = highlightEntities.first(where: { $0.id == highlightId }) {
                    context.delete(entityToDelete)
                    self.logger.debug("🗑️ Deleted TextHighlightEntity from CoreData relationship")
                }
            }

            // Also update JSON fallback for consistency
            var highlights: [TextHighlight] = try self.decodeFromJSON(entity.highlightsJSON) ?? []
            highlights.removeAll { $0.id == highlightId }
            entity.highlightsJSON = try self.encodeToJSON(highlights)

            // Save changes to both relationship and JSON
            try context.save()

            self.logger.info("✅ Deleted highlight \(highlightId) from answer: \(answerId). Remaining: \(highlights.count)")
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case answerNotFound

    var errorDescription: String? {
        switch self {
        case .answerNotFound:
            return "Research answer not found in database"
        }
    }
}
