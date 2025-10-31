import EventSource from 'eventsource';
import axios from 'axios';
import {
  ResearchJourney,
  SSEEvent,
  QueryInput,
  RouterDecision,
  ResearchPlan,
  RoundResult,
  APICall,
  GapAnalysis,
  ResponseSynthesis,
  JourneySummary,
  SourceCollection
} from '../types/research-journey';

export interface ResearchOptions {
  question: string;
  userId: string;
  diabetesProfile?: {
    type: '1' | '2' | 'LADA' | 'gestational' | 'prediabetes';
    medications?: string[];
  };
  conversationHistory?: Array<{ role: string; content: string }>;
}

export type EventCallback = (event: SSEEvent) => void;

export class ResearchInterceptor {
  private firebaseUrl: string;
  private events: Array<{ timestamp: number; event: SSEEvent }> = [];
  private startTime: number = 0;

  constructor(firebaseUrl: string) {
    this.firebaseUrl = firebaseUrl;
  }

  /**
   * Execute research query and capture all SSE events
   */
  async executeResearch(
    options: ResearchOptions,
    onEvent?: EventCallback
  ): Promise<ResearchJourney> {
    this.startTime = Date.now();
    this.events = [];

    console.log(`\n🔗 Connecting to: ${this.firebaseUrl}\n`);

    return new Promise((resolve, reject) => {
      const journey = this.initializeJourney(options);
      let responseText = '';
      let currentRound: Partial<RoundResult> | null = null;
      const apiCalls: Map<string, Partial<APICall>> = new Map();

      // Make POST request to get streaming response
      axios({
        method: 'POST',
        url: this.firebaseUrl,
        data: {
          question: options.question,
          userId: options.userId,
          diabetesProfile: options.diabetesProfile,
          conversationHistory: options.conversationHistory
        },
        responseType: 'stream',
        headers: {
          'Content-Type': 'application/json'
        }
      })
        .then((response) => {
          const stream = response.data;
          let buffer = '';

          stream.on('data', (chunk: Buffer) => {
            buffer += chunk.toString();
            const lines = buffer.split('\n');
            buffer = lines.pop() || '';

            for (const line of lines) {
              if (line.startsWith('data: ')) {
                try {
                  const eventData = JSON.parse(line.substring(6));
                  this.captureEvent(eventData);
                  if (onEvent) {
                    onEvent(eventData);
                  }

                  // Process event and update journey
                  this.processEvent(
                    eventData,
                    journey,
                    currentRound,
                    apiCalls,
                    (text) => { responseText += text; }
                  );

                  // Special handling for round events
                  if (eventData.type === 'round_started') {
                    currentRound = {
                      roundNumber: eventData.round,
                      query: eventData.query,
                      estimatedSources: eventData.estimatedSources,
                      apiCalls: [],
                      sources: { exa: [], pubmed: [], medrxiv: [], clinicalTrials: [] },
                      sourceCount: 0,
                      duration: 0,
                      purpose: eventData.round === 1 ? 'initial' : 'gap_fill',
                      status: 'complete'
                    };
                  } else if (eventData.type === 'round_complete' && currentRound) {
                    currentRound.sourceCount = eventData.sourceCount;
                    currentRound.duration = eventData.duration;
                    currentRound.status = eventData.status;
                    if (eventData.sources) {
                      currentRound.sources = this.categorizeSource(eventData.sources);
                    }
                    // Convert API calls map to array
                    currentRound.apiCalls = Array.from(apiCalls.values()) as APICall[];
                    journey.rounds.push(currentRound as RoundResult);
                    currentRound = null;
                    apiCalls.clear();
                  }
                } catch (error) {
                  console.error('Error parsing SSE event:', error);
                }
              }
            }
          });

          stream.on('end', () => {
            // Finalize journey
            journey.synthesis.response = responseText;
            journey.summary = this.calculateSummary(journey);
            resolve(journey);
          });

          stream.on('error', (error: Error) => {
            reject(error);
          });
        })
        .catch((error) => {
          reject(error);
        });
    });
  }

