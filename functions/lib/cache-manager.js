"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.cacheManager = exports.ContextCacheManager = void 0;
//
// Context Cache Manager for Vertex AI
// Handles system prompt caching and user-specific embedding caches
//
// import { vertexAI } from '@genkit-ai/vertexai'; // Commented out until context caching API is available
const providers_1 = require("./providers");
const fs = __importStar(require("fs/promises"));
const path = __importStar(require("path"));
class ContextCacheManager {
    systemPromptCache = null;
    userEmbeddingCaches = new Map();
    cacheStats = {
        systemPromptHits: 0,
        userCacheHits: 0,
        cacheMisses: 0,
        totalRequests: 0,
        cacheEfficiencyRate: 0
    };
    lastSystemPromptRefresh = null;
    constructor() {
        console.log(`🗄️ [CACHE] Initializing ContextCacheManager`);
    }
    // Initialize system prompt cache from the dotprompt file
    async initializeSystemPromptCache() {
        if (!(0, providers_1.supportsContextCaching)()) {
            console.log(`⚠️ [CACHE] Context caching not supported with ${(0, providers_1.getProviderName)()}, skipping cache initialization`);
            return;
        }
        try {
            console.log(`🔄 [CACHE] Loading diabetes assistant prompt for caching...`);
            // Read the prompt file
            const promptPath = path.join(__dirname, '../prompts/memory_aware_diabetes_assistant.prompt');
            const promptContent = await fs.readFile(promptPath, 'utf8');
            // Extract just the text content (remove YAML frontmatter if present)
            let systemPromptText = promptContent;
            if (promptContent.startsWith('---')) {
                const parts = promptContent.split('---');
                if (parts.length >= 3) {
                    systemPromptText = parts.slice(2).join('---').trim();
                }
            }
            console.log(`📏 [CACHE] System prompt: ${systemPromptText.length} characters`);
            // Create the cache with 24-hour TTL
            // const cacheRequest = {
            //   contents: [{
            //     role: 'system' as const,
            //     parts: [{ text: systemPromptText }]
            //   }],
            //   ttl: '86400s', // 24 hours
            //   displayName: 'diabetes-assistant-system-prompt'
            // };
            console.log(`🔄 [CACHE] Creating system prompt cache...`);
            // Note: Context caching API may not be available in all Genkit versions
            // This is a placeholder for when the API becomes available
            try {
                // this.systemPromptCache = await vertexAI.createContextCache(cacheRequest);
                console.log(`⚠️ [CACHE] Context caching API not yet available in current Genkit version`);
                this.systemPromptCache = null;
            }
            catch (apiError) {
                console.log(`⚠️ [CACHE] Context caching not supported: ${apiError}`);
                this.systemPromptCache = null;
            }
            this.lastSystemPromptRefresh = new Date();
            // Note: When context caching API becomes available, this will show cache details
            console.log(`✅ [CACHE] System prompt caching initialized (ready for API)`);
            console.log(`📊 [CACHE] Prompt length: ${systemPromptText.length} characters`);
        }
        catch (error) {
            console.error(`❌ [CACHE] Failed to initialize system prompt cache:`, error);
            // Don't throw - fall back to non-cached operation
            this.systemPromptCache = null;
        }
    }
    // Get system prompt cache reference
    getSystemPromptCache() {
        if (!(0, providers_1.supportsContextCaching)()) {
            return null;
        }
        if (this.systemPromptCache) {
            this.cacheStats.systemPromptHits++;
            this.updateCacheEfficiency();
            return this.systemPromptCache.name;
        }
        this.cacheStats.cacheMisses++;
        this.updateCacheEfficiency();
        return null;
    }
    // Check if system prompt cache needs refresh
    async refreshSystemPromptCacheIfNeeded() {
        if (!(0, providers_1.supportsContextCaching)() || !this.systemPromptCache) {
            return;
        }
        try {
            const now = new Date();
            const expireTime = new Date(this.systemPromptCache.expireTime);
            // Refresh if cache expires in less than 1 hour
            const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);
            if (this.systemPromptCache?.expireTime && expireTime < oneHourFromNow) {
                console.log(`🔄 [CACHE] System prompt cache expiring soon, refreshing...`);
                await this.initializeSystemPromptCache();
            }
        }
        catch (error) {
            console.error(`❌ [CACHE] Error checking cache expiration:`, error);
        }
    }
    // Create cache for user's frequent embeddings (future enhancement)
    async createUserEmbeddingCache(userId, embeddings) {
        if (!(0, providers_1.supportsContextCaching)() || embeddings.length === 0) {
            return;
        }
        try {
            console.log(`🔄 [CACHE] Creating embedding cache for user: ${userId}`);
            // Create cache for user's recent embeddings (1-hour TTL)
            // const cacheRequest = {
            //   contents: embeddings.map(emb => ({
            //     role: 'user' as const,
            //     parts: [{ text: emb.text }]
            //   })),
            //   ttl: '3600s', // 1 hour for user-specific data
            //   displayName: `user-embeddings-${userId.substring(0, 8)}`
            // };
            // Note: Context caching API may not be available in all Genkit versions
            try {
                // const userCache = await vertexAI.createContextCache(cacheRequest);
                console.log(`⚠️ [CACHE] User embedding caching not yet available in current Genkit version`);
                return;
            }
            catch (apiError) {
                console.log(`⚠️ [CACHE] User embedding caching not supported: ${apiError}`);
                return;
            }
            // console.log(`✅ [CACHE] User embedding cache created: ${userCache.name}`);
            console.log(`✅ [CACHE] User embedding cache would be created when API is available`);
        }
        catch (error) {
            console.error(`❌ [CACHE] Failed to create user embedding cache for ${userId}:`, error);
        }
    }
    // Get user embedding cache if available
    getUserEmbeddingCache(userId) {
        if (!(0, providers_1.supportsContextCaching)()) {
            return null;
        }
        const userCache = this.userEmbeddingCaches.get(userId);
        if (userCache) {
            this.cacheStats.userCacheHits++;
            this.updateCacheEfficiency();
            return userCache.name;
        }
        return null;
    }
    // Clean up expired caches
    async cleanupExpiredCaches() {
        if (!(0, providers_1.supportsContextCaching)()) {
            return;
        }
        try {
            const now = new Date();
            // Check system prompt cache
            if (this.systemPromptCache && this.systemPromptCache.expireTime) {
                const expireTime = new Date(this.systemPromptCache.expireTime);
                if (now >= expireTime) {
                    console.log(`🧹 [CACHE] System prompt cache expired, clearing reference`);
                    this.systemPromptCache = null;
                }
            }
            // Check user embedding caches
            for (const [userId, cache] of this.userEmbeddingCaches.entries()) {
                if (cache && cache.expireTime) {
                    const expireTime = new Date(cache.expireTime);
                    if (now >= expireTime) {
                        console.log(`🧹 [CACHE] User cache expired for ${userId}, clearing reference`);
                        this.userEmbeddingCaches.delete(userId);
                    }
                }
            }
        }
        catch (error) {
            console.error(`❌ [CACHE] Error during cache cleanup:`, error);
        }
    }
    // Update cache efficiency metrics
    updateCacheEfficiency() {
        this.cacheStats.totalRequests++;
        const totalHits = this.cacheStats.systemPromptHits + this.cacheStats.userCacheHits;
        this.cacheStats.cacheEfficiencyRate = (totalHits / this.cacheStats.totalRequests) * 100;
    }
    // Get cache statistics for monitoring
    getCacheStats() {
        return {
            ...this.cacheStats,
            isActive: (0, providers_1.supportsContextCaching)(),
            provider: (0, providers_1.getProviderName)()
        };
    }
    // Health check for cache manager
    async healthCheck() {
        const stats = this.getCacheStats();
        return {
            status: (0, providers_1.supportsContextCaching)() ? 'active' : 'disabled',
            caches: {
                systemPrompt: {
                    active: !!this.systemPromptCache,
                    name: this.systemPromptCache?.name || null,
                    lastRefresh: this.lastSystemPromptRefresh?.toISOString() || null,
                    expireTime: this.systemPromptCache?.expireTime || null
                },
                userEmbeddings: {
                    count: this.userEmbeddingCaches.size,
                    users: Array.from(this.userEmbeddingCaches.keys())
                }
            },
            stats: stats
        };
    }
    // Warm up caches (call on cold start)
    async warmupCaches() {
        console.log(`🔥 [CACHE] Starting cache warmup...`);
        await this.initializeSystemPromptCache();
        await this.cleanupExpiredCaches();
        console.log(`✅ [CACHE] Cache warmup completed`);
    }
}
exports.ContextCacheManager = ContextCacheManager;
// Global cache manager instance
exports.cacheManager = new ContextCacheManager();
//# sourceMappingURL=cache-manager.js.map