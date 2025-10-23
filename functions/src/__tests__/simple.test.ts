/**
 * Simple smoke test to verify Jest setup
 */

import { describe, it, expect } from '@jest/globals';

describe('Jest Setup', () => {
  it('should run basic tests', () => {
    expect(1 + 1).toBe(2);
  });

  it('should support async tests', async () => {
    const result = await Promise.resolve(42);
    expect(result).toBe(42);
  });
});
