export interface NutritionExtractionInput {
    imageBase64: string;
    language?: 'tr' | 'en';
    maxWidth?: number;
    userId?: string;
}
export interface NutritionExtractionOutput {
    servingSize: {
        value: number;
        unit: string;
        perContainer?: number;
    };
    nutrients: {
        calories: {
            value: number;
            unit: string;
        };
        totalCarbohydrates: {
            value: number;
            unit: string;
        };
        dietaryFiber?: {
            value: number;
            unit: string;
        };
        sugars?: {
            value: number;
            unit: string;
        };
        protein: {
            value: number;
            unit: string;
        };
        totalFat: {
            value: number;
            unit: string;
        };
        saturatedFat?: {
            value: number;
            unit: string;
        };
        transFat?: {
            value: number;
            unit: string;
        };
        cholesterol?: {
            value: number;
            unit: string;
        };
        sodium?: {
            value: number;
            unit: string;
        };
        addedSugars?: {
            value: number;
            unit: string;
        };
    };
    metadata: {
        confidence: number;
        processingTime: string;
        modelVersion: string;
        warnings: string[];
        detectedLanguage?: string;
    };
    rawText?: string;
    usage?: {
        inputTokens: number;
        outputTokens: number;
    };
}
/**
 * Extracts nutrition information from an image using direct Gemini API with responseSchema
 * This ensures 99%+ JSON parsing reliability by enforcing the structure at the API level
 */
export declare function extractNutritionWithResponseSchema(input: NutritionExtractionInput): Promise<NutritionExtractionOutput>;
/**
 * Health check for the direct API extractor
 */
export declare function healthCheckDirectApi(): Promise<{
    status: string;
    model: string;
    apiKey: boolean;
}>;
//# sourceMappingURL=nutrition-extractor.d.ts.map