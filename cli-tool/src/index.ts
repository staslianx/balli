#!/usr/bin/env node

import { Command } from 'commander';
import inquirer from 'inquirer';
import ora from 'ora';
import { ConfigLoader } from './config/config-loader';
import { ResearchInterceptor } from './collectors/research-interceptor';
import { StageVisualizer } from './visualizers/stage-visualizer';
import { JSONExporter } from './exporters/json-exporter';
import { MarkdownExporter } from './exporters/markdown-exporter';
import { SSEEvent, ResearchJourney } from './types/research-journey';
import { colors, icons } from './utils/colors';

const program = new Command();

program
  .name('research-xray')
  .description('Deep Research Observatory - X-ray visibility into Balli\'s research pipeline')
  .version('1.0.0');

// Main interactive mode
program
  .command('run', { isDefault: true })
  .description('Run research observatory in interactive mode')
  .option('-c, --config <path>', 'Path to configuration file')
  .option('-v, --verbose', 'Enable verbose output')
  .option('-q, --query <query>', 'Research query (skip interactive prompt)')
  .option('-u, --user-id <id>', 'User ID', 'cli-user')
  .action(async (options) => {
    try {
      // Load configuration
      const configLoader = new ConfigLoader(options.config);
      const config = configLoader.getConfig();
      configLoader.ensureOutputDir();

      // Initialize visualizer early
      const visualizer = new StageVisualizer(options.verbose);

      // Display header FIRST
      visualizer.displayHeader();

      // Get query
      let query: string;
      if (options.query) {
        query = options.query;
      } else {
        const answers = await inquirer.prompt([
          {
            type: 'input',
            name: 'query',
            message: '📝 Enter your research query (Turkish):',
            validate: (input: string) => {
              if (!input || input.trim().length === 0) {
                return 'Query cannot be empty';
              }
              return true;
            }
          }
        ]);
        query = answers.query;
      }

      console.log(`\n${colors.success(icons.target)} Starting research journey...\n`);

      // Initialize components
      const firebaseUrl = configLoader.getFirebaseUrl();
      const interceptor = new ResearchInterceptor(firebaseUrl);

      // Create spinner for initial routing
      let currentSpinner: any = ora({
        text: 'Analyzing query and routing...',
        color: 'cyan'
      }).start();

      let lastEvent: SSEEvent | null = null;
      let accumulatedResponse = '';
      let synthesisStartTime = 0;

      // Execute research with real-time visualization
      const journey = await interceptor.executeResearch(
        {
          question: query,
          userId: options.userId
        },
        (event: SSEEvent) => {
          // Handle real-time events with CLEAN, PROFESSIONAL OUTPUT
          if (event.type === 'routing') {
            if (currentSpinner) currentSpinner.text = event.message;
          } else if (event.type === 'tier_selected') {
            if (currentSpinner) currentSpinner.stop();
            console.log('\n' + colors.meta('┌' + '─'.repeat(78) + '┐'));
            console.log(colors.meta('│') + colors.highlight(' 🎯 TIER ROUTING DECISION') + ' '.repeat(53) + colors.meta('│'));
            console.log(colors.meta('├' + '─'.repeat(78) + '┤'));
            console.log(colors.meta('│') + ' Model: ' + colors.system('gemini-2.0-flash-lite') + ' '.repeat(54) + colors.meta('│'));
            console.log(colors.meta('│') + ' '.repeat(78) + colors.meta('│'));
            const tierName = event.tier === 0 ? 'T0: Memory Recall' : event.tier === 1 ? 'T1: Model Direct' : event.tier === 2 ? 'T2: Web Search' : 'T3: Deep Research';
            console.log(colors.meta('│') + ' Selected: ' + colors.success(tierName) + ' '.repeat(65 - tierName.length) + colors.meta('│'));
            console.log(colors.meta('│') + ' Confidence: ' + colors.metric(`${(event.confidence * 100).toFixed(0)}%`) + ' '.repeat(64) + colors.meta('│'));
            console.log(colors.meta('│') + ' '.repeat(78) + colors.meta('│'));
            console.log(colors.meta('│') + ' Reasoning:' + ' '.repeat(67) + colors.meta('│'));
            const reasoningWords = event.reasoning.match(/.{1,74}/g) || [event.reasoning];
            reasoningWords.forEach(line => {
              console.log(colors.meta('│') + '   ' + colors.decision(line) + ' '.repeat(75 - line.length) + colors.meta('│'));
            });
            console.log(colors.meta('└' + '─'.repeat(78) + '┘'));
            currentSpinner = null;
          } else if (event.type === 'planning_started') {
            console.log('\n' + colors.highlight('📋 PLANNING STARTED'));
            currentSpinner = ora({ text: 'Creating research plan...', color: 'blue' }).start();
          } else if (event.type === 'planning_complete') {
            if (currentSpinner) currentSpinner.stop();
            console.log(colors.success('✓ Planning complete'));
            console.log(colors.system(`   Strategy: ${event.plan.strategy}`));
            console.log(colors.system(`   Focus Areas: ${event.plan.focusAreas?.join(', ') || 'N/A'}`));
            console.log(colors.system(`   Estimated Rounds: ${event.plan.estimatedRounds}`));
            console.log(colors.decision(`   Reasoning: ${event.plan.reasoning}`));
            currentSpinner = null;
          } else if (event.type === 'round_started') {
            console.log('\n' + colors.highlight(`🔄 ROUND ${event.round} STARTED`));
            console.log(colors.system(`   Query: ${event.query}`));
            console.log(colors.system(`   Target: ${event.estimatedSources} sources`));
            currentSpinner = ora({ text: 'Fetching sources...', color: 'green' }).start();
          } else if (event.type === 'api_started') {
            if (currentSpinner) {
              currentSpinner.text = `Calling ${event.api.toUpperCase()} API (target: ${event.count} sources)...`;
            }
          } else if (event.type === 'api_completed') {
            if (currentSpinner) currentSpinner.stop();
            console.log(colors.success(`   ✓ ${event.api.toUpperCase()}: ${event.count} sources in ${event.duration}ms`));
            if (currentSpinner) currentSpinner.start();
          } else if (event.type === 'round_complete') {
            if (currentSpinner) currentSpinner.stop();
            console.log(colors.success(`✓ Round ${event.round} complete: ${event.sourceCount} total sources`));
            currentSpinner = null;
          } else if (event.type === 'reflection_started') {
            console.log('\n' + colors.highlight(`🤔 ANALYZING ROUND ${event.round}`));
            currentSpinner = ora({ text: 'Evaluating coverage and gaps...', color: 'yellow' }).start();
          } else if (event.type === 'reflection_complete') {
            if (currentSpinner) currentSpinner.stop();
            console.log('\n' + colors.meta('┌' + '─'.repeat(78) + '┐'));
            console.log(colors.meta('│') + colors.highlight(' 🔍 GAP ANALYSIS') + ' '.repeat(62) + colors.meta('│'));
            console.log(colors.meta('├' + '─'.repeat(78) + '┤'));
            console.log(colors.meta('│') + ' ' + colors.success('✓ Well Covered:') + ' '.repeat(62) + colors.meta('│'));
            (event.reflection.wellCovered || []).forEach((item: string) => {
              const display = `   • ${item}`;
              const padding = Math.max(0, 78 - display.length);
              console.log(colors.meta('│') + colors.system(display) + ' '.repeat(padding) + colors.meta('│'));
            });
            console.log(colors.meta('│') + ' ' + colors.warning('⚠ Partially Covered:') + ' '.repeat(57) + colors.meta('│'));
            (event.reflection.partiallyCovered || []).forEach((item: string) => {
              const display = `   • ${item}`;
              const padding = Math.max(0, 78 - display.length);
              console.log(colors.meta('│') + colors.system(display) + ' '.repeat(padding) + colors.meta('│'));
            });
            console.log(colors.meta('│') + ' ' + colors.error('✗ Gaps Identified:') + ' '.repeat(59) + colors.meta('│'));
            (event.reflection.gapsIdentified || []).forEach((item: string) => {
              const display = `   • ${item}`;
              const padding = Math.max(0, 78 - display.length);
              console.log(colors.meta('│') + colors.warning(display) + ' '.repeat(padding) + colors.meta('│'));
            });
            console.log(colors.meta('│') + ' '.repeat(78) + colors.meta('│'));
            const decision = event.reflection.shouldContinue ? '▶ CONTINUE to next round' : '■ STOP - sufficient coverage';
            const decisionPadding = Math.max(0, 67 - decision.length);
            console.log(colors.meta('│') + ' Decision: ' + colors.highlight(decision) + ' '.repeat(decisionPadding) + colors.meta('│'));
            console.log(colors.meta('│') + ' Reasoning:' + ' '.repeat(67) + colors.meta('│'));
            const reasoning = event.reflection.reasoning.match(/.{1,74}/g) || [event.reflection.reasoning];
            reasoning.forEach((line: string) => {
              const linePadding = Math.max(0, 75 - line.length);
              console.log(colors.meta('│') + '   ' + colors.decision(line) + ' '.repeat(linePadding) + colors.meta('│'));
            });
            console.log(colors.meta('└' + '─'.repeat(78) + '┘'));
            currentSpinner = null;
          } else if (event.type === 'synthesis_started') {
            console.log('\n' + colors.highlight('✍️  SYNTHESIZING RESPONSE'));
            console.log(colors.system(`   Sources provided: ${event.totalSources}`));
            currentSpinner = ora({ text: 'Generating response...', color: 'magenta' }).start();
          } else if (event.type === 'token') {
            // Accumulate response instead of showing token by token
            accumulatedResponse += event.content;
          } else if (event.type === 'complete') {
            // Display full accumulated response at once
            if (accumulatedResponse) {
              console.log('\n\n' + colors.highlight('📝 RESPONSE:'));
              console.log(colors.meta('─'.repeat(80)));
              console.log(colors.response(accumulatedResponse));
              console.log(colors.meta('─'.repeat(80)));
            }
            console.log('\n' + colors.success('✓ Research complete!'));
            currentSpinner = null;
          } else if (event.type === 'error') {
            if (currentSpinner) currentSpinner.fail(event.message);
            console.log(colors.error(`   Error: ${event.message}`));
            currentSpinner = null;
          }

          lastEvent = event;
        }
      );

      // Display complete journey
      console.log('\n');
      visualizer.displayJourney(journey);

      // Export results
      if (config.export.autoSave) {
        const jsonExporter = new JSONExporter();
        const mdExporter = new MarkdownExporter();

        if (config.export.formats.includes('json')) {
          const jsonPath = configLoader.generateOutputFilename('json');
          jsonExporter.export(journey, jsonPath);
        }

        if (config.export.formats.includes('markdown')) {
          const mdPath = configLoader.generateOutputFilename('md');
          mdExporter.export(journey, mdPath);
        }
      }

      // Interactive commands
      await showInteractiveMenu(journey, visualizer, configLoader);

    } catch (error: any) {
      console.error(`\n${colors.error(icons.cross)} Error: ${error.message}`);
      if (error.stack && program.opts().verbose) {
        console.error(colors.meta(error.stack));
      }
      process.exit(1);
    }
  });

