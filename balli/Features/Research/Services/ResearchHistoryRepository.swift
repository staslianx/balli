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
            completedRounds: completedRounds
        )
    }
}
