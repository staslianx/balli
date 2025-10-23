"use strict";
/**
 * Query Analyzer Tool
 * Analyzes user queries to determine optimal API source distribution
 * Uses Gemini 2.5 Flash for fast, accurate categorization
 *
 * Cost: ~$0.00001 per analysis
 * Timeout: 2 seconds
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzeQuery = analyzeQuery;
exports.calculateSourceCounts = calculateSourceCounts;
const genkit_instance_1 = require("../genkit-instance");
const providers_1 = require("../providers"); // Gemini 2.5 Flash Lite
/**
 * Few-shot examples for query categorization
 * Teaches the model optimal API distribution patterns
 */
const FEW_SHOT_EXAMPLES = `
DRUG SAFETY EXAMPLES:
Query: "Metformin yan etkileri nelerdir?"
Category: drug_safety
Distribution: PubMed 70%, medRxiv 10%, ClinicalTrials 20%
Reasoning: Drug safety requires peer-reviewed literature (PubMed) + clinical trial data

Query: "Lantus ile antibiyotik etkileşimi var mı?"
Category: drug_safety
Distribution: PubMed 80%, medRxiv 5%, ClinicalTrials 15%
Reasoning: Drug interactions need high medical literature emphasis

NEW RESEARCH EXAMPLES:
Query: "Beta cell regeneration latest research"
Category: new_research
Distribution: PubMed 50%, medRxiv 30%, ClinicalTrials 20%
Reasoning: Cutting-edge medical research appears on medRxiv (medical preprints) before PubMed

Query: "GLP-1 agonist 2025 clinical trials"
Category: new_research
Distribution: PubMed 40%, medRxiv 20%, ClinicalTrials 40%
Reasoning: Active clinical trials require ClinicalTrials.gov emphasis + recent medRxiv preprints

TREATMENT EXAMPLES:
Query: "Type 1 diabetes insulin therapy guidelines"
Category: treatment
Distribution: PubMed 65%, medRxiv 10%, ClinicalTrials 25%
Reasoning: Guidelines require established literature + trial evidence

Query: "A1C hedefim ne olmalı?"
Category: treatment
Distribution: PubMed 75%, medRxiv 5%, ClinicalTrials 20%
Reasoning: Treatment targets need medical consensus from PubMed

NUTRITION EXAMPLES:
Query: "Badem unu kan şekerine etkisi"
Category: nutrition
Distribution: PubMed 80%, medRxiv 15%, ClinicalTrials 5%
Reasoning: Nutrition science primarily in peer-reviewed journals

Query: "Low carb diet diabetes research"
Category: nutrition
Distribution: PubMed 75%, medRxiv 20%, ClinicalTrials 5%
Reasoning: Diet research spans PubMed and recent medRxiv preprints

GENERAL EXAMPLES:
Query: "A1C nedir nasıl ölçülür?"
Category: general
Distribution: PubMed 55%, medRxiv 20%, ClinicalTrials 25%
Reasoning: Balanced distribution for general education topics
`;
const SYSTEM_PROMPT = `You are a medical query analyzer for a diabetes research assistant.

Your task: Categorize the query and determine the optimal distribution of research sources.

Categories:
- drug_safety: Medication questions (side effects, interactions, dosing, safety)
- new_research: Latest studies, breakthrough research, recent clinical trials
- treatment: Guidelines, therapy decisions, treatment protocols
- nutrition: Diet, food, recipes, nutritional science
- general: Education, definitions, how things work

API Source Characteristics:
- PubMed: Peer-reviewed biomedical literature (most authoritative)
- medRxiv: Medical preprints, cutting-edge medical research (newest findings)
- ClinicalTrials.gov: Active trials, intervention studies

Guidelines:
1. Drug safety questions → High PubMed (70-80%)
2. New research → Higher medRxiv (20-30%) for latest medical findings
3. Active trials → High ClinicalTrials (30-40%)
4. Nutrition → High PubMed (75-80%) for evidence-based research
5. Treatment guidelines → Balanced PubMed + ClinicalTrials

${FEW_SHOT_EXAMPLES}

Respond with ONLY valid JSON in this exact format:
{
  "category": "drug_safety" | "new_research" | "treatment" | "nutrition" | "general",
  "pubmedRatio": 0.0 to 1.0,
  "medrxivRatio": 0.0 to 1.0,
  "clinicalTrialsRatio": 0.0 to 1.0,
  "confidence": 0.0 to 1.0
}

IMPORTANT: Ratios must sum to 1.0 (100%)`;
/**
 * Analyze query and return optimal API source distribution
 * @param query - User's question
 * @param targetSourceCount - Total number of API sources to fetch (e.g., 5 for T2, 15 for T3)
 * @returns QueryAnalysis with category and optimal API ratios
 */
