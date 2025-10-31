import * as fs from 'fs';
import { ResearchJourney } from '../types/research-journey';
import { formatDuration, formatCost, formatTokens, formatPercentage } from '../utils/colors';

export class MarkdownExporter {
  /**
   * Export journey to Markdown file
   */
  export(journey: ResearchJourney, filepath: string): void {
    try {
      const markdown = this.generateMarkdown(journey);
      fs.writeFileSync(filepath, markdown, 'utf-8');
      console.log(`\n📄 Markdown report saved to: ${filepath}`);
    } catch (error) {
      console.error(`Error exporting Markdown: ${error}`);
      throw error;
    }
  }

  private generateMarkdown(journey: ResearchJourney): string {
    let md = '';

    // Header
    md += '# Deep Research Observatory Report\n\n';
    md += `**Generated:** ${new Date().toLocaleString()}\n\n`;
    md += '---\n\n';

    // Executive Summary
    md += '## Executive Summary\n\n';
    md += `- **Query:** "${journey.query.original}"\n`;
    md += `- **Tier:** ${journey.routing.tier} (${this.getTierName(journey.routing.tier)})\n`;
    md += `- **Total Time:** ${formatDuration(journey.summary.totalTime)}\n`;
    md += `- **Total Cost:** ${formatCost(journey.summary.totalCost)}\n`;
    md += `- **Rounds:** ${journey.summary.rounds}\n`;
    md += `- **Total Sources:** ${journey.summary.totalSources}\n\n`;

    // Query Details
    md += '## Query Input\n\n';
    md += `- **Original Query:** ${journey.query.original}\n`;
    md += `- **Language:** ${journey.query.language}\n`;
    md += `- **Length:** ${journey.query.length} characters\n`;
    md += `- **Timestamp:** ${journey.query.timestamp}\n`;
    md += `- **User ID:** ${journey.query.userId}\n\n`;

    // Router Decision
    md += '## Router Decision\n\n';
    md += `- **Selected Tier:** ${journey.routing.tier}\n`;
    md += `- **Confidence:** ${journey.routing.confidence.toFixed(2)}\n`;
    md += `- **Reasoning:** ${journey.routing.reasoning}\n`;
    md += `- **Latency:** ${formatDuration(journey.routing.latency)}\n\n`;

    // Planning (if T3)
    if (journey.planning) {
      md += '## Research Planning\n\n';
      md += `- **Strategy:** ${journey.planning.strategy}\n`;
      md += `- **Estimated Rounds:** ${journey.planning.estimatedRounds}\n`;
      md += `- **Focus Areas:**\n`;
      journey.planning.focusAreas.forEach(area => {
        md += `  - ${area}\n`;
      });
      md += `- **Reasoning:** ${journey.planning.reasoning}\n\n`;
    }

    // Rounds
    md += '## Research Rounds\n\n';
    journey.rounds.forEach(round => {
      md += `### Round ${round.roundNumber} - ${round.purpose === 'initial' ? 'Initial Broad Search' : 'Gap-Targeted Search'}\n\n`;
      md += `- **Query:** "${round.query}"\n`;
      md += `- **Duration:** ${formatDuration(round.duration)}\n`;
      md += `- **Sources Retrieved:** ${round.sourceCount}\n\n`;

      // API Calls
      md += '#### API Calls\n\n';
      round.apiCalls.forEach(api => {
        md += `**${api.api.toUpperCase()}:**\n`;
        md += `- Query: "${api.query}"\n`;
        md += `- Max Results: ${api.maxResults}\n`;
        md += `- Found: ${api.found}\n`;
        md += `- Retrieved: ${api.retrieved}\n`;
        md += `- Status: ${api.status}\n`;
        md += `- Latency: ${formatDuration(api.latency)}\n\n`;
      });

      // Gap Analysis
      if (round.gapAnalysis) {
        md += '#### Gap Analysis\n\n';
        md += `- **Gap Score:** ${round.gapAnalysis.gapScore.toFixed(2)}\n`;
        md += `- **Evidence Quality:** ${round.gapAnalysis.evidenceQuality}\n`;
        md += `- **Decision:** ${round.gapAnalysis.decision}\n\n`;

        if (round.gapAnalysis.wellCovered.length > 0) {
          md += '**Well Covered:**\n';
          round.gapAnalysis.wellCovered.forEach(item => {
            md += `- ✓ ${item}\n`;
          });
          md += '\n';
        }

        if (round.gapAnalysis.notCovered.length > 0) {
          md += '**Not Covered:**\n';
          round.gapAnalysis.notCovered.forEach(item => {
            md += `- ✗ ${item}\n`;
          });
          md += '\n';
        }
      }
    });

    // Synthesis
    md += '## Response Synthesis\n\n';
    md += `- **Model:** ${journey.synthesis.model}\n`;
    md += `- **Temperature:** ${journey.synthesis.temperature}\n`;
    md += `- **Sources Provided:** ${journey.synthesis.sourcesProvided}\n`;
    md += `- **Response Length:** ${journey.synthesis.responseLength} characters\n`;
    md += `- **Input Tokens:** ${formatTokens(journey.synthesis.tokens.input)}\n`;
    md += `- **Output Tokens:** ${formatTokens(journey.synthesis.tokens.output)}\n`;
    md += `- **Cost:** ${formatCost(journey.synthesis.cost)}\n`;
    md += `- **Latency:** ${formatDuration(journey.synthesis.latency)}\n\n`;

    // Performance Metrics
    md += '## Performance Metrics\n\n';
    md += '### Cost Breakdown\n\n';
    md += `- **Total Cost:** ${formatCost(journey.summary.totalCost)}\n\n`;

    md += '### Token Usage\n\n';
    md += `- **Input Tokens:** ${formatTokens(journey.summary.totalTokens.input)}\n`;
    md += `- **Output Tokens:** ${formatTokens(journey.summary.totalTokens.output)}\n`;
    md += `- **Total Tokens:** ${formatTokens(journey.summary.totalTokens.input + journey.summary.totalTokens.output)}\n\n`;

    // Bottlenecks
    if (journey.summary.bottlenecks.length > 0) {
      md += '### Bottlenecks\n\n';
      md += '| Stage | Latency | Percentage |\n';
      md += '|-------|---------|------------|\n';
      journey.summary.bottlenecks.forEach(bottleneck => {
        md += `| ${bottleneck.stage} | ${formatDuration(bottleneck.latency)} | ${formatPercentage(bottleneck.percentage)} |\n`;
      });
      md += '\n';
    }

    // Recommendations
    if (journey.summary.recommendations.length > 0) {
      md += '### Recommendations\n\n';
      journey.summary.recommendations.forEach(rec => {
        md += `- ${rec}\n`;
      });
      md += '\n';
    }

    // Response Preview
    if (journey.synthesis.response) {
      md += '## Response Preview\n\n';
      const preview = journey.synthesis.response.substring(0, 500);
      md += `${preview}${journey.synthesis.response.length > 500 ? '...' : ''}\n\n`;
    }

    md += '---\n\n';
    md += '*Generated by Deep Research Observatory*\n';

    return md;
  }

  private getTierName(tier: number): string {
    switch (tier) {
      case 0: return 'Recall';
      case 1: return 'Model';
      case 2: return 'Hybrid Research';
      case 3: return 'Deep Research';
      default: return 'Unknown';
    }
  }
}
