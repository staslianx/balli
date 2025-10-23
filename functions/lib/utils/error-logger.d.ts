/**
 * Structured Error Logger
 * Provides consistent error logging across Cloud Functions
 * Categorizes errors for monitoring and debugging
 *
 * Based on audit recommendations:
 * - Categorize errors: validation, rate_limit, ai_failure, network, internal
 * - Use firebase-functions/v2 logger with proper severity
 * - Include context: userId, tier, timestamp
 * - Structured for easy querying in Cloud Logging
 */
/**
 * Error categories for monitoring and alerting
 */
export declare enum ErrorType {
    VALIDATION = "validation",// Invalid input from user
    RATE_LIMIT = "rate_limit",// Rate limit exceeded
    AI_FAILURE = "ai_failure",// Gemini API failure
    NETWORK = "network",// External API failure (PubMed, Exa, etc.)
    TIMEOUT = "timeout",// Operation timeout
    INTERNAL = "internal",// Internal server error
    AUTHENTICATION = "authentication",// Auth failure
    PERMISSION = "permission",// Permission denied
    NOT_FOUND = "not_found",// Resource not found
    UNKNOWN = "unknown"
}
/**
 * Error context for structured logging
 */
export interface ErrorContext {
    userId?: string;
    tier?: number;
    operation?: string;
    sessionId?: string;
    query?: string;
    additionalData?: Record<string, any>;
}
/**
 * Log error with structured context
 *
 * @param errorType - Category of error (or undefined to auto-detect)
 * @param error - Error object or message
 * @param context - Error context for debugging
 *
 * @example
 * // Log validation error
 * logError(ErrorType.VALIDATION, new Error('Invalid question'), {
 *   userId: 'user123',
 *   tier: 1,
 *   operation: 'input validation'
 * });
 *
 * @example
 * // Auto-detect error type
 * logError(undefined, error, {
 *   userId: 'user123',
 *   tier: 2,
 *   operation: 'Gemini generate',
 *   query: userQuestion
 * });
 */
export declare function logError(errorType: ErrorType | undefined, error: any, context?: ErrorContext): void;
/**
 * Log warning with structured context
 */
export declare function logWarning(message: string, context?: ErrorContext): void;
/**
 * Log info with structured context
 */
export declare function logInfo(message: string, context?: ErrorContext): void;
/**
 * Get user-friendly error message based on error type
 * Hides internal details from users
 */
export declare function getUserFriendlyMessage(error: any, errorType?: ErrorType): string;
/**
 * Helper: Log operation start (for tracking performance and debugging)
 */
export declare function logOperationStart(operation: string, context?: ErrorContext): void;
/**
 * Helper: Log operation success (for tracking performance)
 */
export declare function logOperationSuccess(operation: string, durationMs: number, context?: ErrorContext): void;
//# sourceMappingURL=error-logger.d.ts.map