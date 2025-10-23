/**
 * Tests for retry-handler utility
 */

import {
  retryWithBackoff,
  retryFast,
  retryStandard,
  isRetryableError,
  getErrorCategory,
  ErrorCategory
} from '../retry-handler';

describe('retry-handler', () => {
  describe('retryWithBackoff', () => {
    it('should succeed on first attempt', async () => {
      const operation = jest.fn().mockResolvedValue('success');

      const result = await retryWithBackoff(operation, 'test operation');

      expect(result).toBe('success');
      expect(operation).toHaveBeenCalledTimes(1);
    });

    it('should retry on transient failure and eventually succeed', async () => {
      const operation = jest
        .fn()
        .mockRejectedValueOnce(new Error('Service unavailable'))
        .mockRejectedValueOnce(new Error('Service unavailable'))
        .mockResolvedValue('success');

      const result = await retryWithBackoff(operation, 'test operation', {
        maxRetries: 3,
        baseDelay: 10 // Short delay for testing
      });

      expect(result).toBe('success');
      expect(operation).toHaveBeenCalledTimes(3);
    });

    it('should throw error after max retries', async () => {
      const operation = jest.fn().mockRejectedValue(new Error('Service unavailable'));

      await expect(
        retryWithBackoff(operation, 'test operation', {
          maxRetries: 2,
          baseDelay: 10
        })
      ).rejects.toThrow('Service unavailable');

      expect(operation).toHaveBeenCalledTimes(3); // Initial + 2 retries
    });

    it('should not retry permanent errors', async () => {
      const operation = jest.fn().mockRejectedValue({ status: 400, message: 'Bad request' });

      await expect(
        retryWithBackoff(operation, 'test operation', {
          maxRetries: 3,
          baseDelay: 10
        })
      ).rejects.toMatchObject({ status: 400 });

      expect(operation).toHaveBeenCalledTimes(1); // No retries
    });

    it('should call onRetry callback', async () => {
      const operation = jest
        .fn()
        .mockRejectedValueOnce(new Error('Timeout'))
        .mockResolvedValue('success');

      const onRetry = jest.fn();

      await retryWithBackoff(operation, 'test operation', {
        maxRetries: 2,
        baseDelay: 10,
        onRetry
      });

      expect(onRetry).toHaveBeenCalledTimes(1);
      expect(onRetry).toHaveBeenCalledWith(
        expect.any(Error),
        1, // Attempt number
        expect.any(Number) // Delay
      );
    });

    it('should use exponential backoff', async () => {
      const operation = jest
        .fn()
        .mockRejectedValueOnce(new Error('Error 1'))
        .mockRejectedValueOnce(new Error('Error 2'))
        .mockResolvedValue('success');

      const delays: number[] = [];
      const onRetry = jest.fn((_, __, delay) => {
        delays.push(delay);
      });

      await retryWithBackoff(operation, 'test operation', {
        maxRetries: 3,
        baseDelay: 100,
        onRetry
      });

      // Check that delays increase exponentially
      expect(delays.length).toBe(2);
      expect(delays[1]).toBeGreaterThan(delays[0]);
    });

    it('should use longer backoff for rate limit errors', async () => {
      const rateLimitError = { status: 429, message: 'Rate limit exceeded' };
      const operation = jest
        .fn()
        .mockRejectedValueOnce(rateLimitError)
        .mockResolvedValue('success');

      const delays: number[] = [];
      const onRetry = jest.fn((_, __, delay) => {
        delays.push(delay);
      });

      await retryWithBackoff(operation, 'test operation', {
        maxRetries: 2,
        baseDelay: 100,
        onRetry
      });

      // Rate limit should have longer backoff (close to 200ms base, accounting for jitter)
      expect(delays[0]).toBeGreaterThanOrEqual(180); // 200ms base - 10% jitter tolerance
    });
  });

  describe('retryFast', () => {
    it('should use fast settings', async () => {
      const operation = jest
        .fn()
        .mockRejectedValueOnce(new Error('Transient error'))
        .mockResolvedValue('success');

      const result = await retryFast(operation, 'fast operation');

      expect(result).toBe('success');
      expect(operation).toHaveBeenCalledTimes(2);
    });
  });

  describe('retryStandard', () => {
    it('should use standard settings', async () => {
      const operation = jest
        .fn()
        .mockRejectedValueOnce(new Error('Transient error'))
        .mockResolvedValue('success');

      const result = await retryStandard(operation, 'standard operation');

      expect(result).toBe('success');
      expect(operation).toHaveBeenCalledTimes(2);
    });
  });

  describe('isRetryableError', () => {
    it('should return true for rate limit errors', () => {
      const error = { status: 429, message: 'Rate limit' };
      expect(isRetryableError(error)).toBe(true);
    });

    it('should return true for timeout errors', () => {
      const error = { code: 'ETIMEDOUT', message: 'Timeout' };
      expect(isRetryableError(error)).toBe(true);
    });

    it('should return true for transient errors', () => {
      const error = { status: 503, message: 'Service unavailable' };
      expect(isRetryableError(error)).toBe(true);
    });

    it('should return false for permanent errors', () => {
      const error = { status: 400, message: 'Bad request' };
      expect(isRetryableError(error)).toBe(false);
    });

    it('should return false for not found errors', () => {
      const error = { status: 404, message: 'Not found' };
      expect(isRetryableError(error)).toBe(false);
    });
  });

  describe('getErrorCategory', () => {
    it('should categorize rate limit errors', () => {
      const error = { status: 429, message: 'Rate limit' };
      expect(getErrorCategory(error)).toBe(ErrorCategory.RATE_LIMIT);
    });

    it('should categorize timeout errors', () => {
      const error = { code: 'ETIMEDOUT' };
      expect(getErrorCategory(error)).toBe(ErrorCategory.TIMEOUT);
    });

    it('should categorize transient errors', () => {
      const error = { status: 503, message: 'Service unavailable' };
      expect(getErrorCategory(error)).toBe(ErrorCategory.TRANSIENT);
    });

    it('should categorize permanent errors', () => {
      const error = { status: 400, message: 'Bad request' };
      expect(getErrorCategory(error)).toBe(ErrorCategory.PERMANENT);
    });

    it('should categorize unknown errors', () => {
      const error = { message: 'Something weird happened' };
      expect(getErrorCategory(error)).toBe(ErrorCategory.UNKNOWN);
    });
  });
});
