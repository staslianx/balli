import boxen from 'boxen';
import Table from 'cli-table3';
import figlet from 'figlet';
import {
  ResearchJourney,
  RouterDecision,
  ResearchPlan,
  RoundResult,
  ResponseSynthesis,
  JourneySummary
} from '../types/research-journey';
import {
  colors,
  icons,
  box,
  formatDuration,
  formatCost,
  formatTokens,
  formatPercentage,
  createProgressBar,
  createLine,
  truncate
} from '../utils/colors';

export class StageVisualizer {
  private verbose: boolean;

  constructor(verbose: boolean = false) {
    this.verbose = verbose;
  }

  /**
   * Display header
   */
  displayHeader(): void {
    // Create figlet ASCII art for "balli" with "DOS Rebel" font
    const balliArt = figlet.textSync('balli', {
      font: 'DOS Rebel',
      horizontalLayout: 'default',
      verticalLayout: 'default'
    });

    // Apply purple color to the ASCII art
    const purpleBalliArt = colors.metric(balliArt);

    // Display the figlet header
    console.log('\n' + purpleBalliArt);

    // Display the subtitle
    const header = boxen(
      colors.highlight('🔬 Deep Research Observatory\n') +
      colors.meta('Balli Research Pipeline X-Ray Tool'),
      {
        padding: 1,
        margin: 1,
        borderStyle: 'double',
        borderColor: 'cyan'
      }
    );
    console.log(header);
  }

  /**
   * Stage 1: Query Input & Analysis
   */
  displayQueryInput(journey: ResearchJourney): void {
    console.log('\n' + colors.user(box.topLeft + createLine(60) + ' 📥 QUERY INPUT ' + createLine(10) + box.topRight));
    console.log(colors.user(box.vertical) + ` Query: "${truncate(journey.query.original, 55)}"`);
    console.log(colors.user(box.vertical) + ` Language: ${journey.query.language}`);
    console.log(colors.user(box.vertical) + ` Length: ${journey.query.length} chars`);
    console.log(colors.user(box.vertical) + ` Timestamp: ${new Date(journey.query.timestamp).toLocaleString()}`);
    console.log(colors.user(box.bottomLeft + createLine(80) + box.bottomRight));
  }

  /**
   * Stage 2: Router Decision
   */
  displayRouterDecision(routing: RouterDecision): void {
    console.log('\n' + colors.system(box.topLeft + createLine(60) + ' 🎯 ROUTER DECISION ' + createLine(8) + box.topRight));
    console.log(colors.system(box.vertical) + ` Model: gemini-2.0-flash-lite`);
    console.log(colors.system(box.vertical));

    // Tier Analysis
    console.log(colors.system(box.vertical) + ` Tier Analysis:`);
    const tierEmoji = routing.tier === 0 ? '📚' : routing.tier === 1 ? '🤖' : routing.tier === 2 ? '🔍' : '🔬';
    const tierName = routing.tier === 0 ? 'Recall' : routing.tier === 1 ? 'Model' : routing.tier === 2 ? 'Hybrid' : 'Deep Research';
    const tierColor = routing.tier === 0 ? colors.tier0 : routing.tier === 1 ? colors.tier1 : routing.tier === 2 ? colors.tier2 : colors.tier3;

    console.log(colors.system(box.vertical) + `   Tier 0 (Recall): ${routing.tier === 0 ? colors.success(icons.check) : colors.meta(icons.cross)}`);
    console.log(colors.system(box.vertical) + `   Tier 1 (Model): ${routing.tier === 1 ? colors.success(icons.check) : colors.meta(icons.cross)}`);
    console.log(colors.system(box.vertical) + `   Tier 2 (Hybrid): ${routing.tier === 2 ? colors.success(icons.check) : colors.meta(icons.cross)}`);
    console.log(colors.system(box.vertical) + `   Tier 3 (Deep): ${routing.tier === 3 ? colors.success(icons.check) : colors.meta(icons.cross)} ${routing.tier === 3 ? tierColor('SELECTED') : ''}`);
    console.log(colors.system(box.vertical));

    // Reasoning
    console.log(colors.system(box.vertical) + ` Reasoning:`);
    console.log(colors.system(box.vertical) + `   "${colors.decision(routing.reasoning)}"`);
    console.log(colors.system(box.vertical));
    console.log(colors.system(box.vertical) + ` Decision Confidence: ${routing.confidence.toFixed(2)}`);
    console.log(colors.system(box.vertical));

    // Metrics
    console.log(colors.metric(box.vertical) + ` ${icons.chart} Tokens: ${formatTokens(routing.tokens.input)} input | ${formatTokens(routing.tokens.output)} output`);
    console.log(colors.metric(box.vertical) + ` ${icons.money} Cost: ${formatCost(routing.cost)}`);
    console.log(colors.metric(box.vertical) + ` ${icons.clock} Latency: ${formatDuration(routing.latency)}`);

    console.log(colors.system(box.bottomLeft + createLine(80) + box.bottomRight));
    console.log(`\n${colors.success(icons.rocket)} Routing to Tier ${routing.tier}: ${tierEmoji} ${tierName}\n`);
  }

