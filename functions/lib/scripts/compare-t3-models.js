"use strict";
/**
 * CLI Tool: Compare T3 Research Responses Between Models
 *
 * Compares gemini-2.5-pro vs gemini-2.5-flash for Tier 3 research
 * Uses the SAME sources for both models to ensure fair comparison
 *
 * Usage:
 *   npm run compare-t3 "Ketoasidoz nedir? Nasıl önlerim? derinleş"
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const deep_research_v2_1 = require("../flows/deep-research-v2");
const research_prompts_1 = require("../research-prompts");
const genkit_instance_1 = require("../genkit-instance");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
// Model identifiers
const MODEL_PRO = 'vertexai/gemini-2.5-pro';
const MODEL_FLASH = 'vertexai/gemini-2.5-flash';
// Pricing (approximate, per 1M tokens)
const PRICING = {
    'gemini-2.5-pro': {
        input: 1.25,
        output: 5.00
    },
    'gemini-2.5-flash': {
        input: 0.075,
        output: 0.30
    }
};
/**
 * Mock SSE Response for research phase
 * Captures research results without actual streaming
 */
class MockResponse {
    events = [];
    write(data) {
        // Parse SSE events
        if (data.startsWith('data: ')) {
            try {
                const json = JSON.parse(data.substring(6));
                this.events.push(json);
            }
            catch (e) {
                // Ignore parsing errors
            }
        }
        return true;
    }
    flush() { }
    end() { }
    setHeader() { }
    getEvents() {
        return this.events;
    }
}
/**
 * Estimate token count (rough approximation)
 */
function estimateTokens(text) {
    // Rough estimate: 1 token ≈ 4 characters for English, 3 for Turkish
    return Math.ceil(text.length / 3);
}
/**
 * Calculate cost based on token usage
 */
function calculateCost(modelName, inputTokens, outputTokens) {
    const modelKey = modelName.includes('pro') ? 'gemini-2.5-pro' : 'gemini-2.5-flash';
    const pricing = PRICING[modelKey];
    const inputCost = (inputTokens / 1_000_000) * pricing.input;
    const outputCost = (outputTokens / 1_000_000) * pricing.output;
    return inputCost + outputCost;
}
/**
 * Run synthesis with specified model
 */
