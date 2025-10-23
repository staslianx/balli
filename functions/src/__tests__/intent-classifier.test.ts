/**
 * Intent Classifier Tests
 *
 * Tests the SPECIFICATION of intent classification:
 * - Greetings should only need immediate context
 * - Health queries should need session + vector search
 * - Memory recalls should need historical + vector search
 * - Follow-ups should need session context
 * - Fallback logic should handle LLM failures gracefully
 */

import { describe, it, expect, beforeEach, jest, afterEach } from '@jest/globals';
import { classifyMessageIntent } from '../intent-classifier';
import { ai } from '../genkit-instance';

describe('Intent Classifier', () => {
  let generateSpy: any;

  beforeEach(() => {
    // Create a spy on ai.generate method
    generateSpy = jest.spyOn(ai, 'generate');
  });

  afterEach(() => {
    // Restore original implementation
    generateSpy.mockRestore();
  });

  describe('Greeting Classification', () => {
    it('should classify simple Turkish greeting with only immediate context', async () => {
      // Mock LLM response
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'greeting',
          confidence: 0.95,
          keywords: ['merhaba'],
          contextNeeded: {
            immediate: true,
            session: false,
            historical: false,
            vectorSearch: false
          },
          reasoning: 'Basit selamlaşma'
        })
      });

      const intent = await classifyMessageIntent('Merhaba');

      expect(intent.category).toBe('greeting');
      expect(intent.contextNeeded.immediate).toBe(true);
      expect(intent.contextNeeded.session).toBe(false);
      expect(intent.contextNeeded.historical).toBe(false);
      expect(intent.contextNeeded.vectorSearch).toBe(false);
    });

    it('should use fallback for greeting when LLM fails', async () => {
      // Mock LLM failure
      generateSpy.mockRejectedValue(new Error('LLM timeout'));

      const intent = await classifyMessageIntent('Günaydın');

      // Fallback should still classify as greeting
      expect(intent.category).toBe('greeting');
      expect(intent.contextNeeded.immediate).toBe(true);
      expect(intent.contextNeeded.session).toBe(false);
      expect(intent.contextNeeded.vectorSearch).toBe(false);
    });

    it('should NOT classify long message as greeting (fallback protection)', async () => {
      generateSpy.mockRejectedValue(new Error('LLM failure'));

      // Long message should not be greeting even with greeting word
      const intent = await classifyMessageIntent(
        'Merhaba, diyabet hakkında çok detaylı bilgi almak istiyorum'
      );

      // Should fallback to general or health_query, NOT greeting
      expect(intent.category).not.toBe('greeting');
    });
  });

  describe('Health Query Classification', () => {
    it('should classify health query with session and vectorSearch context', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'health_query',
          confidence: 0.92,
          keywords: ['A1C', 'diyabet'],
          contextNeeded: {
            immediate: true,
            session: true,
            historical: false,
            vectorSearch: true
          },
          reasoning: 'Sağlık bilgisi talebi'
        })
      });

      const intent = await classifyMessageIntent('A1C nedir?');

      expect(intent.category).toBe('health_query');
      expect(intent.contextNeeded.session).toBe(true);
      expect(intent.contextNeeded.vectorSearch).toBe(true);
    });

    it('should use fallback for health query with health keywords', async () => {
      generateSpy.mockRejectedValue(new Error('LLM failure'));

      const intent = await classifyMessageIntent('Kan şekeri ölçümü nasıl yapılır?');

      expect(intent.category).toBe('health_query');
      expect(intent.contextNeeded.session).toBe(false); // ✅ FIXED: Fallback defaults to new topic (session: false) for safety
      expect(intent.contextNeeded.vectorSearch).toBe(true);
      expect(intent.contextNeeded.historical).toBe(false); // Health queries don't need historical
    });
  });

  describe('Memory Recall Classification', () => {
    it('should classify memory recall with historical and vectorSearch', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'memory_recall',
          confidence: 0.89,
          keywords: ['hatırlıyor musun', 'badem unu'],
          contextNeeded: {
            immediate: true,
            session: true,
            historical: true,
            vectorSearch: true
          },
          reasoning: 'Geçmiş konuşma hatırlatma'
        })
      });

      const intent = await classifyMessageIntent('Hatırlıyor musun badem unu tarifleri?');

      expect(intent.category).toBe('memory_recall');
      expect(intent.contextNeeded.historical).toBe(true);
      expect(intent.contextNeeded.vectorSearch).toBe(true);
      expect(intent.contextNeeded.session).toBe(true);
    });

    it('should use fallback for memory recall keywords', async () => {
      generateSpy.mockRejectedValue(new Error('LLM failure'));

      const intent = await classifyMessageIntent('Daha önce konuştuk mu bu konu hakkında?');

      expect(intent.category).toBe('memory_recall');
      expect(intent.contextNeeded.historical).toBe(true);
      expect(intent.contextNeeded.vectorSearch).toBe(true);
    });
  });

  describe('Follow-up Classification', () => {
    it('should classify follow-up with session context only', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'follow_up',
          confidence: 0.88,
          keywords: ['peki ya'],
          contextNeeded: {
            immediate: true,
            session: true,
            historical: false,
            vectorSearch: false
          },
          reasoning: 'Mevcut konuya devam'
        })
      });

      const intent = await classifyMessageIntent('Peki ya HbA1c?');

      expect(intent.category).toBe('follow_up');
      expect(intent.contextNeeded.session).toBe(true);
      expect(intent.contextNeeded.vectorSearch).toBe(false); // Follow-ups don't need vector search
      expect(intent.contextNeeded.historical).toBe(false);
    });
  });

  describe('General Conversation Classification', () => {
    it('should classify general conversation with immediate and session', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'general',
          confidence: 0.75,
          keywords: [],
          contextNeeded: {
            immediate: true,
            session: true,
            historical: false,
            vectorSearch: false
          },
          reasoning: 'Genel konuşma'
        })
      });

      const intent = await classifyMessageIntent('Bu uygulama nasıl çalışıyor?');

      expect(intent.category).toBe('general');
      expect(intent.contextNeeded.immediate).toBe(true);
      expect(intent.contextNeeded.session).toBe(true);
    });

    it('should use fallback for unrecognized messages', async () => {
      generateSpy.mockRejectedValue(new Error('LLM failure'));

      // Random message with no keywords
      const intent = await classifyMessageIntent('Bugün hava çok güzel');

      expect(intent.category).toBe('general');
      expect(intent.contextNeeded.immediate).toBe(true);
      expect(intent.contextNeeded.session).toBe(true);
      expect(intent.contextNeeded.historical).toBe(false);
      expect(intent.contextNeeded.vectorSearch).toBe(false);
    });
  });

  describe('Fallback Robustness', () => {
    it('should handle malformed JSON from LLM', async () => {
      generateSpy.mockResolvedValue({
        text: 'This is not JSON at all!'
      });

      const intent = await classifyMessageIntent('Test message');

      // Should not throw, should use fallback
      expect(intent).toBeDefined();
      expect(intent.category).toBeDefined();
      expect(intent.contextNeeded).toBeDefined();
    });

    it('should handle empty response from LLM', async () => {
      generateSpy.mockResolvedValue({
        text: ''
      });

      const intent = await classifyMessageIntent('Test');

      expect(intent).toBeDefined();
      expect(intent.category).toBe('general'); // Default fallback
    });

    it('should handle network timeout gracefully', async () => {
      generateSpy.mockRejectedValue(new Error('ETIMEDOUT'));

      const intent = await classifyMessageIntent('Kan şekeri takibi');

      // Fallback should work
      expect(intent.category).toBe('health_query');
      expect(intent.contextNeeded.vectorSearch).toBe(true);
    });
  });

  describe('Intent Confidence Levels', () => {
    it('should have high confidence for clear greetings', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'greeting',
          confidence: 0.95,
          keywords: ['günaydın'],
          contextNeeded: { immediate: true, session: false, historical: false, vectorSearch: false },
          reasoning: 'Açık selamlaşma'
        })
      });

      const intent = await classifyMessageIntent('Günaydın');

      expect(intent.confidence).toBeGreaterThanOrEqual(0.9);
    });

    it('should have lower confidence for ambiguous messages (fallback)', async () => {
      generateSpy.mockRejectedValue(new Error('LLM failure'));

      // Ambiguous message
      const intent = await classifyMessageIntent('Nasıl?');

      // Fallback should have lower confidence
      expect(intent.confidence).toBeLessThan(0.9);
    });
  });

  describe('Context Optimization', () => {
    it('should request minimal context for greetings (cost optimization)', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'greeting',
          confidence: 0.94,
          keywords: ['selam'],
          contextNeeded: { immediate: true, session: false, historical: false, vectorSearch: false },
          reasoning: 'Basit selam'
        })
      });

      const intent = await classifyMessageIntent('Selam');

      // Only immediate context needed - cost optimization
      expect(intent.contextNeeded.session).toBe(false);
      expect(intent.contextNeeded.historical).toBe(false);
      expect(intent.contextNeeded.vectorSearch).toBe(false);
    });

    it('should request maximum context for memory recalls', async () => {
      generateSpy.mockResolvedValue({
        text: JSON.stringify({
          category: 'memory_recall',
          confidence: 0.91,
          keywords: ['hatırla'],
          contextNeeded: { immediate: true, session: true, historical: true, vectorSearch: true },
          reasoning: 'Hafıza hatırlatma'
        })
      });

      const intent = await classifyMessageIntent('Hatırla bana dediğimi');

      // All context types needed for memory recall
      expect(intent.contextNeeded.immediate).toBe(true);
      expect(intent.contextNeeded.session).toBe(true);
      expect(intent.contextNeeded.historical).toBe(true);
      expect(intent.contextNeeded.vectorSearch).toBe(true);
    });
  });
});
