//
//  SourceDeduplicator.swift
//  balli
//
//  Deduplicates sources across research rounds while preserving citation mapping
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Deduplicates sources across research rounds while preserving citation mapping
final class SourceDeduplicator: Sendable {
    private static let logger = AppLoggers.Research.parsing

    /// Deduplicate sources from multiple rounds
    /// - Parameter sourcesByRound: Array of source arrays (one per round)
    /// - Returns: Tuple of (deduplicated sources, citation mapping)
    static func deduplicate(
        _ sourcesByRound: [[SourceResponse]]
    ) -> (sources: [SourceWithMetadata], citationMap: [Int: Int]) {
        var deduped: [SourceWithMetadata] = []
        var seenKeys: Set<String> = []
        var citationMap: [Int: Int] = [:] // originalIndex -> dedupedIndex

        var originalIndex = 1
        var dedupedIndex = 1

        for (roundNumber, sources) in sourcesByRound.enumerated() {
            for source in sources {
                let key = makeDedupeKey(source)

                if seenKeys.contains(key) {
                    // Duplicate found
                    logger.debug("Duplicate source removed: \(source.title)")

                    // Find deduped index for this key
                    if let existing = deduped.first(where: { makeDedupeKey($0.source) == key }) {
                        if let existingDedupIndex = existing.deduplicatedIndex {
                            citationMap[originalIndex] = existingDedupIndex
                        }
                    }
                } else {
                    // New source
                    seenKeys.insert(key)

                    let metadata = SourceWithMetadata(
                        source: source,
                        foundInRound: roundNumber + 1,
                        originalIndex: originalIndex,
                        deduplicatedIndex: dedupedIndex
                    )
                    deduped.append(metadata)
                    citationMap[originalIndex] = dedupedIndex

                    dedupedIndex += 1
                }

                originalIndex += 1
            }
        }

        logger.info("Deduplication: \(originalIndex - 1) → \(deduped.count) sources")
        return (deduped, citationMap)
    }

    /// Generate deduplication key for a source
    private static func makeDedupeKey(_ source: SourceResponse) -> String {
        // Try to extract PMID from URL for PubMed articles
        if source.type == "pubmed" {
            if let pmid = extractPMID(from: source.url) {
                return "pmid:\(pmid)"
            }
        }

        // Use normalized URL for others
        let normalizedURL = source.url
            .lowercased()
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Remove trailing slash
        var normalized = normalizedURL
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        return "url:\(normalized)"
    }

    /// Extract PMID from PubMed URL
    private static func extractPMID(from url: String) -> String? {
        // Match patterns like: /pubmed/12345678 or /12345678/
        let pattern = "/(\\d{7,8})/?$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsString = url as NSString
        if let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: nsString.length)) {
            let pmidRange = match.range(at: 1)
            return nsString.substring(with: pmidRange)
        }

        return nil
    }
}
