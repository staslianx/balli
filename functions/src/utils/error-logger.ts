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

import { logger } from 'firebase-functions/v2';

/**
 * Error categories for monitoring and alerting
 */
export enum ErrorType {
  VALIDATION = 'validation',           // Invalid input from user
  RATE_LIMIT = 'rate_limit',          // Rate limit exceeded
  AI_FAILURE = 'ai_failure',          // Gemini API failure
  NETWORK = 'network',                 // External API failure (PubMed, Exa, etc.)
  TIMEOUT = 'timeout',                 // Operation timeout
  INTERNAL = 'internal',               // Internal server error
  AUTHENTICATION = 'authentication',   // Auth failure
  PERMISSION = 'permission',           // Permission denied
  NOT_FOUND = 'not_found',            // Resource not found
  UNKNOWN = 'unknown'                  // Uncategorized error
}

/**
 * Error context for structured logging
 */
export interface ErrorContext {
  userId?: string;                     // User ID (if available)
  tier?: number;                       // Processing tier (1, 2, 3)
  operation?: string;                  // Operation name (e.g., 'Gemini generate', 'PubMed search')
  sessionId?: string;                  // Session ID (if available)
  query?: string;                      // User query (truncated for privacy)
  additionalData?: Record<string, any>; // Any additional context
}

/**
 * Infer error type from error object
 */
function inferErrorType(error: any): ErrorType {
  // Rate limit errors
  if (error.code === 429 ||
      error.status === 429 ||
      error.message?.toLowerCase().includes('rate limit') ||
      error.message?.toLowerCase().includes('quota exceeded')) {
    return ErrorType.RATE_LIMIT;
  }

  // Timeout errors
  if (error.code === 'ETIMEDOUT' ||
      error.code === 'ECONNRESET' ||
      error.message?.toLowerCase().includes('timeout') ||
      error.message?.toLowerCase().includes('timed out')) {
    return ErrorType.TIMEOUT;
  }

  // Network/external API errors
  if (error.code === 'ECONNREFUSED' ||
      error.code === 'ENOTFOUND' ||
      error.code === 503 ||
      error.status === 503 ||
      error.message?.toLowerCase().includes('network') ||
      error.message?.toLowerCase().includes('connection')) {
    return ErrorType.NETWORK;
  }

  // Authentication errors
  if (error.code === 401 ||
      error.status === 401 ||
      error.code === 'unauthenticated' ||
      error.message?.toLowerCase().includes('unauthorized') ||
      error.message?.toLowerCase().includes('authentication')) {
    return ErrorType.AUTHENTICATION;
  }

  // Permission errors
  if (error.code === 403 ||
      error.status === 403 ||
      error.code === 'permission-denied' ||
      error.message?.toLowerCase().includes('forbidden') ||
      error.message?.toLowerCase().includes('permission')) {
    return ErrorType.PERMISSION;
  }

  // Not found errors
  if (error.code === 404 ||
      error.status === 404 ||
      error.message?.toLowerCase().includes('not found')) {
    return ErrorType.NOT_FOUND;
  }

  // Validation errors
  if (error.code === 400 ||
      error.status === 400 ||
      error.code === 'invalid-argument' ||
      error.message?.toLowerCase().includes('invalid') ||
      error.message?.toLowerCase().includes('validation') ||
      error.message?.toLowerCase().includes('bad request')) {
    return ErrorType.VALIDATION;
  }

  // AI/Gemini errors
  if (error.message?.toLowerCase().includes('gemini') ||
      error.message?.toLowerCase().includes('model') ||
      error.message?.toLowerCase().includes('generation') ||
      error.message?.toLowerCase().includes('vertex')) {
    return ErrorType.AI_FAILURE;
  }

  // Internal server errors
  if (error.code === 500 ||
      error.status === 500 ||
      error.code === 'internal' ||
      error.message?.toLowerCase().includes('internal server error')) {
    return ErrorType.INTERNAL;
  }

  // Unknown
  return ErrorType.UNKNOWN;
}

/**
 * Truncate query for privacy and log size
 */
function truncateQuery(query?: string, maxLength: number = 100): string | undefined {
  if (!query) return undefined;
  if (query.length <= maxLength) return query;
  return query.substring(0, maxLength) + '...';
}

/**
 * Build structured log entry
 */