async function runSynthesis(modelName, researchContext, question, systemPrompt) {
    const startTime = Date.now();
    // Build user prompt
    const userPrompt = `${researchContext}\n---\n\nKullanıcı Sorusu: "${question}"\n\nYukarıdaki tüm araştırma kaynaklarını sentezle ve soruya kapsamlı bir yanıt oluştur.\nÖNEMLİ: Inline [1][2][3] sitasyonları kullan. Sonuna "## Kaynaklar" bölümü ekleme.`;
    // Call model
    const result = await genkit_instance_1.ai.generate({
        model: modelName,
        system: systemPrompt,
        prompt: userPrompt,
        config: {
            temperature: 0.15,
            maxOutputTokens: 12000,
            safetySettings: [
                { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_ONLY_HIGH' },
                { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_ONLY_HIGH' }
            ]
        }
    });
    const latencyMs = Date.now() - startTime;
    // Extract response text
    const response = result.text || '';
    // Estimate tokens
    const inputTokens = estimateTokens(systemPrompt + userPrompt);
    const outputTokens = estimateTokens(response);
    return {
        response,
        latencyMs,
        inputTokens,
        outputTokens
    };
}
/**
 * Format comparison results as markdown
 */
function formatMarkdown(result) {
    const timestamp = new Date(result.timestamp).toISOString().replace(/:/g, '-').split('.')[0];
    let md = `# T3 Model Comparison Report\n\n`;
    md += `**Generated:** ${result.timestamp}\n\n`;
    md += `---\n\n`;
    // Query
    md += `## Query\n\n`;
    md += `> ${result.query}\n\n`;
    md += `---\n\n`;
    // Sources
    md += `## Research Sources (Shared)\n\n`;
    md += `**Total Sources:** ${result.sources.totalCount}\n\n`;
    md += `**Breakdown:**\n`;
    md += `- PubMed: ${result.sources.byType.pubmed}\n`;
    md += `- medRxiv: ${result.sources.byType.medrxiv}\n`;
    md += `- Clinical Trials: ${result.sources.byType.clinicalTrials}\n`;
    md += `- Exa Medical: ${result.sources.byType.exa}\n\n`;
    md += `*Note: Both models used identical sources for synthesis*\n\n`;
    md += `---\n\n`;
    // Performance Comparison
    md += `## Performance Comparison\n\n`;
    md += `| Metric | Gemini 2.5 Pro | Gemini 2.5 Flash | Winner |\n`;
    md += `|--------|---------------|------------------|--------|\n`;
    md += `| Latency | ${(result.pro.latencyMs / 1000).toFixed(2)}s | ${(result.flash.latencyMs / 1000).toFixed(2)}s | ${result.pro.latencyMs < result.flash.latencyMs ? '🏆 Pro' : '🏆 Flash'} |\n`;
    md += `| Input Tokens | ${result.pro.inputTokens.toLocaleString()} | ${result.flash.inputTokens.toLocaleString()} | - |\n`;
    md += `| Output Tokens | ${result.pro.outputTokens.toLocaleString()} | ${result.flash.outputTokens.toLocaleString()} | ${result.pro.outputTokens > result.flash.outputTokens ? '📝 Pro' : '📝 Flash'} |\n`;
    md += `| Estimated Cost | $${result.pro.estimatedCost.toFixed(4)} | $${result.flash.estimatedCost.toFixed(4)} | ${result.pro.estimatedCost < result.flash.estimatedCost ? '💰 Pro' : '💰 Flash'} |\n\n`;
    const costSavings = ((result.pro.estimatedCost - result.flash.estimatedCost) / result.pro.estimatedCost * 100).toFixed(1);
    const speedup = (result.pro.latencyMs / result.flash.latencyMs).toFixed(2);
    md += `**Key Insights:**\n`;
    md += `- Flash is **${speedup}x faster** than Pro\n`;
    md += `- Flash saves **${costSavings}%** in cost vs Pro\n\n`;
    md += `---\n\n`;
    // Pro Response
    md += `## Gemini 2.5 Pro Response\n\n`;
    md += `**Model:** \`vertexai/gemini-2.5-pro\`\n`;
    md += `**Temperature:** 0.15\n`;
    md += `**Max Output Tokens:** 12000\n\n`;
    md += `### Response:\n\n`;
    md += result.pro.response;
    md += `\n\n---\n\n`;
    // Flash Response
    md += `## Gemini 2.5 Flash Response\n\n`;
    md += `**Model:** \`vertexai/gemini-2.5-flash\`\n`;
    md += `**Temperature:** 0.15\n`;
    md += `**Max Output Tokens:** 12000\n\n`;
    md += `### Response:\n\n`;
    md += result.flash.response;
    md += `\n\n---\n\n`;
    // Subjective Analysis Section
    md += `## Subjective Analysis\n\n`;
    md += `*Fill in your observations after reviewing both responses:*\n\n`;
    md += `### Accuracy\n`;
    md += `- Pro: \n`;
    md += `- Flash: \n`;
    md += `- Winner: \n\n`;
    md += `### Comprehensiveness\n`;
    md += `- Pro: \n`;
    md += `- Flash: \n`;
    md += `- Winner: \n\n`;
    md += `### Citation Quality\n`;
    md += `- Pro: \n`;
    md += `- Flash: \n`;
    md += `- Winner: \n\n`;
    md += `### Tone & Clarity\n`;
    md += `- Pro: \n`;
    md += `- Flash: \n`;
    md += `- Winner: \n\n`;
    md += `### Overall Recommendation\n`;
    md += `- Best for Production: \n`;
    md += `- Rationale: \n\n`;
    return md;
}
/**
 * Main comparison function
 */
async function compareModels(query) {
    console.log(`🔍 Starting T3 model comparison for query: "${query}"\n`);
    // Step 1: Execute research ONCE (shared sources)
    console.log(`📚 [1/4] Executing T3 research flow (shared sources)...`);
    const mockRes = new MockResponse();
    const researchResults = await (0, deep_research_v2_1.executeDeepResearchV2)(query, mockRes);
    console.log(`✅ Research complete:`);
    console.log(`   - Rounds: ${researchResults.rounds.length}`);
    console.log(`   - Total sources: ${researchResults.totalSources}`);
    console.log(`   - PubMed: ${researchResults.allSources.pubmed.length}`);
    console.log(`   - medRxiv: ${researchResults.allSources.medrxiv.length}`);
    console.log(`   - Clinical Trials: ${researchResults.allSources.clinicalTrials.length}`);
    console.log(`   - Exa: ${researchResults.allSources.exa.length}\n`);
    // Step 2: Format research context
    const researchContext = (0, deep_research_v2_1.formatResearchForSynthesis)(researchResults);
    const systemPrompt = (0, research_prompts_1.buildResearchSystemPrompt)({ tier: 3 });
    // Step 3: Run Pro synthesis
    console.log(`🤖 [2/4] Running synthesis with Gemini 2.5 Pro...`);
    const proResult = await runSynthesis(MODEL_PRO, researchContext, query, systemPrompt);
    console.log(`✅ Pro complete:`);
    console.log(`   - Latency: ${(proResult.latencyMs / 1000).toFixed(2)}s`);
    console.log(`   - Output length: ${proResult.response.length} chars`);
    console.log(`   - Estimated cost: $${calculateCost(MODEL_PRO, proResult.inputTokens, proResult.outputTokens).toFixed(4)}\n`);
    // Step 4: Run Flash synthesis
    console.log(`⚡ [3/4] Running synthesis with Gemini 2.5 Flash...`);
    const flashResult = await runSynthesis(MODEL_FLASH, researchContext, query, systemPrompt);
    console.log(`✅ Flash complete:`);
    console.log(`   - Latency: ${(flashResult.latencyMs / 1000).toFixed(2)}s`);
    console.log(`   - Output length: ${flashResult.response.length} chars`);
    console.log(`   - Estimated cost: $${calculateCost(MODEL_FLASH, flashResult.inputTokens, flashResult.outputTokens).toFixed(4)}\n`);
    // Step 5: Create comparison result
    const comparison = {
        query,
        timestamp: new Date().toISOString(),
        sources: {
            totalCount: researchResults.totalSources,
            byType: {
                pubmed: researchResults.allSources.pubmed.length,
                medrxiv: researchResults.allSources.medrxiv.length,
                clinicalTrials: researchResults.allSources.clinicalTrials.length,
                exa: researchResults.allSources.exa.length
            }
        },
        pro: {
            response: proResult.response,
            latencyMs: proResult.latencyMs,
            inputTokens: proResult.inputTokens,
            outputTokens: proResult.outputTokens,
            estimatedCost: calculateCost(MODEL_PRO, proResult.inputTokens, proResult.outputTokens)
        },
        flash: {
            response: flashResult.response,
            latencyMs: flashResult.latencyMs,
            inputTokens: flashResult.inputTokens,
            outputTokens: flashResult.outputTokens,
            estimatedCost: calculateCost(MODEL_FLASH, flashResult.inputTokens, flashResult.outputTokens)
        }
    };
    // Step 6: Generate markdown report
    console.log(`📝 [4/4] Generating comparison report...`);
    const markdown = formatMarkdown(comparison);
    // Step 7: Save to file
    const timestamp = new Date().toISOString().replace(/:/g, '-').split('.')[0];
    const filename = `t3-comparison-${timestamp}.md`;
    const outputPath = path.join(__dirname, '../../test-results', filename);
    fs.writeFileSync(outputPath, markdown, 'utf8');
    console.log(`\n✅ Comparison complete!`);
    console.log(`📄 Report saved to: ${outputPath}\n`);
    // Print summary
    console.log(`📊 Summary:`);
    console.log(`   Pro:   ${(proResult.latencyMs / 1000).toFixed(2)}s, $${comparison.pro.estimatedCost.toFixed(4)}, ${proResult.response.length} chars`);
    console.log(`   Flash: ${(flashResult.latencyMs / 1000).toFixed(2)}s, $${comparison.flash.estimatedCost.toFixed(4)}, ${flashResult.response.length} chars`);
    const speedup = (proResult.latencyMs / flashResult.latencyMs).toFixed(2);
    const costSavings = ((comparison.pro.estimatedCost - comparison.flash.estimatedCost) / comparison.pro.estimatedCost * 100).toFixed(1);
    console.log(`\n   Flash is ${speedup}x faster and saves ${costSavings}% in cost`);
}
/**
 * CLI Entry Point
 */
async function main() {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.error(`❌ Error: Query argument required\n`);
        console.log(`Usage: npm run compare-t3 "Your diabetes research question here"`);
        console.log(`Example: npm run compare-t3 "Ketoasidoz nedir? Nasıl önlerim? derinleş"\n`);
        process.exit(1);
    }
    const query = args.join(' ');
    try {
        await compareModels(query);
    }
    catch (error) {
        console.error(`\n❌ Comparison failed:`, error);
        process.exit(1);
    }
}
// Run if called directly
if (require.main === module) {
    main();
}
//# sourceMappingURL=compare-t3-models.js.map