// Replay mode
program
  .command('replay <file>')
  .description('Replay research journey from saved JSON file')
  .option('-v, --verbose', 'Enable verbose output')
  .action(async (file: string, options) => {
    try {
      const jsonExporter = new JSONExporter();
      const journey = jsonExporter.load(file);
      const visualizer = new StageVisualizer(options.verbose);

      console.log('\n' + colors.highlight('🔄 Replaying research journey...\n'));
      visualizer.displayJourney(journey);

      const configLoader = new ConfigLoader();
      await showInteractiveMenu(journey, visualizer, configLoader);
    } catch (error: any) {
      console.error(`\n${colors.error(icons.cross)} Error loading file: ${error.message}`);
      process.exit(1);
    }
  });

/**
 * Interactive menu after research completes
 */
async function showInteractiveMenu(
  journey: ResearchJourney,
  visualizer: StageVisualizer,
  configLoader: ConfigLoader
): Promise<void> {
  let continueMenu = true;

  while (continueMenu) {
    console.log('\n' + colors.highlight('🔍 Commands:'));
    console.log('  v - View full response');
    console.log('  s - Show all sources');
    console.log('  t - Token/cost breakdown');
    console.log('  r - Run another query');
    console.log('  e - Export to different format');
    console.log('  q - Quit');

    const answer = await inquirer.prompt([
      {
        type: 'input',
        name: 'command',
        message: 'Enter command:',
        validate: (input: string) => {
          const valid = ['v', 's', 't', 'r', 'e', 'q'];
          if (!valid.includes(input.toLowerCase())) {
            return `Invalid command. Valid commands: ${valid.join(', ')}`;
          }
          return true;
        }
      }
    ]);

    const cmd = answer.command.toLowerCase();

    switch (cmd) {
      case 'v':
        showFullResponse(journey);
        break;
      case 's':
        showAllSources(journey);
        break;
      case 't':
        showTokenCostBreakdown(journey);
        break;
      case 'r':
        continueMenu = false;
        // Restart the program
        console.log('\n' + colors.success('Starting new research...\n'));
        process.exit(0);
        break;
      case 'e':
        await exportToFormat(journey, configLoader);
        break;
      case 'q':
        console.log('\n' + colors.success('👋 Goodbye!\n'));
        continueMenu = false;
        process.exit(0);
        break;
    }
  }
}

