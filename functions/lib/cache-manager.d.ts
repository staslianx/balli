interface CacheStats {
    systemPromptHits: number;
    userCacheHits: number;
    cacheMisses: number;
    totalRequests: number;
    cacheEfficiencyRate: number;
}
export declare class ContextCacheManager {
    private systemPromptCache;
    private userEmbeddingCaches;
    private cacheStats;
    private lastSystemPromptRefresh;
    constructor();
    initializeSystemPromptCache(): Promise<void>;
    getSystemPromptCache(): string | null;
    refreshSystemPromptCacheIfNeeded(): Promise<void>;
    createUserEmbeddingCache(userId: string, embeddings: any[]): Promise<void>;
    getUserEmbeddingCache(userId: string): string | null;
    cleanupExpiredCaches(): Promise<void>;
    private updateCacheEfficiency;
    getCacheStats(): CacheStats & {
        isActive: boolean;
        provider: string;
    };
    healthCheck(): Promise<{
        status: string;
        caches: any;
        stats: any;
    }>;
    warmupCaches(): Promise<void>;
}
export declare const cacheManager: ContextCacheManager;
export {};
//# sourceMappingURL=cache-manager.d.ts.map