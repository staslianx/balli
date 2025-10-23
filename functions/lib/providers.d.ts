interface ProviderConfig {
    plugin: any;
    name: 'googleai' | 'vertexai';
}
interface ModelReference {
    chat: any;
    summary: any;
    embedder: any;
    classifier: any;
    router: any;
    tier1: any;
    tier2: any;
    tier3: any;
}
export declare function getProviderConfig(): ProviderConfig['plugin'];
export declare function getProviderName(): 'googleai' | 'vertexai';
export declare function getModelReferences(): ModelReference;
export declare function getChatModel(): any;
export declare function getSummaryModel(): any;
export declare function getEmbedder(): any;
export declare function getClassifierModel(): any;
export declare function getRecipeModel(): any;
export declare function getFlashModel(): any;
export declare function getRouterModel(): any;
export declare function getTier1Model(): any;
export declare function getTier2Model(): any;
export declare function getTier3Model(): any;
export declare function supportsContextCaching(): boolean;
export declare function getProviderSpecificConfig(): {
    type: "vertexai";
    projectId: string;
    location: string;
    supportsCache: boolean;
    apiKey?: undefined;
} | {
    type: "googleai";
    apiKey: string | undefined;
    supportsCache: boolean;
    projectId?: undefined;
    location?: undefined;
};
export declare function getProviderError(error: any): string;
export declare function logProviderSwitch(): void;
export {};
//# sourceMappingURL=providers.d.ts.map