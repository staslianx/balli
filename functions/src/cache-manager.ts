//
// Context Cache Manager for Vertex AI
// Handles system prompt caching and user-specific embedding caches
//
// import { vertexAI } from '@genkit-ai/vertexai'; // Commented out until context caching API is available
import { supportsContextCaching, getProviderName } from './providers';
import * as fs from 'fs/promises';
import * as path from 'path';

// Cache reference interface
interface CacheReference {
  name: string;
  createTime: string;
  expireTime: string;
  displayName?: string;
}

// Placeholder cache reference for when API is not available
interface PlaceholderCache {
  name: string;
  createTime: string;
  expireTime: string;
  displayName?: string;
  isPlaceholder: true;
}

// Cache statistics for monitoring
interface CacheStats {
  systemPromptHits: number;
  userCacheHits: number;
  cacheMisses: number;
  totalRequests: number;
  cacheEfficiencyRate: number;
}

export class ContextCacheManager {
  private systemPromptCache: CacheReference | PlaceholderCache | null = null;
  private userEmbeddingCaches: Map<string, CacheReference> = new Map();
  private cacheStats: CacheStats = {
    systemPromptHits: 0,
    userCacheHits: 0,
    cacheMisses: 0,
    totalRequests: 0,
    cacheEfficiencyRate: 0
  };
  private lastSystemPromptRefresh: Date | null = null;

  constructor() {
    console.log(`🗄️ [CACHE] Initializing ContextCacheManager`);
  }

  // Initialize system prompt cache from the dotprompt file
  async initializeSystemPromptCache(): Promise<void> {
    if (!supportsContextCaching()) {
      console.log(`⚠️ [CACHE] Context caching not supported with ${getProviderName()}, skipping cache initialization`);
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
      } catch (apiError) {
        console.log(`⚠️ [CACHE] Context caching not supported: ${apiError}`);
        this.systemPromptCache = null;
      }
      this.lastSystemPromptRefresh = new Date();

      // Note: When context caching API becomes available, this will show cache details
      console.log(`✅ [CACHE] System prompt caching initialized (ready for API)`);
      console.log(`📊 [CACHE] Prompt length: ${systemPromptText.length} characters`);
    } catch (error) {
      console.error(`❌ [CACHE] Failed to initialize system prompt cache:`, error);
      // Don't throw - fall back to non-cached operation
      this.systemPromptCache = null;
    }
  }

  // Get system prompt cache reference
  getSystemPromptCache(): string | null {
    if (!supportsContextCaching()) {
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
  async refreshSystemPromptCacheIfNeeded(): Promise<void> {
    if (!supportsContextCaching() || !this.systemPromptCache) {
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
    } catch (error) {
      console.error(`❌ [CACHE] Error checking cache expiration:`, error);
    }
  }

  // Create cache for user's frequent embeddings (future enhancement)
  async createUserEmbeddingCache(userId: string, embeddings: any[]): Promise<void> {
    if (!supportsContextCaching() || embeddings.length === 0) {
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
      } catch (apiError) {
        console.log(`⚠️ [CACHE] User embedding caching not supported: ${apiError}`);
        return;
      }

      // console.log(`✅ [CACHE] User embedding cache created: ${userCache.name}`);
      console.log(`✅ [CACHE] User embedding cache would be created when API is available`);
    } catch (error) {
      console.error(`❌ [CACHE] Failed to create user embedding cache for ${userId}:`, error);
    }
  }

  // Get user embedding cache if available
  getUserEmbeddingCache(userId: string): string | null {
    if (!supportsContextCaching()) {
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
  async cleanupExpiredCaches(): Promise<void> {
    if (!supportsContextCaching()) {
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
    } catch (error) {
      console.error(`❌ [CACHE] Error during cache cleanup:`, error);
    }
  }

  // Update cache efficiency metrics
  private updateCacheEfficiency(): void {
    this.cacheStats.totalRequests++;
    const totalHits = this.cacheStats.systemPromptHits + this.cacheStats.userCacheHits;
    this.cacheStats.cacheEfficiencyRate = (totalHits / this.cacheStats.totalRequests) * 100;
  }

  // Get cache statistics for monitoring
  getCacheStats(): CacheStats & { isActive: boolean; provider: string } {
    return {
      ...this.cacheStats,
      isActive: supportsContextCaching(),
      provider: getProviderName()
    };
  }

  // Health check for cache manager
  async healthCheck(): Promise<{status: string; caches: any; stats: any}> {
    const stats = this.getCacheStats();

    return {
      status: supportsContextCaching() ? 'active' : 'disabled',
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
  async warmupCaches(): Promise<void> {
    console.log(`🔥 [CACHE] Starting cache warmup...`);

    await this.initializeSystemPromptCache();
    await this.cleanupExpiredCaches();

    console.log(`✅ [CACHE] Cache warmup completed`);
  }
}

// Global cache manager instance
export const cacheManager = new ContextCacheManager();