function showFullResponse(journey: ResearchJourney): void {
  console.log('\n' + colors.highlight('📄 Full Response:'));
  console.log(colors.meta('─'.repeat(80)));
  console.log(journey.synthesis.response);
  console.log(colors.meta('─'.repeat(80)));
}

function showAllSources(journey: ResearchJourney): void {
  console.log('\n' + colors.highlight('📚 All Sources:'));
  console.log(colors.meta('─'.repeat(80)));

  journey.rounds.forEach((round, idx) => {
    console.log(`\n${colors.success(`Round ${idx + 1}:`)}`);

    const allSources = [
      ...round.sources.pubmed.map(s => ({ ...s, type: 'PubMed' })),
      ...round.sources.medrxiv.map(s => ({ ...s, type: 'medRxiv' })),
      ...round.sources.clinicalTrials.map(s => ({ ...s, type: 'Clinical Trial' })),
      ...round.sources.exa.map(s => ({ ...s, type: 'Web Source' }))
    ];

    allSources.forEach((source, sIdx) => {
      console.log(`\n  ${sIdx + 1}. ${colors.highlight(source.title || 'Untitled')}`);
      console.log(`     Type: ${source.type}`);
      if (source.authors) console.log(`     Authors: ${source.authors}`);
      if (source.journal) console.log(`     Journal: ${source.journal}`);
      if (source.year) console.log(`     Year: ${source.year}`);
      if (source.url) console.log(`     URL: ${colors.meta(source.url)}`);
    });
  });

  console.log('\n' + colors.meta('─'.repeat(80)));
}

