/**
 * Type definitions for Deep Research V2 Multi-Round System
 * iOS app expects these exact types and events
 */

import { ExaSearchResult } from '../tools/exa-search';
import { PubMedArticleResult } from '../tools/pubmed-search';
import { MedRxivResult } from '../tools/medrxiv-search';
import { ClinicalTrialResult } from '../tools/clinical-trials';

/**
 * Research Plan from Latents Planning Phase
 * iOS expects this structure in planning_complete event
 */
export interface ResearchPlan {
  estimatedRounds: number;
  strategy: string;
  focusAreas: string[];
}

/**
 * Research Reflection from Latents Reflection Phase
 * iOS expects this structure in reflection_complete event
 */
export interface ResearchReflection {
  evidenceQuality: 'low' | 'medium' | 'high';
  gapsIdentified: string[];
  shouldContinue: boolean;
  reasoning: string;
}

/**
 * Round results accumulator
 */
export interface RoundResult {
  roundNumber: number;
  sources: {
    exa: ExaSearchResult[];
    pubmed: PubMedArticleResult[];
    medrxiv: MedRxivResult[];
    clinicalTrials: ClinicalTrialResult[];
  };
  sourceCount: number;
  duration: number;
  reflection?: ResearchReflection;
}

/**
 * Source ranking metadata
 */
export interface RankingMetadata {
  averageRelevance: number;
  topSourceScore: number;
  rankingDuration: number;
}

/**
 * Source selection metadata
 */
export interface SelectionMetadata {
  selectedCount: number;
  deduplicatedCount: number;
  totalTokens: number;
  selectionStrategy: string;
  qualityMetrics: {
    averageRelevance: number;
    minRelevance: number;
    maxRelevance: number;
    highQualityCount: number;
  };
}

/**
 * Complete research results
 */
export interface DeepResearchResults {
  plan: ResearchPlan;
  rounds: RoundResult[];
  totalSources: number;
  totalDuration: number;
  allSources: {
    exa: ExaSearchResult[];
    pubmed: PubMedArticleResult[];
    medrxiv: MedRxivResult[];
    clinicalTrials: ClinicalTrialResult[];
  };
  rankingMetadata?: RankingMetadata; // Optional - only present if ranking is enabled
  selectionMetadata?: SelectionMetadata; // Optional - only present if selection is enabled
  selectedSources?: any[]; // Selected sources for synthesis (SelectedSource[])
}

/**
 * Deduplication tracking
 */
export interface SourceIdentifier {
  type: 'doi' | 'arxiv' | 'pubmed' | 'url';
  value: string;
}

/**
 * Query refinement result
 */
export interface RefinedQuery {
  original: string;
  refined: string;
  focusArea: string;
  reasoning: string;
}
