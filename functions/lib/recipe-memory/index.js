"use strict";
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
exports.generateRecipeWithMemory = void 0;
const https_1 = require("firebase-functions/v2/https");
const cors = __importStar(require("cors"));
const genkit_instance_1 = require("../genkit-instance");
const vector_utils_1 = require("../vector-utils");
const memory_store_1 = require("./memory-store");
const similarity_checker_1 = require("./similarity-checker");
const diversity_scorer_1 = require("./diversity-scorer");
// Configure CORS
const corsHandler = cors.default({
    origin: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
});
/**
 * Note: Recipe schema is now defined in prompts/recipe_chef_assistant.prompt
 * The .prompt file handles all schema validation and structured output
 */
/**
 * Generate recipe with Gemini AI using Genkit prompt file
 *
 * @param mealType - Type of meal
 * @param styleType - Style subcategory
 * @param diversityConstraints - Optional constraints from recent recipe history
 * @param temperature - Temperature override for generation (higher = more random)
 */
async function generateRecipe(mealType, styleType, diversityConstraints, temperature) {
    try {
        const tempStr = temperature ? ` (temp: ${temperature.toFixed(2)})` : '';
        console.log(`🎯 [RECIPE-GEN] Using prompt file with mealType: ${mealType}, styleType: ${styleType}${tempStr}`);
        if (diversityConstraints) {
            console.log(`   🎲 [DIVERSITY] Constraints applied:`);
            if (diversityConstraints.avoidCuisines.length > 0) {
                console.log(`      - Avoid cuisines: ${diversityConstraints.avoidCuisines.join(', ')}`);
            }
            if (diversityConstraints.avoidProteins.length > 0) {
                console.log(`      - Avoid proteins: ${diversityConstraints.avoidProteins.join(', ')}`);
            }
            if (diversityConstraints.suggestCuisines.length > 0) {
                console.log(`      - Suggest cuisines: ${diversityConstraints.suggestCuisines.join(', ')}`);
            }
            if (diversityConstraints.suggestProteins.length > 0) {
                console.log(`      - Suggest proteins: ${diversityConstraints.suggestProteins.join(', ')}`);
            }
        }
        // Load the .prompt file from prompts directory
        const recipeChefPrompt = genkit_instance_1.ai.prompt('recipe_chef_assistant');
        // Build config with optional temperature override
        const config = {};
        if (temperature !== undefined) {
            config.temperature = temperature;
        }
        // Execute the prompt with input parameters
        const response = await recipeChefPrompt({
            mealType,
            styleType,
            spontaneous: true,
            ingredients: [],
            diversityConstraints: diversityConstraints || undefined,
        }, config.temperature ? { config } : undefined);
        const recipe = response.output;
        if (!recipe) {
            throw new Error('No output from AI generation');
        }
        console.log(`✅ [RECIPE-GEN] Successfully generated recipe: ${recipe.name}`);
        console.log(`   Cuisine: ${recipe.metadata?.cuisine || 'N/A'}, Protein: ${recipe.metadata?.primaryProtein || 'N/A'}, Method: ${recipe.metadata?.cookingMethod || 'N/A'}`);
        console.log(`   Ingredients: ${recipe.ingredients?.length || 0}, Instructions: ${recipe.instructions?.length || 0}`);
        console.log(`   Servings: ${recipe.servings}, Prep: ${recipe.prepTime}min, Cook: ${recipe.cookTime}min`);
        return recipe;
    }
    catch (error) {
        console.error('❌ [RECIPE-GEN] Generation failed:', error);
        return null;
    }
}
/**
 * Main Cloud Function: Generate recipe with memory-based deduplication
 * Now using onRequest for direct HTTP POST compatibility with iOS URLSession
 */
