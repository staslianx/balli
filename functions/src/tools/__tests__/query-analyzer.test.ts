/**
 * Query Analyzer Tests
 * Validates query categorization accuracy and API distribution logic
 */

import { describe, it, expect, beforeAll } from '@jest/globals';
import { analyzeQuery, calculateSourceCounts, type QueryAnalysis } from '../query-analyzer';

describe('Query Analyzer', () => {
  // Test timeout for AI calls
  const TEST_TIMEOUT = 10000;

  describe('Drug Safety Categorization', () => {
    it('should categorize medication side effects query correctly', async () => {
      const result = await analyzeQuery('Metformin yan etkileri nelerdir?', 10);

      expect(result.category).toBe('drug_safety');
      expect(result.pubmedRatio).toBeGreaterThan(0.6); // Should emphasize PubMed
      expect(result.confidence).toBeGreaterThan(0.7);

      // Validate ratios sum to 1.0
      const sum = result.pubmedRatio + result.arxivRatio + result.clinicalTrialsRatio;
      expect(sum).toBeCloseTo(1.0, 2);
    }, TEST_TIMEOUT);

    it('should categorize drug interaction query correctly', async () => {
      const result = await analyzeQuery('Lantus ile antibiyotik etkileşimi var mı?', 10);

      expect(result.category).toBe('drug_safety');
      expect(result.pubmedRatio).toBeGreaterThan(0.6);
      expect(result.confidence).toBeGreaterThan(0.7);
    }, TEST_TIMEOUT);

    it('should handle English drug safety queries', async () => {
      const result = await analyzeQuery('What are the side effects of SGLT2 inhibitors?', 10);

      expect(result.category).toBe('drug_safety');
      expect(result.pubmedRatio).toBeGreaterThan(0.6);
    }, TEST_TIMEOUT);
  });

  describe('New Research Categorization', () => {
    it('should categorize cutting-edge research query correctly', async () => {
      const result = await analyzeQuery('Beta cell regeneration latest research', 10);

      expect(result.category).toBe('new_research');
      expect(result.arxivRatio).toBeGreaterThan(0.3); // Should emphasize arXiv for latest
      expect(result.confidence).toBeGreaterThan(0.7);
    }, TEST_TIMEOUT);

    it('should categorize clinical trial query with high trial ratio', async () => {
      const result = await analyzeQuery('GLP-1 agonist 2025 clinical trials', 10);

      expect(result.category).toBe('new_research');
      expect(result.clinicalTrialsRatio).toBeGreaterThan(0.25); // Should emphasize trials
      expect(result.confidence).toBeGreaterThan(0.7);
    }, TEST_TIMEOUT);

    it('should handle Turkish new research queries', async () => {
      const result = await analyzeQuery('Diyabet tedavisinde en yeni araştırmalar', 10);

      expect(result.category).toBe('new_research');
      expect(result.confidence).toBeGreaterThan(0.6);
    }, TEST_TIMEOUT);
  });

  describe('Treatment Categorization', () => {
    it('should categorize treatment guidelines query correctly', async () => {
      const result = await analyzeQuery('Type 1 diabetes insulin therapy guidelines', 10);

      expect(result.category).toBe('treatment');
      expect(result.pubmedRatio).toBeGreaterThan(0.5); // Guidelines need established literature
      expect(result.confidence).toBeGreaterThan(0.7);
    }, TEST_TIMEOUT);

    it('should categorize A1C target query correctly', async () => {
      const result = await analyzeQuery('A1C hedefim ne olmalı?', 10);

      expect(result.category).toBe('treatment');
      expect(result.pubmedRatio).toBeGreaterThan(0.5);
      expect(result.confidence).toBeGreaterThan(0.6);
    }, TEST_TIMEOUT);
  });

  describe('Nutrition Categorization', () => {
    it('should categorize nutrition science query correctly', async () => {
      const result = await analyzeQuery('Badem unu kan şekerine etkisi', 10);

      expect(result.category).toBe('nutrition');
      expect(result.pubmedRatio).toBeGreaterThan(0.7); // Nutrition research in PubMed
      expect(result.confidence).toBeGreaterThan(0.6);
    }, TEST_TIMEOUT);

    it('should categorize diet research query correctly', async () => {
      const result = await analyzeQuery('Low carb diet diabetes research', 10);

      expect(result.category).toBe('nutrition');
      expect(result.pubmedRatio).toBeGreaterThan(0.6);
      expect(result.confidence).toBeGreaterThan(0.7);
    }, TEST_TIMEOUT);
  });

  describe('General Categorization', () => {
    it('should categorize educational query as general', async () => {
      const result = await analyzeQuery('A1C nedir nasıl ölçülür?', 10);

      expect(result.category).toBe('general');
      expect(result.confidence).toBeGreaterThan(0.6);

      // General queries should have balanced distribution
      expect(result.pubmedRatio).toBeGreaterThan(0.3);
      expect(result.pubmedRatio).toBeLessThan(0.7);
    }, TEST_TIMEOUT);
  });

  describe('Fallback Handling', () => {
    it('should handle empty query gracefully', async () => {
      const result = await analyzeQuery('', 10);

      expect(result.category).toBe('general');
      expect(result.confidence).toBeLessThanOrEqual(0.6);
    }, TEST_TIMEOUT);

    it('should handle very short query gracefully', async () => {
      const result = await analyzeQuery('A1C', 10);

      expect(result).toBeDefined();
      expect(result.category).toBeDefined();
    }, TEST_TIMEOUT);
  });

  describe('Ratio Validation', () => {
    it('should ensure ratios always sum to 1.0', async () => {
      const queries = [
        'Metformin yan etkileri',
        'Beta cell regeneration',
        'A1C nedir',
        'Low carb diet research'
      ];

      for (const query of queries) {
        const result = await analyzeQuery(query, 10);
        const sum = result.pubmedRatio + result.arxivRatio + result.clinicalTrialsRatio;

        expect(sum).toBeCloseTo(1.0, 2); // Allow small floating point errors
      }
    }, TEST_TIMEOUT * 4);
  });

  describe('Source Count Calculation', () => {
    it('should calculate correct source counts for T2 (5 API sources)', () => {
      const analysis: QueryAnalysis = {
        category: 'drug_safety',
        pubmedRatio: 0.7,
        arxivRatio: 0.1,
        clinicalTrialsRatio: 0.2,
        confidence: 0.9
      };

      const counts = calculateSourceCounts(analysis, 5);

      // Should distribute 5 sources according to ratios
      expect(counts.pubmedCount + counts.arxivCount + counts.clinicalTrialsCount).toBe(5);
      expect(counts.pubmedCount).toBeGreaterThanOrEqual(3); // 70% of 5 ≈ 3-4
      expect(counts.pubmedCount).toBeLessThanOrEqual(4);
    });

    it('should calculate correct source counts for T3 (15 API sources)', () => {
      const analysis: QueryAnalysis = {
        category: 'new_research',
        pubmedRatio: 0.4,
        arxivRatio: 0.4,
        clinicalTrialsRatio: 0.2,
        confidence: 0.9
      };

      const counts = calculateSourceCounts(analysis, 15);

      // Should distribute 15 sources according to ratios
      expect(counts.pubmedCount + counts.arxivCount + counts.clinicalTrialsCount).toBe(15);
      expect(counts.pubmedCount).toBeGreaterThanOrEqual(5); // 40% of 15 = 6
      expect(counts.pubmedCount).toBeLessThanOrEqual(7);
      expect(counts.arxivCount).toBeGreaterThanOrEqual(5);
      expect(counts.arxivCount).toBeLessThanOrEqual(7);
    });

    it('should handle edge case with all sources from one API', () => {
      const analysis: QueryAnalysis = {
        category: 'nutrition',
        pubmedRatio: 1.0,
        arxivRatio: 0.0,
        clinicalTrialsRatio: 0.0,
        confidence: 0.9
      };

      const counts = calculateSourceCounts(analysis, 10);

      expect(counts.pubmedCount).toBe(10);
      expect(counts.arxivCount).toBe(0);
      expect(counts.clinicalTrialsCount).toBe(0);
    });

    it('should ensure no negative counts', () => {
      const analysis: QueryAnalysis = {
        category: 'general',
        pubmedRatio: 0.5,
        arxivRatio: 0.3,
        clinicalTrialsRatio: 0.2,
        confidence: 0.8
      };

      const counts = calculateSourceCounts(analysis, 2); // Very small target

      expect(counts.pubmedCount).toBeGreaterThanOrEqual(0);
      expect(counts.arxivCount).toBeGreaterThanOrEqual(0);
      expect(counts.clinicalTrialsCount).toBeGreaterThanOrEqual(0);
      expect(counts.pubmedCount + counts.arxivCount + counts.clinicalTrialsCount).toBe(2);
    });
  });

  describe('Performance', () => {
    it('should complete analysis within 2 seconds', async () => {
      const startTime = Date.now();
      await analyzeQuery('Metformin yan etkileri', 10);
      const duration = Date.now() - startTime;

      expect(duration).toBeLessThan(2000); // Should be <2s as per spec
    });
  });
});