function buildLogEntry(
  errorType: ErrorType,
  error: any,
  context: ErrorContext
) {
  return {
    errorType,
    errorMessage: error.message || String(error),
    errorCode: error.code || error.status,
    userId: context.userId,
    tier: context.tier,
    operation: context.operation,
    sessionId: context.sessionId,
    query: truncateQuery(context.query),
    timestamp: new Date().toISOString(),
    ...context.additionalData
  };
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
export function logError(
  errorType: ErrorType | undefined,
  error: any,
  context: ErrorContext = {}
): void {
  // Infer error type if not provided
  const inferredType = errorType || inferErrorType(error);

  // Build structured log entry
  const logEntry = buildLogEntry(inferredType, error, context);

  // Log with appropriate severity
  switch (inferredType) {
    case ErrorType.VALIDATION:
    case ErrorType.NOT_FOUND:
      // Expected errors - log as warning
      logger.warn('⚠️ [ERROR] User/client error', logEntry);
      break;

    case ErrorType.RATE_LIMIT:
      // Rate limit - log as warning (expected with retry)
      logger.warn('🚦 [ERROR] Rate limit hit', logEntry);
      break;

    case ErrorType.TIMEOUT:
    case ErrorType.NETWORK:
      // External service issues - log as warning (transient)
      logger.warn('🌐 [ERROR] External service issue', logEntry);
      break;

    case ErrorType.AI_FAILURE:
    case ErrorType.INTERNAL:
      // Our code issues - log as error (needs attention)
      logger.error('🔥 [ERROR] Internal failure', logEntry);
      break;

    case ErrorType.AUTHENTICATION:
    case ErrorType.PERMISSION:
      // Security issues - log as warning (expected)
      logger.warn('🔒 [ERROR] Security error', logEntry);
      break;

    case ErrorType.UNKNOWN:
    default:
      // Unknown errors - log as error (investigate)
      logger.error('❓ [ERROR] Unknown error', logEntry);
      break;
  }
}

/**
 * Log warning with structured context
 */
export function logWarning(
  message: string,
  context: ErrorContext = {}
): void {
  logger.warn('⚠️ [WARNING]', {
    message,
    userId: context.userId,
    tier: context.tier,
    operation: context.operation,
    sessionId: context.sessionId,
    query: truncateQuery(context.query),
    timestamp: new Date().toISOString(),
    ...context.additionalData
  });
}

/**
 * Log info with structured context
 */
export function logInfo(
  message: string,
  context: ErrorContext = {}
): void {
  logger.info('ℹ️ [INFO]', {
    message,
    userId: context.userId,
    tier: context.tier,
    operation: context.operation,
    sessionId: context.sessionId,
    query: truncateQuery(context.query),
    timestamp: new Date().toISOString(),
    ...context.additionalData
  });
}

/**
 * Get user-friendly error message based on error type
 * Hides internal details from users
 */
export function getUserFriendlyMessage(error: any, errorType?: ErrorType): string {
  const inferredType = errorType || inferErrorType(error);

  switch (inferredType) {
    case ErrorType.VALIDATION:
      return 'Geçersiz soru. Lütfen sorunuzu kontrol edip tekrar deneyin.';

    case ErrorType.RATE_LIMIT:
      return 'Çok fazla istek gönderildi. Lütfen birkaç saniye bekleyip tekrar deneyin.';

    case ErrorType.AI_FAILURE:
      return 'AI servisi şu anda yanıt veremiyor. Lütfen birkaç saniye sonra tekrar deneyin.';

    case ErrorType.NETWORK:
      return 'Harici kaynaklara ulaşılamıyor. Lütfen internet bağlantınızı kontrol edin.';

    case ErrorType.TIMEOUT:
      return 'İşlem zaman aşımına uğradı. Lütfen sorunuzu daha basit hale getirip tekrar deneyin.';

    case ErrorType.AUTHENTICATION:
      return 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';

    case ErrorType.PERMISSION:
      return 'Bu işlem için yetkiniz yok.';

    case ErrorType.NOT_FOUND:
      return 'İstenen kaynak bulunamadı.';

    case ErrorType.INTERNAL:
    case ErrorType.UNKNOWN:
    default:
      return 'Bir hata oluştu. Lütfen tekrar deneyin. Sorun devam ederse destek ekibine bildirin.';
  }
}

/**
 * Helper: Log operation start (for tracking performance and debugging)
 */
export function logOperationStart(
  operation: string,
  context: ErrorContext = {}
): void {
  logger.debug('🚀 [START]', {
    operation,
    userId: context.userId,
    tier: context.tier,
    sessionId: context.sessionId,
    query: truncateQuery(context.query),
    timestamp: new Date().toISOString(),
    ...context.additionalData
  });
}

/**
 * Helper: Log operation success (for tracking performance)
 */
export function logOperationSuccess(
  operation: string,
  durationMs: number,
  context: ErrorContext = {}
): void {
  logger.info('✅ [SUCCESS]', {
    operation,
    durationMs,
    userId: context.userId,
    tier: context.tier,
    sessionId: context.sessionId,
    timestamp: new Date().toISOString(),
    ...context.additionalData
  });
}
