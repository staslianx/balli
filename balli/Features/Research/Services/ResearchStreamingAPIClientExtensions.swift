//
//  ResearchStreamingAPIClientExtensions.swift
//  balli
//
//  Offline support extensions for ResearchStreamingAPIClient
//  Adds simple caching for research queries
//

import Foundation

extension ResearchStreamingAPIClient {

    /// Search with offline cache fallback
    func searchWithCache(query: String, userId: String) async throws -> ResearchSearchResponse {
        // Check if online
        let monitor = NetworkMonitor.shared
        let isOnline = monitor.isConnected

        if !isOnline {
            // Try cached result
            let cache = OfflineCache.shared
            if let cached = await cache.getCachedResearchResult(query: query) {
                logger.info("Returning cached research result for: \(query)")

                // Convert cached data to response format
                let sources = cached.sources.compactMap { sourceDict -> DiabetesSource? in
                    guard let title = sourceDict["title"],
                          let type = sourceDict["type"] else {
                        return nil
                    }
                    return DiabetesSource(
                        title: title,
                        url: sourceDict["url"],
                        type: type,
                        authors: sourceDict["authors"],
                        journal: sourceDict["journal"],
                        year: sourceDict["year"],
                        pmid: sourceDict["pmid"]
                    )
                }

                return ResearchSearchResponse(
                    answer: cached.answer,
                    tier: 1,
                    processingTier: "cached",
                    thinkingSummary: "Cached response",
                    routing: RoutingInfo(
                        selectedTier: 1,
                        reasoning: "Offline - cached result",
                        confidence: 1.0
                    ),
                    sources: sources,
                    metadata: MetadataInfo(
                        processingTime: "0ms",
                        modelUsed: "cached",
                        costTier: "free",
                        tokenUsage: nil
                    ),
                    researchSummary: nil,
                    rateLimitInfo: nil
                )
            }

            // No cache available
            throw ResearchSearchError.networkError
        }

        // Online - fetch from server
        do {
            let response = try await search(query: query, userId: userId)

            // Cache the result for offline use
            let cache = OfflineCache.shared
            let sourceDicts = response.sources.map { source -> [String: String] in
                var dict: [String: String] = [
                    "title": source.title,
                    "type": source.type
                ]
                if let url = source.url {
                    dict["url"] = url
                }
                if let authors = source.authors {
                    dict["authors"] = authors
                }
                if let journal = source.journal {
                    dict["journal"] = journal
                }
                if let year = source.year {
                    dict["year"] = year
                }
                if let pmid = source.pmid {
                    dict["pmid"] = pmid
                }
                return dict
            }

            await cache.cacheResearchResult(
                query: query,
                answer: response.answer,
                sources: sourceDicts
            )

            return response
        } catch {
            // If network error, try returning cached data
            if case ResearchSearchError.networkError = error {
                let cache = OfflineCache.shared
                if let cached = await cache.getCachedResearchResult(query: query) {
                    logger.info("Network error - returning cached research result")

                    let sources = cached.sources.compactMap { sourceDict -> DiabetesSource? in
                        guard let title = sourceDict["title"],
                              let type = sourceDict["type"] else {
                            return nil
                        }
                        return DiabetesSource(
                            title: title,
                            url: sourceDict["url"],
                            type: type,
                            authors: sourceDict["authors"],
                            journal: sourceDict["journal"],
                            year: sourceDict["year"],
                            pmid: sourceDict["pmid"]
                        )
                    }

                    return ResearchSearchResponse(
                        answer: cached.answer,
                        tier: 1,
                        processingTier: "cached",
                        thinkingSummary: "Cached response",
                        routing: RoutingInfo(
                            selectedTier: 1,
                            reasoning: "Network error - cached result",
                            confidence: 1.0
                        ),
                        sources: sources,
                        metadata: MetadataInfo(
                            processingTime: "0ms",
                            modelUsed: "cached",
                            costTier: "free",
                            tokenUsage: nil
                        ),
                        researchSummary: nil,
                        rateLimitInfo: nil
                    )
                }
            }

            throw error
        }
    }
}
