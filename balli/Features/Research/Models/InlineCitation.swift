//
//  InlineCitation.swift
//  balli
//
//  Inline citation tracking for answer text references
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Represents an inline citation marker in answer text (e.g., "[1]")
struct InlineCitation: Identifiable, Codable, Sendable {
    let id: UUID
    let sourceIndex: Int  // Maps to sources array (1-indexed)
    let range: Range<String.Index>?  // Position in text (optional)

    init(id: UUID = UUID(), sourceIndex: Int, range: Range<String.Index>? = nil) {
        self.id = id
        self.sourceIndex = sourceIndex
        self.range = range
    }

    // Custom Codable implementation since Range<String.Index> isn't Codable
    enum CodingKeys: String, CodingKey {
        case id
        case sourceIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.sourceIndex = try container.decode(Int.self, forKey: .sourceIndex)
        self.range = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceIndex, forKey: .sourceIndex)
    }
}
