"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ErrorCategory = void 0;
exports.retryWithBackoff = retryWithBackoff;
exports.retryFast = retryFast;
exports.retryStandard = retryStandard;
exports.isRetryableError = isRetryableError;
exports.getErrorCategory = getErrorCategory;
const v2_1 = require("firebase-functions/v2");
/**
 * Error categories for retry decisions
 */
var ErrorCategory;
(function (ErrorCategory) {
    ErrorCategory["RATE_LIMIT"] = "rate_limit";
    ErrorCategory["TRANSIENT"] = "transient";
    ErrorCategory["PERMANENT"] = "permanent";
    ErrorCategory["TIMEOUT"] = "timeout";
    ErrorCategory["UNKNOWN"] = "unknown"; // Unknown errors - retry cautiously
})(ErrorCategory || (exports.ErrorCategory = ErrorCategory = {}));
/**
 * Categorize error for retry decision
 */
function categorizeError(error) {
    // Check for rate limit errors (429)
    if (error.code === 429 ||
        error.status === 429 ||
        error.message?.toLowerCase().includes('rate limit') ||
        error.message?.toLowerCase().includes('quota exceeded') ||
        error.message?.toLowerCase().includes('too many requests')) {
        return ErrorCategory.RATE_LIMIT;
    }
    // Check for timeout errors
    if (error.code === 'ETIMEDOUT' ||
        error.code === 'ECONNRESET' ||
        error.code === 'ECONNREFUSED' ||
        error.message?.toLowerCase().includes('timeout') ||
        error.message?.toLowerCase().includes('timed out')) {
        return ErrorCategory.TIMEOUT;
    }
    // Check for transient server errors (500, 503)
    if (error.status === 500 ||
        error.status === 503 ||
        error.code === 500 ||
        error.code === 503 ||
        error.message?.toLowerCase().includes('internal server error') ||
        error.message?.toLowerCase().includes('service unavailable') ||
        error.message?.toLowerCase().includes('temporarily unavailable')) {
        return ErrorCategory.TRANSIENT;
    }
    // Check for permanent errors (400, 404, 401, 403)
    if (error.status === 400 ||
        error.status === 404 ||
        error.status === 401 ||
        error.status === 403 ||
        error.code === 400 ||
        error.code === 404 ||
        error.code === 401 ||
        error.code === 403 ||
        error.message?.toLowerCase().includes('not found') ||
        error.message?.toLowerCase().includes('unauthorized') ||
        error.message?.toLowerCase().includes('forbidden') ||
        error.message?.toLowerCase().includes('invalid') ||
        error.message?.toLowerCase().includes('bad request')) {
        return ErrorCategory.PERMANENT;
    }
    // Unknown error - be cautious
    return ErrorCategory.UNKNOWN;
}
/**
 * Check if error should be retried
 */
function shouldRetry(error) {
    const category = categorizeError(error);
    // Don't retry permanent errors
    if (category === ErrorCategory.PERMANENT) {
        v2_1.logger.warn('🚫 [RETRY] Permanent error detected, not retrying', {
            error: error.message,
            category
        });
        return false;
    }
    // Retry all other categories
    return true;
}
/**
 * Calculate backoff delay with exponential growth and jitter
 */
function calculateBackoff(attempt, baseDelay, maxDelay, errorCategory) {
    // Use longer backoff for rate limits (double the base delay)
    const effectiveBaseDelay = errorCategory === ErrorCategory.RATE_LIMIT
        ? baseDelay * 2
        : baseDelay;
    // Exponential backoff: baseDelay * 2^attempt
    const exponentialDelay = effectiveBaseDelay * Math.pow(2, attempt);
    // Add jitter (±20% random variation) to avoid thundering herd
    const jitter = exponentialDelay * 0.2 * (Math.random() - 0.5);
    // Cap at maxDelay
    const delayWithJitter = exponentialDelay + jitter;
    return Math.min(delayWithJitter, maxDelay);
}
/**
 * Sleep utility
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
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
async function retryWithBackoff(operation, context, options = {}) {
    const { maxRetries = 3, baseDelay = 1000, maxDelay = 10000, onRetry } = options;
    let lastError;
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            // Execute the operation
            if (attempt === 0) {
                v2_1.logger.debug(`🔄 [RETRY] Executing: ${context}`);
            }
            else {
                v2_1.logger.info(`🔄 [RETRY] Retry attempt ${attempt}/${maxRetries}: ${context}`);
            }
            const result = await operation();
            // Success!
            if (attempt > 0) {
                v2_1.logger.info(`✅ [RETRY] Succeeded on attempt ${attempt + 1}: ${context}`);
            }
            return result;
        }
        catch (error) {
            lastError = error;
            // Categorize the error
            const errorCategory = categorizeError(error);
            v2_1.logger.warn(`❌ [RETRY] Attempt ${attempt + 1}/${maxRetries + 1} failed: ${context}`, {
                error: error.message,
                category: errorCategory,
                code: error.code || error.status
            });
            // Check if we should retry
            if (!shouldRetry(error)) {
                v2_1.logger.error(`🚫 [RETRY] Permanent error, aborting: ${context}`, {
                    error: error.message,
                    category: errorCategory
                });
                throw error;
            }
            // Check if we've exhausted retries
            if (attempt === maxRetries) {
                v2_1.logger.error(`🚫 [RETRY] Max retries exhausted: ${context}`, {
                    attempts: maxRetries + 1,
                    lastError: error.message,
                    category: errorCategory
                });
                throw error;
            }
            // Calculate backoff delay
            const delay = calculateBackoff(attempt, baseDelay, maxDelay, errorCategory);
            v2_1.logger.info(`⏳ [RETRY] Waiting ${delay.toFixed(0)}ms before retry ${attempt + 1}/${maxRetries}: ${context}`, {
                errorCategory,
                delay: `${delay.toFixed(0)}ms`
            });
            // Call retry callback if provided
            if (onRetry) {
                onRetry(error, attempt + 1, delay);
            }
            // Wait before retrying
            await sleep(delay);
        }
    }
    // Should never reach here, but TypeScript needs this
    throw lastError;
}
/**
 * Helper: Retry with shorter settings for fast operations (API searches)
 * Max 2 retries, 500ms base delay, 5s max delay
 */
async function retryFast(operation, context) {
    return retryWithBackoff(operation, context, {
        maxRetries: 2,
        baseDelay: 500,
        maxDelay: 5000
    });
}
/**
 * Helper: Retry with standard settings for normal operations
 * Max 3 retries, 1s base delay, 10s max delay
 */
async function retryStandard(operation, context) {
    return retryWithBackoff(operation, context, {
        maxRetries: 3,
        baseDelay: 1000,
        maxDelay: 10000
    });
}
/**
 * Helper: Check if error is retryable (useful for custom retry logic)
 */
function isRetryableError(error) {
    return shouldRetry(error);
}
/**
 * Helper: Get error category (useful for logging and monitoring)
 */
function getErrorCategory(error) {
    return categorizeError(error);
}
//# sourceMappingURL=retry-handler.js.map