  private initializeJourney(options: ResearchOptions): ResearchJourney {
    return {
      query: {
        original: options.question,
        timestamp: new Date().toISOString(),
        language: this.detectLanguage(options.question),
        length: options.question.length,
        userId: options.userId,
        diabetesProfile: options.diabetesProfile,
        conversationHistory: options.conversationHistory
      },
      routing: {
        tier: 1,
        reasoning: '',
        confidence: 0,
        model: '',
        tokens: { input: 0, output: 0 },
        cost: 0,
        latency: 0,
        timestamp: Date.now()
      },
      rounds: [],
      synthesis: {
        model: '',
        temperature: 0,
        systemPromptVersion: '',
        sourcesProvided: 0,
        responseLength: 0,
        streaming: true,
        tokens: { input: 0, output: 0 },
        cost: 0,
        latency: 0,
        response: '',
        finishReason: '',
        startTime: Date.now(),
        endTime: 0
      },
      summary: {
        totalTime: 0,
        totalCost: 0,
        totalTokens: { input: 0, output: 0 },
        qualityMetrics: {
          sourceQualityAvg: 0,
          gapCoverage: 0,
          journalIFAvg: 0
        },
        bottlenecks: [],
        recommendations: [],
        tier: '',
        rounds: 0,
        totalSources: 0
      }
    };
  }

  private processEvent(
    event: SSEEvent,
    journey: ResearchJourney,
    currentRound: Partial<RoundResult> | null,
    apiCalls: Map<string, Partial<APICall>>,
    onToken: (text: string) => void
  ): void {
    switch (event.type) {
      case 'tier_selected':
        journey.routing.tier = event.tier as 0 | 1 | 2 | 3;
        journey.routing.reasoning = event.reasoning;
        journey.routing.confidence = event.confidence;
        journey.routing.timestamp = Date.now();
        break;

      case 'planning_complete':
        journey.planning = {
          ...event.plan,
          model: 'gemini-2.0-flash-lite',
          tokens: { input: 0, output: 0 },
          cost: 0,
          latency: 0
        };
        break;

      case 'api_started':
        // Use the full query from the dedicated query field (not truncated preview in message)
        const fullQuery = event.query || '';

        apiCalls.set(event.api, {
          api: event.api,
          query: fullQuery,
          maxResults: event.count,
          found: 0,
          retrieved: 0,
          status: 'success',
          latency: 0,
          startTime: Date.now(),
          endTime: 0,
          results: []
        });
        break;

      case 'api_completed':
        const apiCall = apiCalls.get(event.api);
        if (apiCall) {
          apiCall.found = event.count;
          apiCall.retrieved = event.count;
          apiCall.latency = event.duration;
          apiCall.endTime = Date.now();
          apiCall.status = event.success ? 'success' : 'failure';
        }
        break;

      case 'reflection_complete':
        if (currentRound) {
          currentRound.gapAnalysis = {
            wellCovered: event.reflection.wellCovered || [],
            partiallyCovered: event.reflection.partiallyCovered || [],
            notCovered: event.reflection.gapsIdentified || [],
            gapScore: 0,
            decision: event.reflection.shouldContinue ? 'continue' : 'stop',
            reasoning: event.reflection.reasoning || '',
            model: 'gemini-2.0-flash-lite',
            tokens: { input: 0, output: 0 },
            cost: 0,
            latency: 0,
            evidenceQuality: event.reflection.evidenceQuality || 'moderate'
          };
        }
        break;

      case 'synthesis_started':
        journey.synthesis.startTime = Date.now();
        journey.synthesis.sourcesProvided = event.totalSources;
        break;

      case 'token':
        onToken(event.content);
        journey.synthesis.responseLength += event.content.length;
        break;

      case 'complete':
        journey.synthesis.endTime = Date.now();
        journey.synthesis.latency = journey.synthesis.endTime - journey.synthesis.startTime;
        if (event.metadata) {
          journey.synthesis.model = event.metadata.modelUsed || '';
          if (event.metadata.tokenUsage) {
            journey.synthesis.tokens = event.metadata.tokenUsage;
          }
        }
        break;
    }
  }

