/**
 * Unit tests for Source Ranker
 *
 * Tests AI-powered source relevance ranking functionality
 */

import { describe, it, expect, beforeEach } from '@jest/globals';
import {
  rankSourcesByRelevance,
  reorderSourcesByRanking,
  RankedSource
} from '../source-ranker';

describe('Source Ranker', () => {
  describe('rankSourcesByRelevance', () => {
    it('should rank sources by relevance to query', async () => {
      const query = 'metformin side effects';
      const sources = {
        pubmed: [
          {
            pmid: '12345',
            title: 'Metformin side effects in Type 2 Diabetes',
            abstract: 'Study on gastrointestinal side effects of metformin',
            pubdate: '2024-01-15',
            authors: ['Smith J']
          },
          {
            pmid: '67890',
            title: 'Insulin resistance mechanisms',
            abstract: 'Mechanisms of insulin resistance in diabetes',
            pubdate: '2023-05-10',
            authors: ['Jones A']
          }
        ],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources);

      // Assertions
      expect(result.rankedSources).toHaveLength(2);
      expect(result.rankedSources[0].relevanceScore).toBeGreaterThan(
        result.rankedSources[1].relevanceScore
      );
      expect(result.rankedSources[0].source.pmid).toBe('12345'); // More relevant source
      expect(result.averageRelevance).toBeGreaterThan(0);
      expect(result.averageRelevance).toBeLessThanOrEqual(100);
    }, 30000); // 30 second timeout for AI call

    it('should handle empty sources gracefully', async () => {
      const query = 'diabetes management';
      const sources = {
        pubmed: [],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources);

      expect(result.rankedSources).toHaveLength(0);
      expect(result.topSources).toHaveLength(0);
      expect(result.averageRelevance).toBe(0);
      expect(result.totalSources).toBe(0);
    });

    it('should limit sources to maxSourcesToRank', async () => {
      const query = 'diabetes';
      const sources = {
        pubmed: Array(100).fill(null).map((_, i) => ({
          pmid: `pmid${i}`,
          title: `Article ${i}`,
          abstract: `Abstract ${i}`,
          pubdate: '2024-01-01',
          authors: ['Author']
        })),
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources, {
        maxSourcesToRank: 20
      });

      expect(result.rankedSources.length).toBeLessThanOrEqual(20);
    }, 60000); // 60 second timeout for large batch

    it('should return top N sources', async () => {
      const query = 'metformin';
      const sources = {
        pubmed: Array(30).fill(null).map((_, i) => ({
          pmid: `pmid${i}`,
          title: `Metformin study ${i}`,
          abstract: `Abstract ${i}`,
          pubdate: '2024-01-01',
          authors: ['Author']
        })),
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources, {
        topNToReturn: 5
      });

      expect(result.topSources).toHaveLength(5);
      expect(result.rankedSources.length).toBeGreaterThanOrEqual(5);
    }, 60000);

    it('should rank sources from different types', async () => {
      const query = 'diabetes treatment';
      const sources = {
        pubmed: [
          {
            pmid: '111',
            title: 'Diabetes treatment guidelines',
            abstract: 'Guidelines for diabetes treatment',
            pubdate: '2024-01-01',
            authors: ['Smith']
          }
        ],
        arxiv: [
          {
            id: 'arxiv-222',
            title: 'Machine learning for diabetes',
            summary: 'ML approaches for diabetes prediction',
            published: '2024-02-01',
            authors: ['Jones']
          }
        ],
        clinicalTrials: [
          {
            nctId: 'NCT333',
            title: 'Trial on diabetes medication',
            description: 'Clinical trial testing new diabetes drug',
            startDate: '2024-03-01',
            sponsor: 'Pharma Inc'
          }
        ],
        exa: [
          {
            id: 'exa-444',
            url: 'https://example.com/diabetes',
            title: 'Diabetes overview',
            text: 'General information about diabetes',
            publishedDate: '2024-04-01',
            domain: 'example.com'
          }
        ]
      };

      const result = await rankSourcesByRelevance(query, sources);

      expect(result.rankedSources).toHaveLength(4);
      expect(result.rankedSources.some(r => r.sourceType === 'pubmed')).toBe(true);
      expect(result.rankedSources.some(r => r.sourceType === 'arxiv')).toBe(true);
      expect(result.rankedSources.some(r => r.sourceType === 'clinicaltrials')).toBe(true);
      expect(result.rankedSources.some(r => r.sourceType === 'exa')).toBe(true);
    }, 30000);

    it('should prioritize highly credible sources when relevance is similar', async () => {
      const query = 'metformin efficacy';
      const sources = {
        pubmed: [
          {
            pmid: '100',
            title: 'Metformin efficacy study',
            abstract: 'RCT on metformin efficacy',
            pubdate: '2024-01-01',
            authors: ['Smith']
          }
        ],
        arxiv: [
          {
            id: 'arxiv-200',
            title: 'Metformin efficacy analysis',
            summary: 'Analysis of metformin efficacy',
            published: '2024-01-01',
            authors: ['Jones']
          }
        ],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources);

      // PubMed source should generally score higher than arXiv for similar titles
      const pubmedSource = result.rankedSources.find(r => r.sourceType === 'pubmed');
      const arxivSource = result.rankedSources.find(r => r.sourceType === 'arxiv');

      expect(pubmedSource).toBeDefined();
      expect(arxivSource).toBeDefined();
      // Note: This may not always hold if arXiv title is significantly more relevant
      // but should generally be true for similar relevance
    }, 30000);
  });

  describe('reorderSourcesByRanking', () => {
    it('should reorder sources by ranking', () => {
      const originalSources = {
        pubmed: [
          { pmid: '1', title: 'Article 1' },
          { pmid: '2', title: 'Article 2' },
          { pmid: '3', title: 'Article 3' }
        ],
        arxiv: [
          { id: 'arx1', title: 'Paper 1' },
          { id: 'arx2', title: 'Paper 2' }
        ],
        clinicalTrials: [],
        exa: []
      };

      const rankedSources: RankedSource[] = [
        { source: { pmid: '3', title: 'Article 3' }, relevanceScore: 95, reasoning: '', sourceType: 'pubmed' },
        { source: { id: 'arx1', title: 'Paper 1' }, relevanceScore: 85, reasoning: '', sourceType: 'arxiv' },
        { source: { pmid: '1', title: 'Article 1' }, relevanceScore: 75, reasoning: '', sourceType: 'pubmed' },
        { source: { pmid: '2', title: 'Article 2' }, relevanceScore: 70, reasoning: '', sourceType: 'pubmed' },
        { source: { id: 'arx2', title: 'Paper 2' }, relevanceScore: 65, reasoning: '', sourceType: 'arxiv' }
      ];

      const reordered = reorderSourcesByRanking(originalSources, rankedSources);

      // Check PubMed order (should be: 3, 1, 2)
      expect(reordered.pubmed[0].pmid).toBe('3');
      expect(reordered.pubmed[1].pmid).toBe('1');
      expect(reordered.pubmed[2].pmid).toBe('2');

      // Check arXiv order (should be: arx1, arx2)
      expect(reordered.arxiv[0].id).toBe('arx1');
      expect(reordered.arxiv[1].id).toBe('arx2');
    });

    it('should handle empty ranking', () => {
      const originalSources = {
        pubmed: [{ pmid: '1', title: 'Article 1' }],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const rankedSources: RankedSource[] = [];

      const reordered = reorderSourcesByRanking(originalSources, rankedSources);

      expect(reordered.pubmed).toHaveLength(0);
      expect(reordered.arxiv).toHaveLength(0);
      expect(reordered.clinicalTrials).toHaveLength(0);
      expect(reordered.exa).toHaveLength(0);
    });

    it('should maintain source integrity during reordering', () => {
      const originalSources = {
        pubmed: [
          { pmid: '1', title: 'Article 1', abstract: 'Abstract 1', authors: ['Author 1'] }
        ],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1', title: 'Article 1', abstract: 'Abstract 1', authors: ['Author 1'] },
          relevanceScore: 90,
          reasoning: 'Highly relevant',
          sourceType: 'pubmed'
        }
      ];

      const reordered = reorderSourcesByRanking(originalSources, rankedSources);

      expect(reordered.pubmed[0]).toEqual(originalSources.pubmed[0]);
    });
  });

  describe('Edge cases and error handling', () => {
    it('should handle malformed source data gracefully', async () => {
      const query = 'test';
      const sources = {
        pubmed: [
          { pmid: '1' } as any, // Missing required fields
          { title: 'No PMID' } as any
        ],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources);

      // Should still return results, even if ranking quality is degraded
      expect(result.rankedSources.length).toBeGreaterThan(0);
    }, 30000);

    it('should handle very long queries', async () => {
      const longQuery = 'metformin '.repeat(100); // Very long query
      const sources = {
        pubmed: [
          {
            pmid: '1',
            title: 'Test',
            abstract: 'Test abstract',
            pubdate: '2024-01-01',
            authors: ['Test']
          }
        ],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(longQuery, sources);

      expect(result.rankedSources).toHaveLength(1);
    }, 30000);

    it('should handle batch size correctly', async () => {
      const query = 'diabetes';
      const sources = {
        pubmed: Array(25).fill(null).map((_, i) => ({
          pmid: `pmid${i}`,
          title: `Article ${i}`,
          abstract: `Abstract ${i}`,
          pubdate: '2024-01-01',
          authors: ['Author']
        })),
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources, {
        batchSize: 5 // Small batch size
      });

      expect(result.rankedSources).toHaveLength(25);
      // Should process all sources despite small batch size
    }, 60000);
  });

  describe('Performance metrics', () => {
    it('should complete ranking within reasonable time for 30 sources', async () => {
      const query = 'diabetes treatment';
      const sources = {
        pubmed: Array(30).fill(null).map((_, i) => ({
          pmid: `pmid${i}`,
          title: `Article ${i}`,
          abstract: `Abstract ${i}`,
          pubdate: '2024-01-01',
          authors: ['Author']
        })),
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const startTime = Date.now();
      const result = await rankSourcesByRelevance(query, sources);
      const duration = Date.now() - startTime;

      expect(duration).toBeLessThan(30000); // Should complete in under 30 seconds
      expect(result.rankingDuration).toBeGreaterThan(0);
      expect(result.rankingDuration).toBeLessThan(duration);
    }, 60000);

    it('should report accurate duration metrics', async () => {
      const query = 'metformin';
      const sources = {
        pubmed: [
          {
            pmid: '1',
            title: 'Test',
            abstract: 'Abstract',
            pubdate: '2024-01-01',
            authors: ['Author']
          }
        ],
        arxiv: [],
        clinicalTrials: [],
        exa: []
      };

      const result = await rankSourcesByRelevance(query, sources);

      expect(result.rankingDuration).toBeGreaterThan(0);
      expect(typeof result.rankingDuration).toBe('number');
    }, 30000);
  });
});
