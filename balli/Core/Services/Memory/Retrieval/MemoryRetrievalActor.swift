//
//  MemoryRetrievalActor.swift
//  balli
//
//  Actor responsible for retrieving memory entries and building context
//  Handles thread-safe read access to memory caches
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

// MARK: - Memory Retrieval Actor

actor MemoryRetrievalActor {
    // MARK: - Properties

    private let logger = AppLoggers.Data.sync

    // Configuration
    private let shortTermLimit = 5   // Keep 5 turns (10 messages) in full text

    // MARK: - Initialization

    init() {
        logger.info("MemoryRetrievalActor initialized (ChatAssistant removed - local only)")
    }

    // MARK: - Context Retrieval

    func getRelevantContext(for prompt: String, cache: UserMemoryCache?, userId: String) async -> String {
        // Try to get enhanced context from Firebase first
        let enhancedContext = await getEnhancedMemoryContext(for: prompt, userId: userId)
        if !enhancedContext.isEmpty {
            return enhancedContext
        }

        // Fallback to local memory context
        guard let cache = cache else {
            logger.error("No cache available for context retrieval")
            return ""
        }

        var context = ""
        var tokenEstimate = 0

        // 1. Add immediate memory (last 5 turns - full text)
        if !cache.immediateMemory.isEmpty {
            context += "<recent_messages>\n"
            for memory in cache.immediateMemory.suffix(shortTermLimit * 2) { // 5 turns = 10 messages
                if memory.type == .conversation {
                    let role = memory.metadata?["role"] ?? "unknown"
                    context += "[\(role)]: \(memory.content)\n"
                    tokenEstimate += memory.content.count / 4
                }
            }
            context += "</recent_messages>\n\n"
        }

        // 2. Add persistent user facts
        if !cache.userFacts.isEmpty {
            context += "<user_profile>\n"
            for fact in cache.userFacts {
                context += "- \(fact)\n"
                tokenEstimate += fact.count / 4
            }
            context += "</user_profile>\n\n"
        }

        // 3. Add relevant patterns based on prompt keywords
        let relevantPatterns = findRelevantPatterns(for: prompt, cache: cache)
        if !relevantPatterns.isEmpty {
            context += "<relevant_patterns>\n"
            for pattern in relevantPatterns.prefix(3) {
                context += "- \(pattern.content)\n"
                tokenEstimate += pattern.content.count / 4
            }
            context += "</relevant_patterns>\n\n"
        }

        // 4. Check for recipe requests and add recipe history
        if await isRecipeRequest(prompt) {
            context += getRecipeContext(cache: cache)
        }

        logger.info("Built local context with estimated \(tokenEstimate) tokens")
        return context
    }

    // MARK: - Semantic Search (DISABLED - ChatAssistant removed)

    /// ChatAssistant removed - semantic search no longer available
    func getSemanticallySimilarMessages(for prompt: String, userId: String) async -> [(content: String, role: String, timestamp: Date)] {
        logger.debug("Semantic search disabled - ChatAssistant removed")
        return []
    }

    // MARK: - Pattern Matching

    private func findRelevantPatterns(for prompt: String, cache: UserMemoryCache) -> [MemoryEntry] {
        let lowercasePrompt = prompt.lowercased()

        return cache.recentPatterns.filter { pattern in
            // Check if pattern content is relevant to the prompt
            let content = pattern.content.lowercased()

            // Simple keyword matching - could be enhanced with semantic similarity
            let keywords = ["kahvaltı", "öğle", "akşam", "yemek", "şeker", "glukoz", "insülin"]

            for keyword in keywords {
                if lowercasePrompt.contains(keyword) && content.contains(keyword) {
                    return true
                }
            }

            return false
        }
    }

    // MARK: - Recipe Handling

    /// Check if prompt is asking for a recipe
    private func isRecipeRequest(_ prompt: String) async -> Bool {
        let recipeKeywords = ["tarif", "yemek", "recipe", "nasıl yapılır", "malzemeler", "pişir"]
        let lowercasePrompt = prompt.lowercased()

        return recipeKeywords.contains { keyword in
            lowercasePrompt.contains(keyword)
        }
    }

    /// Get recipe context to avoid duplicates
    private func getRecipeContext(cache: UserMemoryCache) -> String {
        guard !cache.storedRecipes.isEmpty else { return "" }

        var context = "<previous_recipes>\n"
        context += "User has already received these recipes (avoid duplicates):\n"

        for (title, _) in cache.storedRecipes.prefix(5) {
            context += "- \(title)\n"
        }

        context += "</previous_recipes>\n\n"
        return context
    }

    // MARK: - Enhanced Memory Context (Firebase Integration)

    /// Get enhanced memory context using Firebase search endpoint
    private func getEnhancedMemoryContext(for query: String, userId: String) async -> String {
        do {
            guard let url = URL(string: "\(NetworkConfiguration.shared.baseURL)/searchSimilarMessages") else {
                logger.error("Invalid URL for searchSimilarMessages endpoint")
                return ""
            }

            let requestData = [
                "queryText": query,
                "userId": userId,
                "limit": 5
            ] as [String : Any]

            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = jsonResponse["data"] as? [String: Any] {

                var context = ""

                // Add memory results
                if let memoryResults = responseData["memoryResults"] as? [[String: Any]] {
                    if !memoryResults.isEmpty {
                        context += "Relevant memories:\n"
                        for result in memoryResults {
                            if let text = result["text"] as? String,
                               let source = result["source"] as? String {
                                context += "[\(source)]: \(text)\n"
                            }
                        }
                        context += "\n"
                    }
                }

                // Add similar messages
                if let messages = responseData["messages"] as? [[String: Any]] {
                    if !messages.isEmpty {
                        context += "Similar past conversations:\n"
                        for message in messages {
                            if let text = message["text"] as? String,
                               let isUser = message["isUser"] as? Bool {
                                let role = isUser ? "User" : "Assistant"
                                context += "[\(role)]: \(text)\n"
                            }
                        }
                    }
                }

                logger.info("Retrieved enhanced memory context (\(context.count) characters)")
                return context
            }

        } catch {
            logger.error("Failed to get enhanced memory context: \(error.localizedDescription)")
        }

        return ""
    }
}
