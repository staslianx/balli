/**
 * Unit tests for Intelligent Source Selector
 *
 * Tests top-P style selection with semantic deduplication and token management
 */

import { describe, it, expect } from '@jest/globals';
import {
  selectSourcesForSynthesis,
  formatSelectedSourcesForSynthesis,
  SelectedSource
} from '../source-selector';
import { RankedSource } from '../source-ranker';

describe('Intelligent Source Selector', () => {
  describe('selectSourcesForSynthesis', () => {
    it('should select top 30 sources by default', async () => {
      const rankedSources: RankedSource[] = Array(50).fill(null).map((_, i) => ({
        source: { pmid: `pmid${i}`, title: `Article ${i}`, abstract: `Abstract ${i}` },
        relevanceScore: 90 - i, // Descending scores
        reasoning: '',
        sourceType: 'pubmed' as const
      }));

      const result = await selectSourcesForSynthesis(rankedSources);

      expect(result.selectedCount).toBeLessThanOrEqual(30);
      expect(result.selectedSources[0].relevanceScore).toBeGreaterThanOrEqual(
        result.selectedSources[result.selectedSources.length - 1].relevanceScore
      );
    });

    it('should extend to 35 sources when many high-quality sources available', async () => {
      const rankedSources: RankedSource[] = Array(50).fill(null).map((_, i) => ({
        source: { pmid: `pmid${i}`, title: `Article ${i}`, abstract: `Abstract ${i}` },
        relevanceScore: 85 - i * 0.5, // Many high-quality sources (>70)
        reasoning: '',
        sourceType: 'pubmed' as const
      }));

      const result = await selectSourcesForSynthesis(rankedSources, {
        baseLimit: 30,
        extendedLimit: 35,
        highQualityThreshold: 70
      });

      // Should extend beyond 30 because many sources > 70
      expect(result.selectedCount).toBeGreaterThan(30);
      expect(result.selectedCount).toBeLessThanOrEqual(35);
      expect(result.selectionStrategy).toContain('Extended selection');
    });

    it('should filter sources below minimum relevance', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1', title: 'High quality', abstract: 'Abstract 1' },
          relevanceScore: 85,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: { pmid: '2', title: 'Medium quality', abstract: 'Abstract 2' },
          relevanceScore: 60,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: { pmid: '3', title: 'Low quality', abstract: 'Abstract 3' },
          relevanceScore: 30,
          reasoning: '',
          sourceType: 'pubmed'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources, {
        minRelevanceScore: 50
      });

      expect(result.selectedCount).toBe(2);
      expect(result.selectedSources.every(s => s.relevanceScore >= 50)).toBe(true);
    });

    it('should respect token budget', async () => {
      const rankedSources: RankedSource[] = Array(50).fill(null).map((_, i) => ({
        source: {
          pmid: `pmid${i}`,
          title: `Article ${i}`,
          abstract: 'A'.repeat(2000) // ~500 tokens per source
        },
        relevanceScore: 90 - i,
        reasoning: '',
        sourceType: 'pubmed' as const
      }));

      const result = await selectSourcesForSynthesis(rankedSources, {
        tokenBudget: 5000 // Should fit ~10 sources
      });

      expect(result.totalTokens).toBeLessThanOrEqual(5000);
      expect(result.selectedCount).toBeLessThan(20); // Should stop early due to budget
    });

    it('should remove semantically similar sources', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: {
            pmid: '1',
            title: 'Metformin side effects in diabetes',
            abstract: 'Study on gastrointestinal side effects of metformin in type 2 diabetes patients'
          },
          relevanceScore: 90,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: {
            pmid: '2',
            title: 'Metformin adverse effects in diabetes',
            abstract: 'Research on gastrointestinal adverse effects of metformin in type 2 diabetes patients'
          },
          relevanceScore: 88,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: {
            pmid: '3',
            title: 'Insulin resistance mechanisms',
            abstract: 'Different topic about insulin resistance pathways'
          },
          relevanceScore: 85,
          reasoning: '',
          sourceType: 'pubmed'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources, {
        enableSemanticDedup: true,
        semanticSimilarityThreshold: 0.7 // Lower threshold to catch similar sources
      });

      // Should remove one of the two similar sources
      expect(result.deduplicatedCount).toBeGreaterThan(0);
      expect(result.selectedCount).toBeLessThan(rankedSources.length);
    });

    it('should include all sources when below base limit', async () => {
      const rankedSources: RankedSource[] = Array(15).fill(null).map((_, i) => ({
        source: { pmid: `pmid${i}`, title: `Article ${i}`, abstract: `Abstract ${i}` },
        relevanceScore: 90 - i * 2,
        reasoning: '',
        sourceType: 'pubmed' as const
      }));

      const result = await selectSourcesForSynthesis(rankedSources, {
        baseLimit: 30
      });

      expect(result.selectedCount).toBe(15);
      expect(result.selectionStrategy).toContain('all sources');
    });

    it('should handle empty input', async () => {
      const rankedSources: RankedSource[] = [];

      const result = await selectSourcesForSynthesis(rankedSources);

      expect(result.selectedCount).toBe(0);
      expect(result.selectedSources).toHaveLength(0);
      expect(result.totalTokens).toBe(0);
    });

    it('should handle mixed source types', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1', title: 'PubMed article', abstract: 'Abstract 1' },
          relevanceScore: 90,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: { id: 'arxiv1', title: 'arXiv paper', summary: 'Summary 1' },
          relevanceScore: 85,
          reasoning: '',
          sourceType: 'arxiv'
        },
        {
          source: { nctId: 'NCT1', title: 'Clinical trial', description: 'Description 1' },
          relevanceScore: 80,
          reasoning: '',
          sourceType: 'clinicaltrials'
        },
        {
          source: { id: 'exa1', url: 'https://example.com', title: 'Web source', text: 'Text 1' },
          relevanceScore: 75,
          reasoning: '',
          sourceType: 'exa'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources);

      expect(result.selectedCount).toBe(4);
      expect(result.selectedSources.some(s => s.sourceType === 'pubmed')).toBe(true);
      expect(result.selectedSources.some(s => s.sourceType === 'arxiv')).toBe(true);
      expect(result.selectedSources.some(s => s.sourceType === 'clinicaltrials')).toBe(true);
      expect(result.selectedSources.some(s => s.sourceType === 'exa')).toBe(true);
    });

    it('should calculate quality metrics correctly', async () => {
      const rankedSources: RankedSource[] = [
        { source: { pmid: '1' }, relevanceScore: 95, reasoning: '', sourceType: 'pubmed' as const },
        { source: { pmid: '2' }, relevanceScore: 85, reasoning: '', sourceType: 'pubmed' as const },
        { source: { pmid: '3' }, relevanceScore: 75, reasoning: '', sourceType: 'pubmed' as const },
        { source: { pmid: '4' }, relevanceScore: 65, reasoning: '', sourceType: 'pubmed' as const }
      ];

      const result = await selectSourcesForSynthesis(rankedSources);

      expect(result.qualityMetrics.minRelevance).toBe(65);
      expect(result.qualityMetrics.maxRelevance).toBe(95);
      expect(result.qualityMetrics.averageRelevance).toBe(80);
      expect(result.qualityMetrics.highQualityCount).toBe(2); // 95 and 85 are > 80
    });

    it('should disable semantic dedup when configured', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1', title: 'Similar title', abstract: 'Similar abstract' },
          relevanceScore: 90,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: { pmid: '2', title: 'Similar title', abstract: 'Similar abstract' },
          relevanceScore: 88,
          reasoning: '',
          sourceType: 'pubmed'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources, {
        enableSemanticDedup: false
      });

      // Should keep both sources even if similar
      expect(result.selectedCount).toBe(2);
      expect(result.deduplicatedCount).toBe(0);
    });
  });

  describe('formatSelectedSourcesForSynthesis', () => {
    it('should format sources by type', () => {
      const selectedSources: SelectedSource[] = [
        {
          source: { pmid: '1' },
          relevanceScore: 90,
          sourceType: 'pubmed',
          citation: 'Smith et al. (2024). Test article. JAMA.',
          summary: 'Test abstract',
          credibilityBadge: 'highly_credible',
          estimatedTokens: 100
        },
        {
          source: { id: 'arxiv1' },
          relevanceScore: 85,
          sourceType: 'arxiv',
          citation: 'Jones et al. (2024). Test paper. arXiv preprint.',
          summary: 'Test summary',
          credibilityBadge: 'credible',
          estimatedTokens: 100
        }
      ];

      const formatted = formatSelectedSourcesForSynthesis(selectedSources);

      expect(formatted).toContain('Peer-Reviewed Articles (PubMed)');
      expect(formatted).toContain('Recent Research (arXiv)');
      expect(formatted).toContain('Smith et al.');
      expect(formatted).toContain('Jones et al.');
      expect(formatted).toContain('Relevance: 90/100');
      expect(formatted).toContain('Relevance: 85/100');
    });

    it('should handle empty list', () => {
      const selectedSources: SelectedSource[] = [];

      const formatted = formatSelectedSourcesForSynthesis(selectedSources);

      expect(formatted).toContain('0 sources');
    });

    it('should include credibility badges', () => {
      const selectedSources: SelectedSource[] = [
        {
          source: { pmid: '1' },
          relevanceScore: 90,
          sourceType: 'pubmed',
          citation: 'Test citation',
          summary: 'Test summary',
          credibilityBadge: 'highly_credible',
          estimatedTokens: 100
        }
      ];

      const formatted = formatSelectedSourcesForSynthesis(selectedSources);

      expect(formatted).toContain('Credibility: highly_credible');
    });

    it('should truncate long summaries', () => {
      const longSummary = 'A'.repeat(1000);

      const selectedSources: SelectedSource[] = [
        {
          source: { pmid: '1' },
          relevanceScore: 90,
          sourceType: 'pubmed',
          citation: 'Test citation',
          summary: longSummary,
          credibilityBadge: 'highly_credible',
          estimatedTokens: 100
        }
      ];

      const formatted = formatSelectedSourcesForSynthesis(selectedSources);

      // Should truncate to 500 chars for PubMed
      expect(formatted).toContain('...');
      expect(formatted.length).toBeLessThan(longSummary.length);
    });

    it('should number sources sequentially across types', () => {
      const selectedSources: SelectedSource[] = [
        {
          source: { pmid: '1' },
          relevanceScore: 90,
          sourceType: 'pubmed',
          citation: 'PubMed 1',
          summary: 'Summary 1',
          credibilityBadge: 'highly_credible',
          estimatedTokens: 100
        },
        {
          source: { pmid: '2' },
          relevanceScore: 88,
          sourceType: 'pubmed',
          citation: 'PubMed 2',
          summary: 'Summary 2',
          credibilityBadge: 'highly_credible',
          estimatedTokens: 100
        },
        {
          source: { id: 'arxiv1' },
          relevanceScore: 85,
          sourceType: 'arxiv',
          citation: 'arXiv 1',
          summary: 'Summary 3',
          credibilityBadge: 'credible',
          estimatedTokens: 100
        }
      ];

      const formatted = formatSelectedSourcesForSynthesis(selectedSources);

      expect(formatted).toContain('[1]'); // First PubMed
      expect(formatted).toContain('[2]'); // Second PubMed
      expect(formatted).toContain('[3]'); // arXiv (continues numbering)
    });
  });

  describe('Edge cases', () => {
    it('should handle sources with missing metadata', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1' }, // Missing title and abstract
          relevanceScore: 90,
          reasoning: '',
          sourceType: 'pubmed'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources);

      expect(result.selectedCount).toBe(1);
      expect(result.selectedSources[0].citation).toBeDefined();
      expect(result.selectedSources[0].summary).toBeDefined();
    });

    it('should handle very high similarity threshold', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1', title: 'Test', abstract: 'Test abstract' },
          relevanceScore: 90,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: { pmid: '2', title: 'Different', abstract: 'Different abstract' },
          relevanceScore: 85,
          reasoning: '',
          sourceType: 'pubmed'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources, {
        semanticSimilarityThreshold: 0.99 // Very high threshold
      });

      // Should keep both sources (not similar enough)
      expect(result.selectedCount).toBe(2);
      expect(result.deduplicatedCount).toBe(0);
    });

    it('should handle very low similarity threshold', async () => {
      const rankedSources: RankedSource[] = [
        {
          source: { pmid: '1', title: 'Test one', abstract: 'Abstract one' },
          relevanceScore: 90,
          reasoning: '',
          sourceType: 'pubmed'
        },
        {
          source: { pmid: '2', title: 'Test two', abstract: 'Abstract two' },
          relevanceScore: 85,
          reasoning: '',
          sourceType: 'pubmed'
        }
      ];

      const result = await selectSourcesForSynthesis(rankedSources, {
        semanticSimilarityThreshold: 0.1 // Very low threshold
      });

      // May deduplicate if any words overlap
      expect(result.selectedCount).toBeGreaterThan(0);
    });
  });
});
