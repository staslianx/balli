//
//  MemoryRepository.swift
//  balli
//
//  Thread-safe repository for AI memory persistence using Core Data
//  Handles MemoryEntry and UserMemoryPreference entities
//  Swift 6 strict concurrency compliant
//

import CoreData
import OSLog

/// Actor-based repository for thread-safe memory persistence
actor MemoryRepository {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.balli", category: "MemoryRepository")
    private let persistence: Persistence.PersistenceController

    init(persistence: Persistence.PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Memory Entry Operations

    /// Save a single memory entry to Core Data
    func saveMemoryEntry(_ entry: MemoryEntry) async throws {
        try await persistence.performBackgroundTask { context in
            let entity = MemoryEntryEntity(context: context)
            entity.id = entry.id
            entity.timestamp = entry.timestamp
            entity.expiresAt = entry.expiresAt
            entity.typeRawValue = entry.type.rawValue
            entity.tierRawValue = entry.tier?.rawValue
            entity.source = entry.source
            entity.content = entry.content
            entity.confidence = entry.confidence

            // Encode metadata as JSON
            if let metadata = entry.metadata {
                entity.metadataJSON = try? self.encodeToJSON(metadata)
            }

            // Encode embedding as JSON
            if let embedding = entry.embedding {
                entity.embeddingJSON = try? self.encodeToJSON(embedding)
            }

            try context.save()
            self.logger.debug("💾 Saved memory entry: \(entry.id)")
        }
    }

    /// Save multiple memory entries in a batch
    func saveMemoryEntries(_ entries: [MemoryEntry]) async throws {
        try await persistence.performBackgroundTask { context in
            for entry in entries {
                let entity = MemoryEntryEntity(context: context)
                entity.id = entry.id
                entity.timestamp = entry.timestamp
                entity.expiresAt = entry.expiresAt
                entity.typeRawValue = entry.type.rawValue
                entity.tierRawValue = entry.tier?.rawValue
                entity.source = entry.source
                entity.content = entry.content
                entity.confidence = entry.confidence

                if let metadata = entry.metadata {
                    entity.metadataJSON = try? self.encodeToJSON(metadata)
                }

                if let embedding = entry.embedding {
                    entity.embeddingJSON = try? self.encodeToJSON(embedding)
                }
            }

            try context.save()
            self.logger.info("💾 Batch saved \(entries.count) memory entries")
        }
    }

    /// Load all memory entries, optionally filtered by type and/or tier
    func loadMemoryEntries(type: MemoryType? = nil, tier: MemoryTier? = nil) async throws -> [MemoryEntry] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<MemoryEntryEntity>(entityName: "MemoryEntryEntity")

            var predicates: [NSPredicate] = []
            if let type {
                predicates.append(NSPredicate(format: "typeRawValue == %@", type.rawValue))
            }
            if let tier {
                predicates.append(NSPredicate(format: "tierRawValue == %@", tier.rawValue))
            }

            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

            let entities = try context.fetch(request)
            return entities.compactMap { try? self.convertToMemoryEntry($0) }
        }
    }

    /// Delete expired memory entries
    func deleteExpiredMemories() async throws -> Int {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<MemoryEntryEntity>(entityName: "MemoryEntryEntity")
            request.predicate = NSPredicate(format: "expiresAt != nil AND expiresAt < %@", Date() as NSDate)

            let expired = try context.fetch(request)
            for entry in expired {
                context.delete(entry)
            }

            try context.save()

            self.logger.info("🧹 Deleted \(expired.count) expired memory entries")
            return expired.count
        }
    }

    /// Delete all memory entries (for testing or reset)
    func deleteAllMemoryEntries() async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<MemoryEntryEntity>(entityName: "MemoryEntryEntity")
            let entities = try context.fetch(request)

            for entity in entities {
                context.delete(entity)
            }

            try context.save()
            self.logger.warning("🗑️ Deleted all memory entries")
        }
    }

    // MARK: - Preference Operations

    /// Save a user preference
    func savePreference(key: String, value: PreferenceValue) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<UserMemoryPreferenceEntity>(entityName: "UserMemoryPreferenceEntity")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.fetchLimit = 1

            let entity: UserMemoryPreferenceEntity
            if let existing = try context.fetch(request).first {
                entity = existing
            } else {
                entity = UserMemoryPreferenceEntity(context: context)
                entity.id = UUID()
                entity.key = key
            }

            // Set value based on type
            switch value {
            case .string(let val):
                entity.valueType = "string"
                entity.stringValue = val
            case .int(let val):
                entity.valueType = "int"
                entity.intValue = Int64(val)
            case .double(let val):
                entity.valueType = "double"
                entity.doubleValue = val
            case .bool(let val):
                entity.valueType = "bool"
                entity.boolValue = val
            case .date(let val):
                entity.valueType = "date"
                entity.dateValue = val
            case .array(let val):
                entity.valueType = "array"
                entity.arrayJSON = try? self.encodeToJSON(val)
            }

            entity.lastUpdated = Date()

            try context.save()
            self.logger.debug("💾 Saved preference: \(key)")
        }
    }

    /// Load all user preferences
    func loadPreferences() async throws -> [String: PreferenceValue] {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<UserMemoryPreferenceEntity>(entityName: "UserMemoryPreferenceEntity")
            let entities = try context.fetch(request)

            var preferences: [String: PreferenceValue] = [:]
            for entity in entities {
                guard let key = entity.key, let valueType = entity.valueType else { continue }

                let value: PreferenceValue
                switch valueType {
                case "string":
                    value = .string(entity.stringValue ?? "")
                case "int":
                    value = .int(Int(entity.intValue))
                case "double":
                    value = .double(entity.doubleValue)
                case "bool":
                    value = .bool(entity.boolValue)
                case "date":
                    value = .date(entity.dateValue ?? Date())
                case "array":
                    if let json = entity.arrayJSON,
                       let array: [String] = try? self.decodeFromJSON(json) {
                        value = .array(array)
                    } else {
                        value = .array([])
                    }
                default:
                    continue
                }

                preferences[key] = value
            }

            self.logger.debug("📖 Loaded \(preferences.count) preferences")
            return preferences
        }
    }

    /// Delete a preference by key
    func deletePreference(key: String) async throws {
        try await persistence.performBackgroundTask { context in
            let request = NSFetchRequest<UserMemoryPreferenceEntity>(entityName: "UserMemoryPreferenceEntity")
            request.predicate = NSPredicate(format: "key == %@", key)

            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }

            try context.save()
            self.logger.debug("🗑️ Deleted preference: \(key)")
        }
    }

    // MARK: - Helper Methods

    /// Convert MemoryEntryEntity to MemoryEntry struct
    nonisolated private func convertToMemoryEntry(_ entity: MemoryEntryEntity) throws -> MemoryEntry {
        guard let id = entity.id,
              let typeRaw = entity.typeRawValue,
              let type = MemoryType(rawValue: typeRaw),
              let content = entity.content else {
            throw MemoryRepositoryError.invalidData
        }

        let metadata: [String: String]? = entity.metadataJSON.flatMap { try? decodeFromJSON($0) }
        let embedding: [Double]? = entity.embeddingJSON.flatMap { try? decodeFromJSON($0) }
        let tier: MemoryTier? = entity.tierRawValue.flatMap { MemoryTier(rawValue: $0) }

        return MemoryEntry(
            id: id,
            type: type,
            content: content,
            metadata: metadata,
            timestamp: entity.timestamp ?? Date(),
            expiresAt: entity.expiresAt,
            confidence: entity.confidence,
            source: entity.source ?? "user_stated",
            tier: tier,
            embedding: embedding
        )
    }

    /// Encode value to JSON string
    nonisolated private func encodeToJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw MemoryRepositoryError.encodingFailed
        }
        return json
    }

    /// Decode value from JSON string
    nonisolated private func decodeFromJSON<T: Decodable>(_ json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw MemoryRepositoryError.decodingFailed
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Memory Repository Error

enum MemoryRepositoryError: LocalizedError {
    case invalidData
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data in Core Data entity"
        case .encodingFailed:
            return "Failed to encode data to JSON"
        case .decodingFailed:
            return "Failed to decode JSON data"
        }
    }
}