  /**
   * Stage 3: Planning (T3 only)
   */
  displayPlanning(plan: ResearchPlan): void {
    console.log('\n' + colors.system(box.topLeft + createLine(60) + ' 📊 RESEARCH PLANNING ' + createLine(8) + box.topRight));
    console.log(colors.system(box.vertical) + ` Model: gemini-2.0-flash-lite`);
    console.log(colors.system(box.vertical));
    console.log(colors.system(box.vertical) + ` Strategy: ${colors.highlight(plan.strategy)}`);
    console.log(colors.system(box.vertical) + ` Estimated Rounds: ${colors.highlight(plan.estimatedRounds.toString())}`);
    console.log(colors.system(box.vertical));
    console.log(colors.system(box.vertical) + ` Focus Areas:`);
    plan.focusAreas.forEach(area => {
      console.log(colors.system(box.vertical) + `   ${icons.bullet} ${area}`);
    });
    console.log(colors.system(box.vertical));
    console.log(colors.system(box.vertical) + ` Reasoning:`);
    console.log(colors.system(box.vertical) + `   "${colors.decision(plan.reasoning)}"`);
    console.log(colors.system(box.vertical));

    // Metrics
    console.log(colors.metric(box.vertical) + ` ${icons.chart} Tokens: ${formatTokens(plan.tokens.input)} input | ${formatTokens(plan.tokens.output)} output`);
    console.log(colors.metric(box.vertical) + ` ${icons.money} Cost: ${formatCost(plan.cost)}`);
    console.log(colors.metric(box.vertical) + ` ${icons.clock} Latency: ${formatDuration(plan.latency)}`);

    console.log(colors.system(box.bottomLeft + createLine(80) + box.bottomRight));
  }

  /**
   * Stage 4: Research Round
   */
  displayRound(round: RoundResult): void {
    const roundTitle = round.purpose === 'initial' ? 'INITIAL BROAD SEARCH' : 'GAP-TARGETED SEARCH';
    console.log('\n' + colors.success(box.topLeft + createLine(55) + ` 🔄 ROUND ${round.roundNumber}: ${roundTitle} ` + createLine(5) + box.topRight));
    console.log(colors.success(box.vertical));

    // API Calls
    round.apiCalls.forEach(api => {
      const apiIcon = api.api === 'pubmed' ? '📚' : api.api === 'medrxiv' ? '🔬' : api.api === 'clinicaltrials' ? '🏥' : '🌐';
      const apiName = api.api.toUpperCase();
      const statusIcon = api.status === 'success' ? colors.success(icons.check) : colors.error(icons.cross);

      console.log(colors.success(box.vertical) + ` ${apiIcon} ${apiName} API Call`);
      console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ Query: "${truncate(api.query, 50)}"`);
      console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ Max results: ${api.maxResults}`);
      console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ Status: ${statusIcon} ${api.status.toUpperCase()}`);
      console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ Found: ${api.found} results`);
      console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ Retrieved: ${api.retrieved}`);
      console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ ${icons.clock} Latency: ${formatDuration(api.latency)}`);