  private categorizeSource(sources: any[]): SourceCollection {
    const collection: SourceCollection = {
      exa: [],
      pubmed: [],
      medrxiv: [],
      clinicalTrials: []
    };

    for (const source of sources) {
      if (source.type === 'pubmed') {
        collection.pubmed.push(source);
      } else if (source.type === 'medrxiv') {
        collection.medrxiv.push(source);
      } else if (source.type === 'clinical_trial') {
        collection.clinicalTrials.push(source);
      } else {
        collection.exa.push(source);
      }
    }

    return collection;
  }

  private calculateSummary(journey: ResearchJourney): JourneySummary {
    const totalTime = Date.now() - this.startTime;
    const totalSources = journey.rounds.reduce((sum, round) => sum + round.sourceCount, 0);

    return {
      totalTime,
      totalCost: this.estimateCost(journey),
      totalTokens: this.sumTokens(journey),
      qualityMetrics: {
        sourceQualityAvg: 0,
        gapCoverage: 0,
        journalIFAvg: 0
      },
      bottlenecks: this.identifyBottlenecks(journey),
      recommendations: this.generateRecommendations(journey),
      tier: `T${journey.routing.tier}`,
      rounds: journey.rounds.length,
      totalSources
    };
  }

  private estimateCost(journey: ResearchJourney): number {
    // Simplified cost estimation based on tier
    if (journey.routing.tier === 1) return 0.001;
    if (journey.routing.tier === 2) return 0.003;
    if (journey.routing.tier === 3) return 0.05;
    return 0;
  }

  private sumTokens(journey: ResearchJourney): { input: number; output: number } {
    return {
      input: journey.synthesis.tokens.input,
      output: journey.synthesis.tokens.output
    };
  }

  private identifyBottlenecks(journey: ResearchJourney): Array<{ stage: string; latency: number; percentage: number }> {
    const totalTime = journey.summary.totalTime;
    const bottlenecks: Array<{ stage: string; latency: number; percentage: number }> = [];

    // Routing
    if (journey.routing.latency > 0) {
      bottlenecks.push({
        stage: 'Routing',
        latency: journey.routing.latency,
        percentage: (journey.routing.latency / totalTime) * 100
      });
    }

    // Rounds
    journey.rounds.forEach((round, idx) => {
      bottlenecks.push({
        stage: `Round ${idx + 1}`,
        latency: round.duration,
        percentage: (round.duration / totalTime) * 100
      });
    });

    // Synthesis
    bottlenecks.push({
      stage: 'Synthesis',
      latency: journey.synthesis.latency,
      percentage: (journey.synthesis.latency / totalTime) * 100
    });

    return bottlenecks.sort((a, b) => b.latency - a.latency);
  }

  private generateRecommendations(journey: ResearchJourney): string[] {
    const recommendations: string[] = [];

    if (journey.synthesis.latency > 20000) {
      recommendations.push('Consider using a faster model for synthesis to reduce latency');
    }

    if (journey.rounds.length > 3) {
      recommendations.push('High number of rounds - consider refining initial query or planning strategy');
    }

    const avgApiLatency = journey.rounds.flatMap(r => r.apiCalls).reduce((sum, api) => sum + api.latency, 0) /
                          journey.rounds.flatMap(r => r.apiCalls).length;
    if (avgApiLatency > 2000) {
      recommendations.push('API calls are slow - consider caching or optimizing queries');
    }

    return recommendations;
  }

  private detectLanguage(text: string): string {
    // Simple Turkish detection
    const turkishChars = /[çÇğĞıİöÖşŞüÜ]/;
    return turkishChars.test(text) ? 'Turkish' : 'English';
  }

  private captureEvent(event: SSEEvent): void {
    this.events.push({
      timestamp: Date.now() - this.startTime,
      event
    });
  }

  getEvents(): Array<{ timestamp: number; event: SSEEvent }> {
    return this.events;
  }
}
