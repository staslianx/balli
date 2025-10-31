/**
 * Complete type definitions for Research Journey
 * Based on production Firebase Functions SSE event structure
 */

export interface ResearchJourney {
  query: QueryInput;
  routing: RouterDecision;
  planning?: ResearchPlan;
  enrichment?: QueryEnrichment;
  rounds: RoundResult[];
  ranking?: SourceRanking;
  synthesis: ResponseSynthesis;
  citationVerification?: CitationVerification;
  summary: JourneySummary;
}

export interface QueryInput {
  original: string;
  enriched?: string;
  timestamp: string;
  language: string;
  length: number;
  userId: string;
  diabetesProfile?: {
    type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
    medications?: string[];
  };
  conversationHistory?: Array<{ role: string; content: string }>;
}

export interface RouterDecision {
  tier: 0 | 1 | 2 | 3;
  reasoning: string;
  confidence: number;
  explicitDeepRequest?: boolean;
  isRecallRequest?: boolean;
  searchTerms?: string;
  model: string;
  tokens: { input: number; output: number };
  cost: number;
  latency: number;
  timestamp: number;
}

export interface QueryEnrichment {
  original: string;
  enriched: string;
  contextUsed: string[];
  reasoning: string;
  model: string;
  tokens: { input: number; output: number };
  cost: number;
  latency: number;
}

export interface ResearchPlan {
  estimatedRounds: number;
  strategy: string;
  focusAreas: string[];
  reasoning: string;
  model: string;
  tokens: { input: number; output: number };
  cost: number;
  latency: number;
}

export interface RoundResult {
  roundNumber: number;
  purpose: 'initial' | 'gap_fill';
  query: string;
  estimatedSources: number;
  apiCalls: APICall[];
  sources: SourceCollection;
  sourceCount: number;
  duration: number;
  gapAnalysis?: GapAnalysis;
  status: 'complete' | 'partial' | 'failed';
}

export interface APICall {
  api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa';
  query: string;
  filters?: Record<string, any>;
  maxResults: number;
  found: number;
  retrieved: number;
  status: 'success' | 'failure';
  error?: string;
  latency: number;
  startTime: number;
  endTime: number;
  results: SourceItem[];
}

export interface SourceCollection {
  exa: any[];
  pubmed: any[];
  medrxiv: any[];
  clinicalTrials: any[];
}

export interface SourceItem {
  id: string;
  title: string;
  authors?: string;
  journal?: string;
  year?: number;
  citations?: number;
  impactFactor?: number;
  relevanceScore?: number;
  qualityRating?: number;
  url: string;
  snippet?: string;
  type: 'pubmed' | 'medrxiv' | 'clinical_trial' | 'medical_source';
}

export interface GapAnalysis {
  wellCovered: string[];
  partiallyCovered: string[];
  notCovered: string[];
  gapScore: number;
  decision: 'continue' | 'stop';
  reasoning: string;
  model: string;
  tokens: { input: number; output: number };
  cost: number;
  latency: number;
  evidenceQuality: 'insufficient' | 'limited' | 'moderate' | 'high';
}

export interface SourceRanking {
  criteria: Record<string, number>; // weights
  totalEvaluated: number;
  selected: number;
  excluded: Array<{
    reason: string;
    count: number;
  }>;
  topSources: Array<{
    rank: number;
    source: SourceItem;
    overallScore: number;
    breakdown: Record<string, number>;
  }>;
  model: string;
  tokens: { input: number; output: number };
  cost: number;
  latency: number;
  averageRelevance: number;
}

export interface ResponseSynthesis {
  model: string;
  temperature: number;
  systemPromptVersion: string;
  sourcesProvided: number;
  responseLength: number;
  streaming: boolean;
  tokens: { input: number; output: number };
  cost: number;
  latency: number;
  response: string;
  thinkingSummary?: string;
  finishReason: string;
  startTime: number;
  endTime: number;
}

export interface CitationVerification {
  totalSentences: number;
  totalCitations: number;
  checks: Array<{
    sentence: string;
    citations: Array<{
      index: number;
      sourceTitle: string;
      sourceText: string;
      similarity: number;
      accurate: boolean;
      issue?: string;
    }>;
  }>;
  overallScore: number;
  summary: {
    accurate: number;
    nuanceLost: number;
    inaccurate: number;
  };
  cost: number;
  latency: number;
}

export interface JourneySummary {
  totalTime: number;
  totalCost: number;
  totalTokens: { input: number; output: number };
  qualityMetrics: {
    sourceQualityAvg: number;
    gapCoverage: number;
    citationAuthenticity?: number;
    journalIFAvg: number;
  };
  bottlenecks: Array<{
    stage: string;
    latency: number;
    percentage: number;
  }>;
  recommendations: string[];
  tier: string;
  rounds: number;
  totalSources: number;
}

/**
 * SSE Event Types (matching production Firebase Functions)
 */
export type SSEEvent =
  | { type: 'routing'; message: string }
  | { type: 'tier_selected'; tier: number; reasoning: string; confidence: number }
  | { type: 'searching_memory'; message: string }
  | { type: 'searching'; source: 'exa' | 'pubmed' | 'clinicaltrials' }
  | { type: 'search_complete'; count: number; source: string }
  | { type: 'sources_ready'; sources: any[] }
  | { type: 'extracting_keywords' }
  | { type: 'keywords_extracted'; keywords: string }
  | { type: 'research_stage'; stage: 'starting' | 'scanning' | 'fetching' | 'synthesizing'; message: string }
  | { type: 'api_started'; api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa'; count: number; message: string; query?: string }
  | { type: 'api_completed'; api: 'pubmed' | 'medrxiv' | 'clinicaltrials' | 'exa'; count: number; duration: number; message: string; success: boolean }
  | { type: 'research_progress'; fetched: number; total: number; message: string }
  | { type: 'planning_started'; message: string; sequence: number }
  | { type: 'planning_complete'; plan: any; sequence: number }
  | { type: 'round_started'; round: number; query: string; estimatedSources: number; sequence: number }
  | { type: 'round_complete'; round: number; sourceCount: number; duration: number; sources: any[]; status: string; sequence: number }
  | { type: 'source_found'; title: string; sourceType: string }
  | { type: 'reflection_started'; round: number; sequence: number }
  | { type: 'reflection_complete'; round: number; reflection: any; sequence: number }
  | { type: 'source_selection_started'; message: string; sequence: number }
  | { type: 'synthesis_preparation'; message: string; sequence: number }
  | { type: 'synthesis_started'; totalRounds: number; totalSources: number; sequence: number }
  | { type: 'generating'; message: string }
  | { type: 'token'; content: string }
  | { type: 'complete'; sources: any[]; metadata: any; researchSummary?: any; processingTier?: string; thinkingSummary?: string }
  | { type: 'error'; message: string };

/**
 * Configuration file structure
 */
export interface Config {
  apiKeys?: {
    firebase?: string;
    gemini?: string;
  };
  firebaseFunctions: {
    emulator: boolean;
    emulatorUrl?: string;
    productionUrl?: string;
    projectId: string;
    region: string;
  };
  display: {
    colorScheme: 'default' | 'light' | 'dark';
    verbosity: 'minimal' | 'normal' | 'verbose';
    showTimestamps: boolean;
    showCosts: boolean;
    showTokens: boolean;
  };
  export: {
    autoSave: boolean;
    outputDir: string;
    formats: Array<'json' | 'markdown' | 'html'>;
  };
}