exports.generateRecipeWithMemory = (0, https_1.onRequest)({
    timeoutSeconds: 120,
    memory: '512MiB',
    cpu: 1,
    concurrency: 2
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            // Validate request method
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed. Use POST.' });
                return;
            }
            const startTime = Date.now();
            const data = req.body;
            // No authentication required - personal app with hardcoded user IDs
            // Users: "serhat" and "wife" - data separation by userId in Firestore
            const { mealType, styleType, userId, conversationId, maxRetries = 3, // Increased for diversity checks
            similarityThreshold: baseSimilarityThreshold = 0.85, temporalWindowDays = 14, } = data;
            // Category-specific configuration
            // Different meal types have different variety expectations
            const categoryConfig = {
                "Kahvaltı": {
                    similarityThreshold: 0.85, // Relaxed - limited natural variety
                    diversityThreshold: 0.50,
                    qualityBar: "practical & diabetes-friendly"
                },
                "Akşam Yemeği": {
                    similarityThreshold: 0.85, // Relaxed to allow more variety
                    diversityThreshold: 0.55, // Moderate - balance variety with practicality
                    qualityBar: "interesting & worth making"
                },
                "Salatalar": {
                    similarityThreshold: 0.85, // Relaxed - limited natural variety in salads
                    diversityThreshold: 0.50, // Lower bar - focus on freshness over novelty
                    qualityBar: "fresh & complete"
                },
                "Tatlılar": {
                    similarityThreshold: 0.80, // Relaxed - diabetes-friendly desserts have limited variety
                    diversityThreshold: 0.55, // Moderate - balance surprise with practical constraints
                    qualityBar: "surprising & delicious"
                },
                "Atıştırmalıklar": {
                    similarityThreshold: 0.80, // Relaxed - snacks have limited variety
                    diversityThreshold: 0.50, // Lower bar - focus on being satisfying
                    qualityBar: "creative & satisfying"
                }
            };
            // Get category-specific config or use defaults
            const config = categoryConfig[mealType] || {
                similarityThreshold: baseSimilarityThreshold,
                diversityThreshold: 0.60,
                qualityBar: "good quality"
            };
            const similarityThreshold = config.similarityThreshold;
            const diversityThreshold = config.diversityThreshold;
            // Validate required fields
            if (!mealType || !styleType || !userId || !conversationId) {
                res.status(400).json({
                    success: false,
                    error: 'Missing required fields: mealType, styleType, userId, or conversationId'
                });
                return;
            }
            console.log(`🍳 [RECIPE-GEN] Starting generation for user ${userId}`);
            // Step 1: Fetch recent recipes
            const recentRecipes = await (0, memory_store_1.getRecentRecipes)(userId, temporalWindowDays);
            console.log(`📚 [RECIPE-GEN] Found ${recentRecipes.length} recent recipes (last ${temporalWindowDays} days)`);
            // Step 2: Build initial diversity constraints from recipe history
            const baseConstraints = recentRecipes.length > 0
                ? (0, diversity_scorer_1.buildDiversityConstraints)(recentRecipes, 10)
                : null;
            if (baseConstraints) {
                console.log(`🎲 [DIVERSITY] Built constraints from ${recentRecipes.length} recent recipes`);
            }
            let recipe = null;
            let attempts = 0;
            let maxSimilarity = 0;
            let diversityScore = null;
            // Step 3: Generation loop with constraint-based diversity and adaptive temperature
            while (attempts < maxRetries) {
                attempts++;
                // Calculate adaptive temperature: 0.7 → 0.9 → 1.1
                // Higher temperature on retries increases randomness and diversity
                const temperature = 0.5 + (attempts * 0.2); // 0.7, 0.9, 1.1
                console.log(`🎲 [RECIPE-GEN] Attempt ${attempts}/${maxRetries} - Generating recipe (temp: ${temperature.toFixed(2)})...`);
                // Generate recipe with constraints and adaptive temperature
                recipe = await generateRecipe(mealType, styleType, baseConstraints || undefined, temperature);
                if (!recipe) {
                    throw new Error('Recipe generation returned null');
                }
                console.log(`✨ [RECIPE-GEN] Generated: "${recipe.name}"`);
                // Generate embedding for similarity check
                // Use aiNotes instead of description (description is optional now)
                const embeddingText = `${recipe.name}. ${recipe.aiNotes.substring(0, 200)}`;
                const embedding = await (0, vector_utils_1.generateEmbedding)(embeddingText);
                console.log(`🔮 [RECIPE-GEN] Generated embedding (${embedding.length}D)`);
                // Check similarity against recent recipes
                const similarityCheck = (0, similarity_checker_1.checkRecipeSimilarity)(embedding, recentRecipes, similarityThreshold);
                maxSimilarity = similarityCheck.maxSimilarity;
                // Calculate diversity score (Phase 3)
                diversityScore = (0, diversity_scorer_1.calculateDiversityScore)(recipe, recentRecipes, maxSimilarity);
                console.log(`📊 [DIVERSITY] Score: ${diversityScore.overallScore.toFixed(3)} ` +
                    `(similarity: ${(1 - maxSimilarity).toFixed(3)}, ` +
                    `cuisine: ${diversityScore.cuisineVariety.toFixed(2)}, ` +
                    `protein: ${diversityScore.proteinDiversity.toFixed(2)})`);
                // Accept if BOTH similarity AND diversity pass
                const passedSimilarity = !similarityCheck.isSimilar;
                const passedDiversity = diversityScore.overallScore >= diversityThreshold;
                if (passedSimilarity && passedDiversity) {
                    // Success! Recipe meets both criteria
                    console.log(`✅ [RECIPE-GEN] Recipe accepted on attempt ${attempts}\n` +
                        `   Similarity: ${maxSimilarity.toFixed(3)} < ${similarityThreshold}\n` +
                        `   Diversity: ${diversityScore.overallScore.toFixed(3)} >= ${diversityThreshold}\n` +
                        `   Strengths: ${diversityScore.strengths.join(', ')}`);
                    // Save to memory
                    const recipeId = await (0, memory_store_1.saveRecipeMemory)({
                        userId,
                        conversationId,
                        recipe,
                        embedding,
                        generationAttempt: attempts,
                        wasRetried: attempts > 1,
                    });
                    const latencyMs = Date.now() - startTime;
                    // HTTP response
                    res.json({
                        success: true,
                        recipe: { ...recipe, id: recipeId },
                        recipeId,
                        metadata: {
                            wasRetried: attempts > 1,
                            attempts,
                            similarityScore: maxSimilarity,
                            latencyMs,
                            recentRecipesChecked: recentRecipes.length,
                        },
                    });
                    return;
                }
                // Failed similarity or diversity check, retry needed
                const reasons = [];
                if (!passedSimilarity) {
                    reasons.push(`similarity too high (${maxSimilarity.toFixed(3)} >= ${similarityThreshold})`);
                }
                if (!passedDiversity) {
                    reasons.push(`diversity too low (${diversityScore.overallScore.toFixed(3)} < ${diversityThreshold})`);
                    if (diversityScore.weaknesses.length > 0) {
                        reasons.push(`weaknesses: ${diversityScore.weaknesses.join(', ')}`);
                    }
                }
                console.log(`⚠️ [RECIPE-GEN] Recipe rejected - ${reasons.join('; ')}. ` +
                    `Retrying with higher temperature and same constraints (attempt ${attempts}/${maxRetries})...`);
            }
            // Max retries reached - DO NOT SAVE TO DATABASE
            // This prevents polluting recipe memory with 97% similar recipes
            console.error(`❌ [RECIPE-GEN] Max retries (${maxRetries}) reached. ` +
                `Recipe still too similar (similarity: ${maxSimilarity.toFixed(3)}, diversity: ${diversityScore?.overallScore.toFixed(3)})`);
            if (diversityScore) {
                console.error(`   Diversity breakdown: ` +
                    `cuisine=${diversityScore.cuisineVariety.toFixed(2)}, ` +
                    `protein=${diversityScore.proteinDiversity.toFixed(2)}, ` +
                    `method=${diversityScore.cookingMethodVariety.toFixed(2)}, ` +
                    `ingredients=${diversityScore.ingredientNovelty.toFixed(2)}`);
            }
            // Return error to client instead of saving garbage
            res.status(409).json({
                success: false,
                error: 'DIVERSITY_FAILURE',
                message: 'Could not generate sufficiently diverse recipe after multiple attempts',
                details: {
                    attempts: maxRetries,
                    similarityScore: maxSimilarity,
                    similarityThreshold,
                    diversityScore: diversityScore?.overallScore,
                    diversityThreshold,
                    weaknesses: diversityScore?.weaknesses || [],
                    suggestions: [
                        'Try a different meal type or style',
                        'Wait a bit and try again later',
                        'Some categories naturally have less variety'
                    ]
                },
                metadata: {
                    wasRetried: true,
                    attempts: maxRetries,
                    recentRecipesChecked: recentRecipes.length,
                }
            });
            return;
        }
        catch (error) {
            console.error('❌ [RECIPE-GEN] Fatal error:', error);
            if (!res.headersSent) {
                res.status(500).json({
                    success: false,
                    error: 'Recipe generation failed',
                    message: error.message || 'Unknown error occurred',
                    timestamp: new Date().toISOString()
                });
            }
        }
    });
});
//# sourceMappingURL=index.js.map