function showTokenCostBreakdown(journey: ResearchJourney): void {
  console.log('\n' + colors.highlight('💰 Token & Cost Breakdown:'));
  console.log(colors.meta('─'.repeat(80)));

  // Routing
  console.log(`\n${colors.system('Routing:')}`);
  console.log(`  Tokens: ${journey.routing.tokens.input} input | ${journey.routing.tokens.output} output`);
  console.log(`  Cost: ${formatCost(journey.routing.cost)}`);

  // Planning
  if (journey.planning) {
    console.log(`\n${colors.system('Planning:')}`);
    console.log(`  Tokens: ${journey.planning.tokens.input} input | ${journey.planning.tokens.output} output`);
    console.log(`  Cost: ${formatCost(journey.planning.cost)}`);
  }

  // Rounds
  journey.rounds.forEach((round, idx) => {
    if (round.gapAnalysis) {
      console.log(`\n${colors.system(`Round ${idx + 1} Gap Analysis:`)}`);
      console.log(`  Tokens: ${round.gapAnalysis.tokens.input} input | ${round.gapAnalysis.tokens.output} output`);
      console.log(`  Cost: ${formatCost(round.gapAnalysis.cost)}`);
    }
  });

  // Synthesis
  console.log(`\n${colors.system('Synthesis:')}`);
  console.log(`  Tokens: ${journey.synthesis.tokens.input} input | ${journey.synthesis.tokens.output} output`);
  console.log(`  Cost: ${formatCost(journey.synthesis.cost)}`);

  // Total
  console.log(`\n${colors.highlight('Total:')}`);
  console.log(`  Tokens: ${journey.summary.totalTokens.input} input | ${journey.summary.totalTokens.output} output`);
  console.log(`  Total Tokens: ${journey.summary.totalTokens.input + journey.summary.totalTokens.output}`);
  console.log(`  Total Cost: ${formatCost(journey.summary.totalCost)}`);

  console.log('\n' + colors.meta('─'.repeat(80)));
}

async function exportToFormat(journey: ResearchJourney, configLoader: ConfigLoader): Promise<void> {
  const answer = await inquirer.prompt([
    {
      type: 'list',
      name: 'format',
      message: 'Select export format:',
      choices: ['JSON', 'Markdown', 'Both']
    }
  ]);

  const jsonExporter = new JSONExporter();
  const mdExporter = new MarkdownExporter();

  if (answer.format === 'JSON' || answer.format === 'Both') {
    const jsonPath = configLoader.generateOutputFilename('json');
    jsonExporter.export(journey, jsonPath);
  }

  if (answer.format === 'Markdown' || answer.format === 'Both') {
    const mdPath = configLoader.generateOutputFilename('md');
    mdExporter.export(journey, mdPath);
  }
}

// Helper function to format cost
function formatCost(cost: number): string {
  return `$${cost.toFixed(6)}`;
}

program.parse();
