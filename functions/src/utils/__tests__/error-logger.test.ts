/**
 * Tests for error-logger utility
 */

import {
  logError,
  logWarning,
  logInfo,
  getUserFriendlyMessage,
  ErrorType
} from '../error-logger';
import { logger } from 'firebase-functions/v2';

// Mock firebase logger
jest.mock('firebase-functions/v2', () => ({
  logger: {
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn()
  }
}));

describe('error-logger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('logError', () => {
    it('should log validation errors as warnings', () => {
      const error = new Error('Invalid input');

      logError(ErrorType.VALIDATION, error, {
        userId: 'user123',
        tier: 1,
        operation: 'input validation'
      });

      expect(logger.warn).toHaveBeenCalledWith(
        '⚠️ [ERROR] User/client error',
        expect.objectContaining({
          errorType: ErrorType.VALIDATION,
          errorMessage: 'Invalid input',
          userId: 'user123',
          tier: 1,
          operation: 'input validation'
        })
      );
    });

    it('should log rate limit errors as warnings', () => {
      const error = { status: 429, message: 'Rate limit exceeded' };

      logError(ErrorType.RATE_LIMIT, error, {
        userId: 'user123',
        tier: 2
      });

      expect(logger.warn).toHaveBeenCalledWith(
        '🚦 [ERROR] Rate limit hit',
        expect.objectContaining({
          errorType: ErrorType.RATE_LIMIT,
          errorMessage: 'Rate limit exceeded',
          userId: 'user123',
          tier: 2
        })
      );
    });

    it('should log AI failures as errors', () => {
      const error = new Error('Gemini API timeout');

      logError(ErrorType.AI_FAILURE, error, {
        userId: 'user123',
        tier: 3,
        operation: 'Gemini generate'
      });

      expect(logger.error).toHaveBeenCalledWith(
        '🔥 [ERROR] Internal failure',
        expect.objectContaining({
          errorType: ErrorType.AI_FAILURE,
          errorMessage: 'Gemini API timeout',
          userId: 'user123',
          tier: 3,
          operation: 'Gemini generate'
        })
      );
    });

    it('should auto-detect error type if not provided', () => {
      const error = { status: 429, message: 'Too many requests' };

      logError(undefined, error, { userId: 'user123' });

      expect(logger.warn).toHaveBeenCalledWith(
        '🚦 [ERROR] Rate limit hit',
        expect.objectContaining({
          errorType: ErrorType.RATE_LIMIT
        })
      );
    });

    it('should truncate long queries', () => {
      const longQuery = 'a'.repeat(200);
      const error = new Error('Test error');

      logError(ErrorType.INTERNAL, error, {
        userId: 'user123',
        query: longQuery
      });

      const logCall = (logger.error as jest.Mock).mock.calls[0];
      const loggedQuery = logCall[1].query;

      expect(loggedQuery).toHaveLength(103); // 100 chars + '...'
      expect(loggedQuery).toContain('...');
    });

    it('should include additional data', () => {
      const error = new Error('Test error');

      logError(ErrorType.NETWORK, error, {
        userId: 'user123',
        additionalData: {
          apiName: 'PubMed',
          attempt: 2
        }
      });

      expect(logger.warn).toHaveBeenCalledWith(
        '🌐 [ERROR] External service issue',
        expect.objectContaining({
          apiName: 'PubMed',
          attempt: 2
        })
      );
    });
  });

  describe('logWarning', () => {
    it('should log warnings with context', () => {
      logWarning('API slow response', {
        userId: 'user123',
        tier: 2,
        operation: 'PubMed search',
        additionalData: { duration: 5000 }
      });

      expect(logger.warn).toHaveBeenCalledWith(
        '⚠️ [WARNING]',
        expect.objectContaining({
          message: 'API slow response',
          userId: 'user123',
          tier: 2,
          operation: 'PubMed search',
          duration: 5000
        })
      );
    });
  });

  describe('logInfo', () => {
    it('should log info with context', () => {
      logInfo('Operation successful', {
        userId: 'user123',
        tier: 1
      });

      expect(logger.info).toHaveBeenCalledWith(
        'ℹ️ [INFO]',
        expect.objectContaining({
          message: 'Operation successful',
          userId: 'user123',
          tier: 1
        })
      );
    });
  });

  describe('getUserFriendlyMessage', () => {
    it('should return Turkish message for validation errors', () => {
      const error = new Error('Invalid input');
      const message = getUserFriendlyMessage(error, ErrorType.VALIDATION);

      expect(message).toContain('Geçersiz');
      expect(message).not.toContain('Invalid input'); // No internal details
    });

    it('should return Turkish message for rate limit errors', () => {
      const error = { status: 429, message: 'Rate limit' };
      const message = getUserFriendlyMessage(error, ErrorType.RATE_LIMIT);

      expect(message).toContain('Çok fazla istek');
    });

    it('should return Turkish message for AI failures', () => {
      const error = new Error('Gemini API down');
      const message = getUserFriendlyMessage(error, ErrorType.AI_FAILURE);

      expect(message).toContain('AI servisi');
      expect(message).not.toContain('Gemini'); // No internal details
    });

    it('should return Turkish message for network errors', () => {
      const error = new Error('Connection refused');
      const message = getUserFriendlyMessage(error, ErrorType.NETWORK);

      expect(message).toContain('Harici kaynaklara ulaşılamıyor');
    });

    it('should return Turkish message for timeout errors', () => {
      const error = new Error('Operation timeout');
      const message = getUserFriendlyMessage(error, ErrorType.TIMEOUT);

      expect(message).toContain('zaman aşımı');
    });

    it('should return generic Turkish message for internal errors', () => {
      const error = new Error('Internal server error');
      const message = getUserFriendlyMessage(error, ErrorType.INTERNAL);

      expect(message).toContain('Bir hata oluştu');
      expect(message).not.toContain('Internal server error'); // No internal details
    });

    it('should auto-detect error type', () => {
      const error = { status: 429, message: 'Rate limit' };
      const message = getUserFriendlyMessage(error);

      expect(message).toContain('Çok fazla istek');
    });
  });
});
