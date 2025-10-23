/**
 * Comprehensive response cleaning utility
 * Handles all variations of LLM JSON output formatting
 */
export declare function cleanLLMResponse(responseText: string): string;
/**
 * Parse LLM JSON response with aggressive fallback cleaning
 */
export declare function parseLLMResponse<T extends {
    answer: string;
}>(responseText: string, fallbackConfidence?: number): T;
//# sourceMappingURL=response-cleaner.d.ts.map