      // Show top results if verbose
      if (this.verbose && api.results.length > 0) {
        console.log(colors.success(box.vertical) + ` ${box.verticalRight}─ Top Results:`);
        api.results.slice(0, 3).forEach((result, idx) => {
          console.log(colors.success(box.vertical) + `    ${idx + 1}. ${colors.highlight(truncate(result.title, 60))}`);
          if (result.authors) {
            console.log(colors.success(box.vertical) + `       ${colors.meta('Authors: ' + truncate(result.authors, 50))}`);
          }
        });
      }
      console.log(colors.success(box.vertical));
    });

    // Round Summary
    console.log(colors.success(box.vertical) + ` Round ${round.roundNumber} Summary:`);
    console.log(colors.success(box.vertical) + `   Sources gathered: ${round.sourceCount} / ${round.estimatedSources} target`);
    console.log(colors.success(box.vertical) + `   ${icons.clock} Total latency: ${formatDuration(round.duration)}`);

    console.log(colors.success(box.bottomLeft + createLine(80) + box.bottomRight));
  }

  /**
   * Stage 5: Gap Analysis (T3 only)
   */
  displayGapAnalysis(round: RoundResult): void {
    if (!round.gapAnalysis) return;

    const gap = round.gapAnalysis;
    console.log('\n' + colors.decision(box.topLeft + createLine(55) + ` 🧩 GAP DETECTION: Round ${round.roundNumber} ` + createLine(10) + box.topRight));
    console.log(colors.decision(box.vertical) + ` Model: gemini-2.0-flash-lite`);
    console.log(colors.decision(box.vertical));
    console.log(colors.decision(box.vertical) + ` Analyzing coverage gaps...`);
    console.log(colors.decision(box.vertical));

    // Well Covered
    if (gap.wellCovered.length > 0) {
      console.log(colors.success(box.vertical) + ` ${icons.check} Well Covered:`);
      gap.wellCovered.forEach(item => {
        console.log(colors.success(box.vertical) + `   ${icons.bullet} ${item}`);
      });
      console.log(colors.decision(box.vertical));
    }

    // Partially Covered
    if (gap.partiallyCovered.length > 0) {
      console.log(colors.warning(box.vertical) + ` ${icons.warning} Partially Covered:`);
      gap.partiallyCovered.forEach(item => {
        console.log(colors.warning(box.vertical) + `   ${icons.bullet} ${item}`);
      });
      console.log(colors.decision(box.vertical));
    }

    // Not Covered
    if (gap.notCovered.length > 0) {
      console.log(colors.error(box.vertical) + ` ${icons.cross} Not Covered:`);
      gap.notCovered.forEach(item => {
        console.log(colors.error(box.vertical) + `   ${icons.bullet} ${item}`);
      });
      console.log(colors.decision(box.vertical));
    }

    console.log(colors.decision(box.vertical) + ` Gap Score: ${gap.gapScore.toFixed(2)} (target: >0.85)`);
    console.log(colors.decision(box.vertical) + ` Evidence Quality: ${gap.evidenceQuality.toUpperCase()}`);
    console.log(colors.decision(box.vertical));
    console.log(colors.decision(box.vertical) + ` Decision: ${gap.decision === 'continue' ? colors.success('PROCEED TO NEXT ROUND') : colors.success('STOP SEARCHING, PROCEED TO RANKING')}`);
    console.log(colors.decision(box.vertical) + ` Reason: ${gap.reasoning}`);
    console.log(colors.decision(box.vertical));

    // Metrics
    console.log(colors.metric(box.vertical) + ` ${icons.chart} Tokens: ${formatTokens(gap.tokens.input)} input | ${formatTokens(gap.tokens.output)} output`);
    console.log(colors.metric(box.vertical) + ` ${icons.money} Cost: ${formatCost(gap.cost)}`);
    console.log(colors.metric(box.vertical) + ` ${icons.clock} Latency: ${formatDuration(gap.latency)}`);

    console.log(colors.decision(box.bottomLeft + createLine(80) + box.bottomRight));
  }

  /**
   * Stage 6: Response Synthesis
   */
  displaySynthesis(synthesis: ResponseSynthesis): void {
    console.log('\n' + colors.system(box.topLeft + createLine(60) + ' ✍️  RESPONSE SYNTHESIS ' + createLine(8) + box.topRight));
    console.log(colors.system(box.vertical) + ` Model: ${synthesis.model}`);
    console.log(colors.system(box.vertical) + ` Temperature: ${synthesis.temperature}`);
    console.log(colors.system(box.vertical) + ` Sources Provided: ${synthesis.sourcesProvided}`);
    console.log(colors.system(box.vertical));
    console.log(colors.system(box.vertical) + ` ${colors.success('Streaming response...')}`);
    console.log(colors.system(box.vertical));

    // Show response preview
    if (synthesis.response) {
      const preview = truncate(synthesis.response, 200);
      console.log(colors.system(box.vertical) + ` Response Preview:`);
      console.log(colors.system(box.vertical) + `   ${colors.meta(preview)}`);
      console.log(colors.system(box.vertical));
    }

    // Metrics
    console.log(colors.metric(box.vertical) + ` ${icons.chart} Tokens: ${formatTokens(synthesis.tokens.input)} input | ${formatTokens(synthesis.tokens.output)} output`);
    console.log(colors.metric(box.vertical) + ` ${icons.money} Cost: ${formatCost(synthesis.cost)}`);
    console.log(colors.metric(box.vertical) + ` ${icons.clock} Latency: ${formatDuration(synthesis.latency)} (streaming)`);
    console.log(colors.metric(box.vertical) + ` Response Length: ${synthesis.responseLength} chars`);

    console.log(colors.system(box.bottomLeft + createLine(80) + box.bottomRight));
  }

  /**
   * Stage 7: Final Summary
   */
  displaySummary(summary: JourneySummary, query: string): void {
    console.log('\n' + colors.highlight(box.topLeft + createLine(55) + ' 📊 RESEARCH JOURNEY COMPLETE ' + createLine(5) + box.topRight));
    console.log(colors.highlight(box.vertical));
    console.log(colors.highlight(box.vertical) + ` Query: "${truncate(query, 60)}"`);
    console.log(colors.highlight(box.vertical));

    // Pipeline Performance
    console.log(colors.highlight(box.vertical) + ` Pipeline Performance:`);
    console.log(colors.highlight(box.vertical) + `   ${icons.clock} Total time: ${formatDuration(summary.totalTime)}`);
    console.log(colors.highlight(box.vertical) + `   🔄 Rounds: ${summary.rounds}`);
    console.log(colors.highlight(box.vertical) + `   📚 Sources: ${summary.totalSources}`);
    console.log(colors.highlight(box.vertical));

    // Cost Breakdown
    console.log(colors.metric(box.vertical) + ` Cost Breakdown:`);
    console.log(colors.metric(box.vertical) + `   💰 Total: ${formatCost(summary.totalCost)}`);
    console.log(colors.metric(box.vertical));

    // Token Usage
    console.log(colors.metric(box.vertical) + ` Token Usage:`);
    console.log(colors.metric(box.vertical) + `   📥 Input: ${formatTokens(summary.totalTokens.input)} tokens`);
    console.log(colors.metric(box.vertical) + `   📤 Output: ${formatTokens(summary.totalTokens.output)} tokens`);
    console.log(colors.metric(box.vertical) + `   📊 Total: ${formatTokens(summary.totalTokens.input + summary.totalTokens.output)} tokens`);
    console.log(colors.metric(box.vertical));

    // Bottlenecks
    if (summary.bottlenecks.length > 0) {
      console.log(colors.warning(box.vertical) + ` Bottlenecks Detected:`);
      summary.bottlenecks.slice(0, 3).forEach(bottleneck => {
        console.log(colors.warning(box.vertical) + `   ${icons.warning} ${bottleneck.stage}: ${formatDuration(bottleneck.latency)} (${formatPercentage(bottleneck.percentage)} of total time)`);
      });
      console.log(colors.warning(box.vertical));
    }

    // Recommendations
    if (summary.recommendations.length > 0) {
      console.log(colors.decision(box.vertical) + ` Recommendations:`);
      summary.recommendations.forEach(rec => {
        console.log(colors.decision(box.vertical) + `   ${icons.bullet} ${rec}`);
      });
      console.log(colors.decision(box.vertical));
    }

    console.log(colors.highlight(box.bottomLeft + createLine(80) + box.bottomRight));
  }

  /**
   * Display complete journey
   */
  displayJourney(journey: ResearchJourney): void {
    this.displayHeader();
    this.displayQueryInput(journey);
    this.displayRouterDecision(journey.routing);

    if (journey.planning) {
      this.displayPlanning(journey.planning);
    }

    journey.rounds.forEach(round => {
      this.displayRound(round);
      if (round.gapAnalysis) {
        this.displayGapAnalysis(round);
      }
    });

    this.displaySynthesis(journey.synthesis);
    this.displaySummary(journey.summary, journey.query.original);
  }
}