async function analyzeQuery(query, targetSourceCount) {
    const startTime = Date.now();
    try {
        console.log(`🔍 [QUERY-ANALYZER] Analyzing query for ${targetSourceCount} sources: "${query.substring(0, 60)}..."`);
        const result = await genkit_instance_1.ai.generate({
            model: (0, providers_1.getRouterModel)(), // Gemini 2.5 Flash Lite - fast & cheap
            config: {
                temperature: 0.1, // Very low for consistent categorization
                maxOutputTokens: 256,
            },
            system: SYSTEM_PROMPT,
            prompt: `Query: "${query}"\n\nCategorize this query and provide optimal source distribution for ${targetSourceCount} total API sources.`
        });
        const responseText = result.text;
        // Parse JSON response
        let analysis;
        try {
            // Clean markdown code blocks if present
            const cleanedText = responseText
                .replace(/```json\n?/g, '')
                .replace(/```\n?/g, '')
                .trim();
            analysis = JSON.parse(cleanedText);
        }
        catch (parseError) {
            console.error('❌ [QUERY-ANALYZER] JSON parse failed, using fallback');
            return getFallbackAnalysis(query);
        }
        // Validate ratios sum to 1.0 (allow small floating point errors)
        const ratioSum = analysis.pubmedRatio + analysis.medrxivRatio + analysis.clinicalTrialsRatio;
        if (Math.abs(ratioSum - 1.0) > 0.01) {
            console.warn(`⚠️ [QUERY-ANALYZER] Ratios sum to ${ratioSum.toFixed(3)}, normalizing...`);
            // Normalize to sum to 1.0
            const normalized = {
                ...analysis,
                pubmedRatio: analysis.pubmedRatio / ratioSum,
                medrxivRatio: analysis.medrxivRatio / ratioSum,
                clinicalTrialsRatio: analysis.clinicalTrialsRatio / ratioSum
            };
            analysis = normalized;
        }
        const duration = Date.now() - startTime;
        console.log(`✅ [QUERY-ANALYZER] Categorized as "${analysis.category}" ` +
            `(PubMed: ${(analysis.pubmedRatio * 100).toFixed(0)}%, ` +
            `medRxiv: ${(analysis.medrxivRatio * 100).toFixed(0)}%, ` +
            `Trials: ${(analysis.clinicalTrialsRatio * 100).toFixed(0)}%) ` +
            `in ${duration}ms`);
        return analysis;
    }
    catch (error) {
        console.error('❌ [QUERY-ANALYZER] Analysis failed:', error.message);
        return getFallbackAnalysis(query);
    }
}
/**
 * Fallback analysis when AI categorization fails
 * Uses simple keyword matching for basic categorization
 */
function getFallbackAnalysis(query) {
    // Drug safety keywords
    if (/yan etki|etkileş|güvenli mi|side effect|interaction|contraindic|doz/i.test(query)) {
        return {
            category: 'drug_safety',
            pubmedRatio: 0.7,
            medrxivRatio: 0.1,
            clinicalTrialsRatio: 0.2,
            confidence: 0.6
        };
    }
    // New research keywords
    if (/latest|yeni|güncel|202[4-6]|breakthrough|recent|clinical trial/i.test(query)) {
        return {
            category: 'new_research',
            pubmedRatio: 0.5,
            medrxivRatio: 0.3,
            clinicalTrialsRatio: 0.2,
            confidence: 0.6
        };
    }
    // Nutrition keywords
    if (/beslenme|nutrition|diet|food|yemek|tarif|recipe|carb|protein/i.test(query)) {
        return {
            category: 'nutrition',
            pubmedRatio: 0.8,
            medrxivRatio: 0.15,
            clinicalTrialsRatio: 0.05,
            confidence: 0.6
        };
    }
    // Treatment keywords
    if (/tedavi|treatment|therapy|guideline|protocol|hedef|target/i.test(query)) {
        return {
            category: 'treatment',
            pubmedRatio: 0.65,
            medrxivRatio: 0.1,
            clinicalTrialsRatio: 0.25,
            confidence: 0.6
        };
    }
    // Default: General category with balanced distribution
    console.log('📊 [QUERY-ANALYZER] Using general fallback distribution');
    return {
        category: 'general',
        pubmedRatio: 0.55,
        medrxivRatio: 0.2,
        clinicalTrialsRatio: 0.25,
        confidence: 0.5
    };
}
/**
 * Calculate exact source counts from ratios
 * Ensures counts sum to targetSourceCount
 * @param analysis - Query analysis with ratios
 * @param targetSourceCount - Total sources needed
 * @returns Object with exact counts per API
 */
function calculateSourceCounts(analysis, targetSourceCount) {
    // Calculate raw counts
    const pubmedCount = Math.round(analysis.pubmedRatio * targetSourceCount);
    const medrxivCount = Math.round(analysis.medrxivRatio * targetSourceCount);
    let clinicalTrialsCount = Math.round(analysis.clinicalTrialsRatio * targetSourceCount);
    // Adjust to ensure exact sum
    const calculatedSum = pubmedCount + medrxivCount + clinicalTrialsCount;
    const diff = targetSourceCount - calculatedSum;
    if (diff !== 0) {
        // Add/subtract diff from the source with highest ratio
        const maxRatio = Math.max(analysis.pubmedRatio, analysis.medrxivRatio, analysis.clinicalTrialsRatio);
        if (maxRatio === analysis.pubmedRatio) {
            clinicalTrialsCount += diff; // Adjust clinicalTrials since it's calculated last
        }
        else if (maxRatio === analysis.medrxivRatio) {
            clinicalTrialsCount += diff;
        }
        else {
            clinicalTrialsCount += diff;
        }
    }
    // Ensure no negative counts
    const result = {
        pubmedCount: Math.max(0, pubmedCount),
        medrxivCount: Math.max(0, medrxivCount),
        clinicalTrialsCount: Math.max(0, clinicalTrialsCount)
    };
    console.log(`📊 [QUERY-ANALYZER] Source distribution: ` +
        `PubMed: ${result.pubmedCount}, medRxiv: ${result.medrxivCount}, Trials: ${result.clinicalTrialsCount}`);
    return result;
}
//# sourceMappingURL=query-analyzer.js.map