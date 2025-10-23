/**
 * Retry Handler Utility
 * Provides exponential backoff retry logic for Cloud Functions
 * Handles transient failures gracefully while avoiding unnecessary retries
 *
 * Based on audit recommendations:
 * - Max 3 retries with exponential backoff
 * - Smart detection of retryable vs permanent errors
 * - Rate limit handling with longer backoff
 * - Jitter to avoid thundering herd
 */
/**
 * Error categories for retry decisions
 */
export declare enum ErrorCategory {
    RATE_LIMIT = "rate_limit",// 429, rate limit errors - retry with longer backoff
    TRANSIENT = "transient",// 500, 503, network errors - retry normally
    PERMANENT = "permanent",// 400, 404, validation errors - don't retry
    TIMEOUT = "timeout",// ETIMEDOUT, ECONNRESET - retry normally
    UNKNOWN = "unknown"
}
/**
 * Retry options configuration
 */
export interface RetryOptions {
    maxRetries?: number;
    baseDelay?: number;
    maxDelay?: number;
    onRetry?: (error: any, attempt: number, delay: number) => void;
}
/**
 * Execute operation with retry logic and exponential backoff
 *
 * @param operation - Async function to execute
 * @param context - Operation context for logging (e.g., 'Gemini API call', 'PubMed search')
 * @param options - Retry configuration options
 * @returns Result of the operation
 * @throws Last error if all retries exhausted
 *
 * @example
 * // Retry Gemini API call
 * const result = await retryWithBackoff(
 *   () => ai.generate({ model, prompt }),
 *   'Gemini API generate',
 *   { maxRetries: 3, baseDelay: 1000 }
 * );
 *
 * @example
 * // Retry PubMed search with custom callback
 * const articles = await retryWithBackoff(
 *   () => searchPubMed(query, 5),
 *   'PubMed search',
 *   {
 *     maxRetries: 2,
 *     baseDelay: 500,
 *     onRetry: (error, attempt, delay) => {
 *       console.log(`Retrying PubMed after ${delay}ms (attempt ${attempt})`);
 *     }
 *   }
 * );
 */
export declare function retryWithBackoff<T>(operation: () => Promise<T>, context: string, options?: RetryOptions): Promise<T>;
/**
 * Helper: Retry with shorter settings for fast operations (API searches)
 * Max 2 retries, 500ms base delay, 5s max delay
 */
export declare function retryFast<T>(operation: () => Promise<T>, context: string): Promise<T>;
/**
 * Helper: Retry with standard settings for normal operations
 * Max 3 retries, 1s base delay, 10s max delay
 */
export declare function retryStandard<T>(operation: () => Promise<T>, context: string): Promise<T>;
/**
 * Helper: Check if error is retryable (useful for custom retry logic)
 */
export declare function isRetryableError(error: any): boolean;
/**
 * Helper: Get error category (useful for logging and monitoring)
 */
export declare function getErrorCategory(error: any): ErrorCategory;
//# sourceMappingURL=retry-handler.d.ts.map