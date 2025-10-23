"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ErrorType = void 0;
exports.logError = logError;
exports.logWarning = logWarning;
exports.logInfo = logInfo;
exports.getUserFriendlyMessage = getUserFriendlyMessage;
exports.logOperationStart = logOperationStart;
exports.logOperationSuccess = logOperationSuccess;
const v2_1 = require("firebase-functions/v2");
/**
 * Error categories for monitoring and alerting
 */
var ErrorType;
(function (ErrorType) {
    ErrorType["VALIDATION"] = "validation";
    ErrorType["RATE_LIMIT"] = "rate_limit";
    ErrorType["AI_FAILURE"] = "ai_failure";
    ErrorType["NETWORK"] = "network";
    ErrorType["TIMEOUT"] = "timeout";
    ErrorType["INTERNAL"] = "internal";
    ErrorType["AUTHENTICATION"] = "authentication";
    ErrorType["PERMISSION"] = "permission";
    ErrorType["NOT_FOUND"] = "not_found";
    ErrorType["UNKNOWN"] = "unknown"; // Uncategorized error
})(ErrorType || (exports.ErrorType = ErrorType = {}));
/**
 * Infer error type from error object
 */
function inferErrorType(error) {
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
function truncateQuery(query, maxLength = 100) {
    if (!query)
        return undefined;
    if (query.length <= maxLength)
        return query;
    return query.substring(0, maxLength) + '...';
}
/**
 * Build structured log entry
 */
function buildLogEntry(errorType, error, context) {
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
function logError(errorType, error, context = {}) {
    // Infer error type if not provided
    const inferredType = errorType || inferErrorType(error);
    // Build structured log entry
    const logEntry = buildLogEntry(inferredType, error, context);
    // Log with appropriate severity
    switch (inferredType) {
        case ErrorType.VALIDATION:
        case ErrorType.NOT_FOUND:
            // Expected errors - log as warning
            v2_1.logger.warn('⚠️ [ERROR] User/client error', logEntry);
            break;
        case ErrorType.RATE_LIMIT:
            // Rate limit - log as warning (expected with retry)
            v2_1.logger.warn('🚦 [ERROR] Rate limit hit', logEntry);
            break;
        case ErrorType.TIMEOUT:
        case ErrorType.NETWORK:
            // External service issues - log as warning (transient)
            v2_1.logger.warn('🌐 [ERROR] External service issue', logEntry);
            break;
        case ErrorType.AI_FAILURE:
        case ErrorType.INTERNAL:
            // Our code issues - log as error (needs attention)
            v2_1.logger.error('🔥 [ERROR] Internal failure', logEntry);
            break;
        case ErrorType.AUTHENTICATION:
        case ErrorType.PERMISSION:
            // Security issues - log as warning (expected)
            v2_1.logger.warn('🔒 [ERROR] Security error', logEntry);
            break;
        case ErrorType.UNKNOWN:
        default:
            // Unknown errors - log as error (investigate)
            v2_1.logger.error('❓ [ERROR] Unknown error', logEntry);
            break;
    }
}
/**
 * Log warning with structured context
 */
function logWarning(message, context = {}) {
    v2_1.logger.warn('⚠️ [WARNING]', {
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
function logInfo(message, context = {}) {
    v2_1.logger.info('ℹ️ [INFO]', {
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
function getUserFriendlyMessage(error, errorType) {
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
function logOperationStart(operation, context = {}) {
    v2_1.logger.debug('🚀 [START]', {
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
function logOperationSuccess(operation, durationMs, context = {}) {
    v2_1.logger.info('✅ [SUCCESS]', {
        operation,
        durationMs,
        userId: context.userId,
        tier: context.tier,
        sessionId: context.sessionId,
        timestamp: new Date().toISOString(),
        ...context.additionalData
    });
}
//# sourceMappingURL=error-logger.js.map