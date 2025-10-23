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

import { logger } from 'firebase-functions/v2';

/**
 * Error categories for retry decisions
 */
export enum ErrorCategory {
  RATE_LIMIT = 'rate_limit',      // 429, rate limit errors - retry with longer backoff
  TRANSIENT = 'transient',         // 500, 503, network errors - retry normally
  PERMANENT = 'permanent',          // 400, 404, validation errors - don't retry
  TIMEOUT = 'timeout',              // ETIMEDOUT, ECONNRESET - retry normally
  UNKNOWN = 'unknown'               // Unknown errors - retry cautiously
}

/**
 * Categorize error for retry decision
 */
function categorizeError(error: any): ErrorCategory {
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
function shouldRetry(error: any): boolean {
  const category = categorizeError(error);

  // Don't retry permanent errors
  if (category === ErrorCategory.PERMANENT) {
    logger.warn('🚫 [RETRY] Permanent error detected, not retrying', {
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
function calculateBackoff(
  attempt: number,
  baseDelay: number,
  maxDelay: number,
  errorCategory: ErrorCategory
): number {
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
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry options configuration
 */
export interface RetryOptions {
  maxRetries?: number;        // Max retry attempts (default: 3)
  baseDelay?: number;         // Base delay in ms (default: 1000)
  maxDelay?: number;          // Max delay in ms (default: 10000)
  onRetry?: (error: any, attempt: number, delay: number) => void;  // Callback before retry
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
export async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  context: string,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxRetries = 3,
    baseDelay = 1000,
    maxDelay = 10000,
    onRetry
  } = options;

  let lastError: any;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      // Execute the operation
      if (attempt === 0) {
        logger.debug(`🔄 [RETRY] Executing: ${context}`);
      } else {
        logger.info(`🔄 [RETRY] Retry attempt ${attempt}/${maxRetries}: ${context}`);
      }

      const result = await operation();

      // Success!
      if (attempt > 0) {
        logger.info(`✅ [RETRY] Succeeded on attempt ${attempt + 1}: ${context}`);
      }

      return result;

    } catch (error: any) {
      lastError = error;

      // Categorize the error
      const errorCategory = categorizeError(error);

      logger.warn(`❌ [RETRY] Attempt ${attempt + 1}/${maxRetries + 1} failed: ${context}`, {
        error: error.message,
        category: errorCategory,
        code: error.code || error.status
      });

      // Check if we should retry
      if (!shouldRetry(error)) {
        logger.error(`🚫 [RETRY] Permanent error, aborting: ${context}`, {
          error: error.message,
          category: errorCategory
        });
        throw error;
      }

      // Check if we've exhausted retries
      if (attempt === maxRetries) {
        logger.error(`🚫 [RETRY] Max retries exhausted: ${context}`, {
          attempts: maxRetries + 1,
          lastError: error.message,
          category: errorCategory
        });
        throw error;
      }

      // Calculate backoff delay
      const delay = calculateBackoff(attempt, baseDelay, maxDelay, errorCategory);

      logger.info(`⏳ [RETRY] Waiting ${delay.toFixed(0)}ms before retry ${attempt + 1}/${maxRetries}: ${context}`, {
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
export async function retryFast<T>(
  operation: () => Promise<T>,
  context: string
): Promise<T> {
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
export async function retryStandard<T>(
  operation: () => Promise<T>,
  context: string
): Promise<T> {
  return retryWithBackoff(operation, context, {
    maxRetries: 3,
    baseDelay: 1000,
    maxDelay: 10000
  });
}

/**
 * Helper: Check if error is retryable (useful for custom retry logic)
 */
export function isRetryableError(error: any): boolean {
  return shouldRetry(error);
}

/**
 * Helper: Get error category (useful for logging and monitoring)
 */
export function getErrorCategory(error: any): ErrorCategory {
  return categorizeError(error);
}
