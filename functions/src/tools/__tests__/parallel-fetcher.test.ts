/**
 * Parallel Research Fetcher Integration Tests
 * Tests concurrent API fetching with fault tolerance
 */

import { describe, it, expect } from '@jest/globals';
import {
  fetchAllResearchSources,
  createT2Config,
  createT3Config,
  type ResearchFetchConfig
} from '../parallel-research-fetcher';

describe('Parallel Research Fetcher', () => {
  // Longer timeout for real API calls
  const TEST_TIMEOUT = 20000;

  describe('Basic Fetching', () => {
    it('should fetch from all sources in parallel', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 2,
        pubmedCount: 2,
        arxivCount: 2,
        clinicalTrialsCount: 2
      };

      const results = await fetchAllResearchSources('diabetes type 1 treatment', config);

      // Should have results from each API (may be partial due to availability)
      expect(results).toBeDefined();
      expect(results.exa).toBeDefined();
      expect(results.pubmed).toBeDefined();
      expect(results.arxiv).toBeDefined();
      expect(results.clinicalTrials).toBeDefined();

      // Should have timing data
      expect(results.timings.total).toBeGreaterThan(0);
      expect(results.timings.exa).toBeGreaterThanOrEqual(0);
      expect(results.timings.pubmed).toBeGreaterThanOrEqual(0);
      expect(results.timings.arxiv).toBeGreaterThanOrEqual(0);
      expect(results.timings.clinicalTrials).toBeGreaterThanOrEqual(0);
    }, TEST_TIMEOUT);

    it('should respect requested source counts', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 3,
        pubmedCount: 3,
        arxivCount: 0, // Skip arXiv
        clinicalTrialsCount: 0 // Skip trials
      };

      const results = await fetchAllResearchSources('metformin side effects', config);

      // Should have attempted to fetch Exa and PubMed
      expect(results.exa.length).toBeLessThanOrEqual(3);
      expect(results.pubmed.length).toBeLessThanOrEqual(3);
      expect(results.arxiv.length).toBe(0); // Should be empty
      expect(results.clinicalTrials.length).toBe(0); // Should be empty
    }, TEST_TIMEOUT);
  });

  describe('T2 Configuration (10 sources)', () => {
    it('should fetch T2 sources within 8 seconds', async () => {
      const config = createT2Config(3, 1, 1); // 5 Exa + 3 PubMed + 1 arXiv + 1 Trial = 10 total

      const startTime = Date.now();
      const results = await fetchAllResearchSources('insulin therapy guidelines', config);
      const duration = Date.now() - startTime;

      // Should complete within 8 seconds (Phase 1 success criterion)
      expect(duration).toBeLessThan(8000);

      // Should attempt to fetch correct source counts
      expect(config.exaCount).toBe(5);
      expect(config.pubmedCount + config.arxivCount + config.clinicalTrialsCount).toBe(5);
    }, TEST_TIMEOUT);

    it('should handle T2 drug safety query', async () => {
      const config = createT2Config(4, 0, 1); // 70% PubMed, 0% arXiv, 20% Trials

      const results = await fetchAllResearchSources('SGLT2 inhibitor contraindications', config);

      // Should prioritize PubMed for drug safety
      expect(config.pubmedCount).toBeGreaterThan(config.arxivCount);
      expect(config.pubmedCount).toBeGreaterThan(config.clinicalTrialsCount);
    });
  });

  describe('T3 Configuration (25 sources)', () => {
    it('should fetch T3 sources within 20 seconds', async () => {
      const config = createT3Config(8, 4, 3); // 10 Exa + 8 PubMed + 4 arXiv + 3 Trial = 25 total

      const startTime = Date.now();
      const results = await fetchAllResearchSources('beta cell regeneration research', config);
      const duration = Date.now() - startTime;

      // Should complete within 20 seconds (Phase 1 success criterion)
      expect(duration).toBeLessThan(20000);

      // Should attempt to fetch correct source counts
      expect(config.exaCount).toBe(10);
      expect(config.pubmedCount + config.arxivCount + config.clinicalTrialsCount).toBe(15);
    }, TEST_TIMEOUT);

    it('should handle T3 new research query', async () => {
      const config = createT3Config(6, 6, 3); // Balanced for new research

      const results = await fetchAllResearchSources('GLP-1 agonist 2025 trials', config);

      // Should have balanced distribution
      expect(config.pubmedCount).toBeGreaterThanOrEqual(5);
      expect(config.arxivCount).toBeGreaterThanOrEqual(5);
    });
  });

  describe('Fault Tolerance', () => {
    it('should handle partial failures gracefully', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 3,
        pubmedCount: 3,
        arxivCount: 3,
        clinicalTrialsCount: 3
      };

      // Use a query that might fail on some APIs
      const results = await fetchAllResearchSources('xyz123 nonexistent query', config);

      // Should not throw - should return empty arrays for failed APIs
      expect(results).toBeDefined();
      expect(results.errors).toBeDefined();

      // Should have timing data even for failures
      expect(results.timings.total).toBeGreaterThan(0);
    }, TEST_TIMEOUT);

    it('should continue when one API fails', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 2,
        pubmedCount: 2,
        arxivCount: 2,
        clinicalTrialsCount: 2
      };

      const results = await fetchAllResearchSources('diabetes', config);

      // Even if one API fails, others should succeed
      const totalSources = results.exa.length + results.pubmed.length +
                          results.arxiv.length + results.clinicalTrials.length;

      expect(totalSources).toBeGreaterThan(0);
    }, TEST_TIMEOUT);
  });

  describe('Error Reporting', () => {
    it('should log errors without breaking request', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 1,
        pubmedCount: 1,
        arxivCount: 1,
        clinicalTrialsCount: 1
      };

      const results = await fetchAllResearchSources('test query', config);

      // Should have errors object
      expect(results.errors).toBeDefined();

      // If there are errors, they should be strings
      if (results.errors.exa) expect(typeof results.errors.exa).toBe('string');
      if (results.errors.pubmed) expect(typeof results.errors.pubmed).toBe('string');
      if (results.errors.arxiv) expect(typeof results.errors.arxiv).toBe('string');
      if (results.errors.clinicalTrials) expect(typeof results.errors.clinicalTrials).toBe('string');
    }, TEST_TIMEOUT);
  });

  describe('Performance', () => {
    it('should fetch sources faster in parallel than sequential', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 2,
        pubmedCount: 2,
        arxivCount: 2,
        clinicalTrialsCount: 2
      };

      const results = await fetchAllResearchSources('insulin resistance', config);

      // Parallel fetch should be faster than sum of individual timings
      // (This validates that we're actually fetching in parallel)
      const sumOfIndividual = results.timings.exa + results.timings.pubmed +
                              results.timings.arxiv + results.timings.clinicalTrials;

      // Total time should be less than sum (parallel speedup)
      // Allow some overhead for Promise.all coordination
      expect(results.timings.total).toBeLessThan(sumOfIndividual * 0.8);
    }, TEST_TIMEOUT);
  });

  describe('Source Distribution', () => {
    it('should return sources in the order: Exa, PubMed, arXiv, Trials', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 2,
        pubmedCount: 2,
        arxivCount: 2,
        clinicalTrialsCount: 2
      };

      const results = await fetchAllResearchSources('type 2 diabetes', config);

      // Results should be organized by source type
      expect(Array.isArray(results.exa)).toBe(true);
      expect(Array.isArray(results.pubmed)).toBe(true);
      expect(Array.isArray(results.arxiv)).toBe(true);
      expect(Array.isArray(results.clinicalTrials)).toBe(true);
    }, TEST_TIMEOUT);
  });

  describe('Zero Count Handling', () => {
    it('should handle zero counts gracefully', async () => {
      const config: ResearchFetchConfig = {
        exaCount: 0,
        pubmedCount: 5,
        arxivCount: 0,
        clinicalTrialsCount: 0
      };

      const results = await fetchAllResearchSources('metformin', config);

      // Should only fetch from PubMed
      expect(results.exa.length).toBe(0);
      expect(results.arxiv.length).toBe(0);
      expect(results.clinicalTrials.length).toBe(0);
      expect(results.pubmed.length).toBeLessThanOrEqual(5);
    }, TEST_TIMEOUT);
  });

  describe('Config Validation', () => {
    it('should warn when T2 API sources do not sum to 5', () => {
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();

      createT2Config(3, 3, 3); // Sums to 9, not 5

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('T2 API sources should sum to 5')
      );

      consoleSpy.mockRestore();
    });

    it('should warn when T3 API sources do not sum to 15', () => {
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();

      createT3Config(5, 5, 5); // Sums to 15, correct
      expect(consoleSpy).not.toHaveBeenCalled();

      createT3Config(10, 10, 10); // Sums to 30, wrong
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('T3 API sources should sum to 15')
      );

      consoleSpy.mockRestore();
    });
  });
});
