"use strict";
//
// Balli Diabetes Assistant - Enhanced with Memory Management
// Implements short-term and long-term memory with summarization
//
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
exports.calculateRecipeNutrition = exports.generateSessionMetadata = exports.diabetesAssistantStream = exports.transcribeMeal = exports.extractNutritionFromImage = exports.generateRecipePhoto = exports.generateSpontaneousRecipe = exports.generateRecipeFromIngredients = void 0;
// Load environment variables first (required for development)
require("dotenv/config");
const admin = __importStar(require("firebase-admin"));
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const cors = __importStar(require("cors"));
const genkit_1 = require("genkit");
const providers_1 = require("./providers");
const cache_manager_1 = require("./cache-manager");
const genkit_instance_1 = require("./genkit-instance");
// Removed extractMainIngredients - using markdown parsing instead
const cost_tracker_1 = require("./cost-tracking/cost-tracker");
const model_pricing_1 = require("./cost-tracking/model-pricing");
// Initialize Firebase Admin (guard against duplicate initialization in tests)
if (!admin.apps.length) {
    (0, app_1.initializeApp)();
}
const db = (0, firestore_1.getFirestore)();
// DO NOT export ai instance - it contains circular references that break Firebase deployment
// The ai instance from genkit-instance is only for internal use within flows
// External consumers should NOT import ai from this module
// Log provider configuration on startup
(0, providers_1.logProviderSwitch)();
// Warm up caches on cold start (async, non-blocking)
setImmediate(async () => {
    try {
        await cache_manager_1.cacheManager.warmupCaches();
        console.log('🔥 [STARTUP] Cache warmup completed');
    }
    catch (error) {
        console.warn('⚠️ [STARTUP] Cache warmup failed, continuing without cache:', error);
    }
});
/**
 * Extract ingredients from markdown recipe content
 * Parses the ## Malzemeler section and extracts ingredient names
 */
function extractIngredientsFromMarkdown(markdown) {
    const ingredients = [];
    // Find the Malzemeler section
    const malzemelerMatch = markdown.match(/##\s*Malzemeler\s*\n---\n([\s\S]*?)(?=\n##|\n$)/);
    if (!malzemelerMatch) {
        console.warn('⚠️ [INGREDIENT-EXTRACT] Could not find Malzemeler section in markdown');
        return ingredients;
    }
    const malzemelerSection = malzemelerMatch[1];
    const lines = malzemelerSection.split('\n');
    for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('- ')) {
            // Extract ingredient line: "- 120g tavuk göğsü (küçük parçalar halinde doğranmış)"
            const ingredientText = trimmed.substring(2).trim();
            // Remove weight/measurement at start (e.g., "120g", "1 yemek kaşığı")
            const withoutWeight = ingredientText.replace(/^[\d/.]+\s*(g|ml|kg|adet|çay kaşığı|yemek kaşığı|su bardağı)?\s*/i, '');
            // Extract main ingredient name before parentheses or commas
            const mainIngredient = withoutWeight.split(/[,(]/)[0].trim();
            if (mainIngredient && mainIngredient.length > 2) {
                ingredients.push(mainIngredient);
            }
        }
    }
    console.log(`🥕 [INGREDIENT-EXTRACT] Extracted ${ingredients.length} ingredients: ${ingredients.slice(0, 5).join(', ')}${ingredients.length > 5 ? '...' : ''}`);
    return ingredients;
}
// Configure CORS
const corsHandler = cors.default({
    origin: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
});
// ============================================
// RECIPE GENERATION FLOWS
// ============================================
// Recipe generation flow using ingredients
const generateRecipeFromIngredientsFlow = genkit_instance_1.ai.defineFlow({
    name: 'generateRecipeFromIngredients',
    inputSchema: genkit_1.z.object({
        ingredients: genkit_1.z.array(genkit_1.z.string()).describe('List of available ingredients'),
        mealType: genkit_1.z.string().describe('Type of meal (Kahvaltı, Akşam Yemeği, Salatalar, Tatlılar, Atıştırmalıklar)'),
        styleType: genkit_1.z.string().describe('Style subcategory for the meal type'),
        userId: genkit_1.z.string().optional().describe('User ID for personalization'),
        userContext: genkit_1.z.string().optional().describe('Optional user context or notes for recipe generation (e.g., "diabetes-friendly tiramisu")')
    }),
    outputSchema: genkit_1.z.object({
        recipeName: genkit_1.z.string(),
        prepTime: genkit_1.z.string(),
        cookTime: genkit_1.z.string(),
        ingredients: genkit_1.z.array(genkit_1.z.string()), // Legacy: kept for backward compatibility
        directions: genkit_1.z.array(genkit_1.z.string()), // Legacy: kept for backward compatibility
        notes: genkit_1.z.string(),
        recipeContent: genkit_1.z.string().optional(), // NEW: Markdown content (ingredients + directions)
        servings: genkit_1.z.string().optional() // Number of servings for nutrition calculation
    })
}, async (input) => {
    try {
        console.log(`🍳 [RECIPE] Generating recipe from ingredients: ${input.ingredients.join(', ')}`);
        const recipePrompt = genkit_instance_1.ai.prompt('recipe_chef_assistant');
        const response = await recipePrompt({
            mealType: input.mealType,
            styleType: input.styleType,
            ingredients: input.ingredients,
            spontaneous: false,
            userContext: input.userContext
        }, {
            model: (0, providers_1.getRecipeModel)() // Use provider-specific model for caching
        });
        // Track cost for recipe generation
        const tokenCounts = (0, cost_tracker_1.extractTokenCounts)(response);
        await (0, cost_tracker_1.logTokenUsage)({
            featureName: model_pricing_1.FeatureName.RECIPE_GENERATION,
            modelName: (0, providers_1.getRecipeModel)(),
            inputTokens: tokenCounts.inputTokens,
            outputTokens: tokenCounts.outputTokens,
            userId: input.userId,
            metadata: { mealType: input.mealType, styleType: input.styleType }
        });
        // Transform the response to match iOS app's expected format
        const promptOutput = response.output;
        return {
            recipeName: promptOutput.name || promptOutput.recipeName || '',
            prepTime: String(promptOutput.prepTime || '0'),
            cookTime: String(promptOutput.cookTime || '0'),
            // Legacy arrays: kept for backward compatibility (parse from recipeContent if needed)
            ingredients: Array.isArray(promptOutput.ingredients)
                ? promptOutput.ingredients.map((ing) => typeof ing === 'string' ? ing : `${ing.quantity || ''} ${ing.item || ''}`.trim())
                : [],
            directions: promptOutput.instructions || promptOutput.directions || [],
            notes: promptOutput.notes || promptOutput.aiNotes || '', // AI Chef notes (separate from recipeContent)
            recipeContent: promptOutput.recipeContent || '', // NEW: Markdown content (ingredients + directions)
            servings: String(promptOutput.servings || '4') // Number of servings for on-demand nutrition calculation
        };
    }
    catch (error) {
        console.error('❌ Recipe generation from ingredients failed:', error);
        throw error;
    }
});
// Aspect ratio configuration for optimal composition
const ASPECT_RATIO_CONFIG = {
    '16:9': {
        promptModifier: 'Wide landscape orientation perfect for web display and recipe cards. Position main dish slightly left of center with elegant side garnishes.',
        description: 'Landscape format ideal for web and desktop viewing'
    },
    '4:3': {
        promptModifier: 'Classic photography ratio with balanced composition. Center the main dish with natural styling and complementary props.',
        description: 'Traditional format perfect for print and versatile display'
    },
    '1:1': {
        promptModifier: 'Square format optimized for social media. Tight crop on the main dish with minimal negative space and bold presentation.',
        description: 'Instagram-optimized square format'
    },
    '9:16': {
        promptModifier: 'Vertical portrait orientation for mobile-first experience. Stack elements vertically with the main dish prominently featured.',
        description: 'Mobile-optimized vertical format'
    }
};
// Recipe photo generation flow using Imagen 4 Ultra with enhanced quality parameters
const generateRecipePhotoFlow = genkit_instance_1.ai.defineFlow({
    name: 'generateRecipePhoto',
    inputSchema: genkit_1.z.object({
        recipeName: genkit_1.z.string().describe('Name of the recipe to photograph'),
        ingredients: genkit_1.z.array(genkit_1.z.string()).describe('List of ingredients in the recipe'),
        directions: genkit_1.z.array(genkit_1.z.string()).describe('Cooking instructions for reference'),
        mealType: genkit_1.z.string().describe('Type of meal (Kahvaltı, Akşam Yemeği, Salatalar, Tatlılar, Atıştırmalıklar)'),
        styleType: genkit_1.z.string().describe('Style subcategory for the meal'),
        aspectRatio: genkit_1.z.enum(['16:9', '4:3', '1:1', '9:16']).optional().default('1:1').describe('Aspect ratio for optimal composition'),
        qualityLevel: genkit_1.z.enum(['standard', 'high', 'ultra']).optional().default('ultra').describe('Generation quality level'),
        resolution: genkit_1.z.enum(['1K', '2K']).optional().default('2K').describe('Image resolution (1K=1024x768, 2K=2048x1536)'),
        userId: genkit_1.z.string().optional().describe('User ID for analytics')
    }),
    outputSchema: genkit_1.z.object({
        imageUrl: genkit_1.z.string().describe('URL or base64 data of the generated image'),
        prompt: genkit_1.z.string().describe('The enhanced prompt used for generation'),
        generationTime: genkit_1.z.string().describe('Time taken for generation'),
        metadata: genkit_1.z.object({
            aspectRatio: genkit_1.z.string(),
            qualityLevel: genkit_1.z.string(),
            resolution: genkit_1.z.string()
        }).describe('Generation metadata for reproducibility')
    })
}, async (input) => {
    try {
        console.log(`📸 [PHOTO] Generating ${input.qualityLevel} quality photo for recipe: ${input.recipeName} (${input.aspectRatio}, ${input.resolution})`);
        const startTime = Date.now();
        // Get aspect ratio configuration
        const aspectRatioConfig = ASPECT_RATIO_CONFIG[input.aspectRatio || '1:1'];
        console.log(`📐 [PHOTO] Using aspect ratio: ${input.aspectRatio}, resolution: ${input.resolution}`);
        const photoPrompt = genkit_instance_1.ai.prompt('recipe_photo_generation');
        const response = await photoPrompt({
            recipeName: input.recipeName,
            ingredients: input.ingredients,
            directions: input.directions,
            mealType: input.mealType,
            styleType: input.styleType,
            aspectRatio: input.aspectRatio || '4:3',
            compositionModifier: aspectRatioConfig.promptModifier
        });
        const generationTime = ((Date.now() - startTime) / 1000).toFixed(2);
        // Check if response contains media
        if (response.media?.url) {
            console.log(`✅ [PHOTO] Generated ${input.qualityLevel} quality photo for ${input.recipeName} in ${generationTime}s`);
            let imageUrl = response.media.url;
            console.log(`🔍 [PHOTO] Original image URL format: ${imageUrl.substring(0, 100)}...`);
            // iOS expects data: URLs for base64 images
            // Convert Genkit response to data URL format if needed
            if (!imageUrl.startsWith('data:')) {
                // If it's a gs:// or https:// URL, we need to download and convert to base64
                if (imageUrl.startsWith('gs://') || imageUrl.startsWith('https://')) {
                    console.log(`📥 [PHOTO] Downloading image from URL to convert to base64...`);
                    try {
                        // Download the image
                        const fetch = (await Promise.resolve().then(() => __importStar(require('node-fetch')))).default;
                        const imageResponse = await fetch(imageUrl);
                        if (!imageResponse.ok) {
                            throw new Error(`Failed to download image: ${imageResponse.statusText}`);
                        }
                        // Convert to base64
                        const arrayBuffer = await imageResponse.arrayBuffer();
                        const base64Data = Buffer.from(arrayBuffer).toString('base64');
                        imageUrl = `data:image/jpeg;base64,${base64Data}`;
                        console.log(`✅ [PHOTO] Converted to base64 data URL (${base64Data.length} chars)`);
                    }
                    catch (downloadError) {
                        console.error(`❌ [PHOTO] Failed to download and convert image:`, downloadError);
                        throw new Error(`Failed to process generated image: ${downloadError}`);
                    }
                }
                else {
                    // Assume it's raw base64 without prefix
                    console.log(`🔧 [PHOTO] Adding data: prefix to raw base64`);
                    imageUrl = `data:image/jpeg;base64,${imageUrl}`;
                }
            }
            console.log(`✅ [PHOTO] Final image URL format: ${imageUrl.substring(0, 50)}...`);
            // Track cost for image generation (Imagen models are priced per image, not tokens)
            await (0, cost_tracker_1.logImageUsage)({
                featureName: model_pricing_1.FeatureName.IMAGE_GENERATION,
                modelName: 'imagen-4.0-ultra', // Using Imagen 4 Ultra
                imageCount: 1,
                userId: input.userId,
                metadata: {
                    recipeName: input.recipeName,
                    aspectRatio: input.aspectRatio || '4:3',
                    qualityLevel: input.qualityLevel || 'ultra',
                    resolution: input.resolution || '2K'
                }
            });
            // Build enhanced prompt description for transparency
            const enhancedPromptDesc = `Ultra-high quality professional food photography of ${input.recipeName} using Canon EOS R5, ${input.aspectRatio} aspect ratio, with ${aspectRatioConfig.description.toLowerCase()}`;
            return {
                imageUrl: imageUrl,
                prompt: enhancedPromptDesc,
                generationTime: `${generationTime}s`,
                metadata: {
                    aspectRatio: input.aspectRatio || '4:3',
                    qualityLevel: input.qualityLevel || 'ultra',
                    resolution: input.resolution || '2K'
                }
            };
        }
        else {
            throw new Error('No image generated in response');
        }
    }
    catch (error) {
        console.error('❌ Recipe photo generation failed:', error);
        throw error;
    }
});
// Note: Old Genkit-based nutrition extraction flow removed
// Replaced with direct Gemini API implementation in nutrition-extractor.ts
// This eliminates 50+ lines of complex fallback parsing and provides 99%+ JSON reliability
// ============================================
// RECIPE GENERATION ENDPOINTS
// ============================================
// Endpoint: Generate recipe from ingredients with streaming
exports.generateRecipeFromIngredients = (0, https_1.onRequest)({
    timeoutSeconds: 300,
    memory: '512MiB',
    cpu: 1,
    concurrency: 2
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed' });
                return;
            }
            const { ingredients, mealType, styleType, userId, streamingEnabled } = req.body;
            if (!ingredients || !mealType || !styleType) {
                res.status(400).json({ error: 'ingredients, mealType, and styleType are required' });
                return;
            }
            // Set up streaming if requested
            if (streamingEnabled) {
                res.writeHead(200, {
                    'Content-Type': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Cache-Control'
                });
                // Send connected event
                const connectedEvent = {
                    type: "connected",
                    data: { status: "connected", message: "Recipe generation started" },
                    timestamp: new Date().toISOString()
                };
                res.write(`event: connected\ndata: ${JSON.stringify(connectedEvent)}\n\n`);
                try {
                    // Use streaming version of the prompt
                    const recipePrompt = genkit_instance_1.ai.prompt('recipe_chef_assistant');
                    const streamingResponse = await recipePrompt.stream({
                        mealType,
                        styleType,
                        ingredients,
                        spontaneous: false
                    }, {
                        model: (0, providers_1.getRecipeModel)() // Use provider-specific model for caching
                    });
                    let fullContent = '';
                    let tokenCount = 0;
                    for await (const chunk of streamingResponse.stream) {
                        const chunkText = chunk.text;
                        if (chunkText) {
                            // Split large chunks into smaller word-based pieces for smooth streaming
                            // This ensures character-by-character animation on the client
                            const words = chunkText.split(/(\s+)/); // Split by whitespace but keep the spaces
                            for (const word of words) {
                                if (word) {
                                    fullContent += word;
                                    tokenCount++;
                                    // Send small word-based chunk to client
                                    const chunkEvent = {
                                        type: "chunk",
                                        data: {
                                            content: word,
                                            fullContent: fullContent,
                                            tokenCount: tokenCount
                                        },
                                        timestamp: new Date().toISOString()
                                    };
                                    res.write(`event: chunk\ndata: ${JSON.stringify(chunkEvent)}\n\n`);
                                    // CRITICAL: Flush immediately to send chunk to client without buffering
                                    if (typeof res.flush === 'function') {
                                        res.flush();
                                    }
                                    // Smaller delay for word-by-word streaming (smooth animation)
                                    await new Promise(resolve => setTimeout(resolve, 30));
                                }
                            }
                        }
                    }
                    // Parse metadata from markdown
                    // Format: # Recipe Name\n**Hazırlık:** X dakika | **Pişirme:** X dakika | **Porsiyon:** 1 kişi
                    const lines = fullContent.split('\n');
                    let recipeName = 'Tarif';
                    let prepTime = 15;
                    let cookTime = 20;
                    // Extract recipe name from first line (# Recipe Name)
                    if (lines[0]?.startsWith('# ')) {
                        recipeName = lines[0].substring(2).trim();
                    }
                    // Extract times from second line
                    const timeLine = lines[1] || '';
                    const prepMatch = timeLine.match(/\*\*Hazırlık:\*\*\s*(\d+)\s*dakika/i);
                    const cookMatch = timeLine.match(/\*\*Pişirme:\*\*\s*(\d+)\s*dakika/i);
                    if (prepMatch)
                        prepTime = parseInt(prepMatch[1]);
                    if (cookMatch)
                        cookTime = parseInt(cookMatch[1]);
                    console.log(`📝 [MARKDOWN-PARSE] Extracted: name="${recipeName}", prep=${prepTime}min, cook=${cookTime}min`);
                    // Send completion event with markdown content
                    const recipeData = {
                        recipeName: recipeName,
                        name: recipeName, // Alias for compatibility
                        recipeContent: fullContent, // The full markdown content
                        prepTime: prepTime,
                        cookTime: cookTime,
                        servings: 1,
                        tokenCount: tokenCount,
                        // Extract ingredients for memory system (parse from markdown)
                        extractedIngredients: extractIngredientsFromMarkdown(fullContent),
                        // Empty nutrition fields - will be calculated on-demand by iOS
                        calories: "",
                        carbohydrates: "",
                        fiber: "",
                        protein: "",
                        fat: "",
                        sugar: "",
                        glycemicLoad: ""
                    };
                    console.log(`📊 [NUTRITION-CHECK] Recipe data nutrition fields: calories="${recipeData.calories}", carbs="${recipeData.carbohydrates}", protein="${recipeData.protein}"`);
                    const completedEvent = {
                        type: "completed",
                        data: recipeData,
                        timestamp: new Date().toISOString()
                    };
                    // Write the completion event
                    res.write(`event: completed\ndata: ${JSON.stringify(completedEvent)}\n\n`);
                    // CRITICAL FIX: Ensure the buffer is flushed before ending
                    // Without this, the last SSE event may be truncated
                    if (typeof res.flush === 'function') {
                        res.flush();
                    }
                    // End the response stream
                    res.end();
                }
                catch (error) {
                    console.error('❌ [RECIPE] Streaming error:', error);
                    const errorEvent = {
                        type: "error",
                        data: {
                            error: "Recipe generation failed",
                            message: error instanceof Error ? error.message : "Unknown error"
                        },
                        timestamp: new Date().toISOString()
                    };
                    res.write(`event: error\ndata: ${JSON.stringify(errorEvent)}\n\n`);
                    res.end();
                }
            }
            else {
                // Non-streaming response
                const result = await generateRecipeFromIngredientsFlow({
                    ingredients,
                    mealType,
                    styleType,
                    userId: userId || 'anonymous'
                });
                res.json({
                    success: true,
                    data: result
                });
            }
        }
        catch (error) {
            console.error('❌ Generate recipe from ingredients error:', error);
            if (!res.headersSent) {
                res.status(500).json({
                    success: false,
                    error: 'Failed to generate recipe from ingredients'
                });
            }
        }
    });
});
// Endpoint: Generate spontaneous recipe with streaming
exports.generateSpontaneousRecipe = (0, https_1.onRequest)({
    timeoutSeconds: 300,
    memory: '512MiB',
    cpu: 1,
    concurrency: 2
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed' });
                return;
            }
            const { mealType, memoryEntries, diversityConstraints, userContext } = req.body;
            let { styleType, recentRecipes } = req.body;
            if (!mealType) {
                res.status(400).json({ error: 'mealType is required' });
                return;
            }
            // For categories without subcategories (Kahvaltı, Atıştırmalık), use mealType as styleType
            if (!styleType || styleType.trim() === '') {
                styleType = mealType;
                console.log(`📝 [ENDPOINT] No styleType provided, using mealType as styleType: "${styleType}"`);
            }
            // Log memory info if provided
            if (memoryEntries && Array.isArray(memoryEntries) && memoryEntries.length > 0) {
                console.log(`📚 [ENDPOINT] Received ${memoryEntries.length} memory entries for diversity`);
            }
            // Log diversity constraints if provided
            if (diversityConstraints) {
                console.log(`🎯 [ENDPOINT] Received diversity constraints:`);
                if (diversityConstraints.avoidProteins) {
                    console.log(`   ❌ Avoid proteins: ${diversityConstraints.avoidProteins.join(', ')}`);
                }
                if (diversityConstraints.suggestProteins) {
                    console.log(`   ✅ Suggest proteins: ${diversityConstraints.suggestProteins.join(', ')}`);
                }
            }
            // Extract recent recipes if provided
            if (!recentRecipes) {
                recentRecipes = [];
            }
            // Always use streaming
            res.writeHead(200, {
                'Content-Type': 'text/event-stream',
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Cache-Control'
            });
            // Send connected event
            const connectedEvent = {
                type: "connected",
                data: { status: "connected", message: "Recipe generation started" },
                timestamp: new Date().toISOString()
            };
            res.write(`event: connected\ndata: ${JSON.stringify(connectedEvent)}\n\n`);
            try {
                // Use streaming version of the prompt
                const recipePrompt = genkit_instance_1.ai.prompt('recipe_chef_assistant');
                const streamingResponse = await recipePrompt.stream({
                    mealType,
                    styleType,
                    spontaneous: true,
                    recentRecipes: recentRecipes || [],
                    diversityConstraints: diversityConstraints || undefined,
                    userContext: userContext
                }, {
                    model: (0, providers_1.getRecipeModel)() // Use provider-specific model for caching
                });
                let fullContent = '';
                let tokenCount = 0;
                for await (const chunk of streamingResponse.stream) {
                    const chunkText = chunk.text;
                    if (chunkText) {
                        // Split large chunks into smaller word-based pieces for smooth streaming
                        // This ensures character-by-character animation on the client
                        const words = chunkText.split(/(\s+)/); // Split by whitespace but keep the spaces
                        for (const word of words) {
                            if (word) {
                                fullContent += word;
                                tokenCount++;
                                // Send small word-based chunk to client
                                const chunkEvent = {
                                    type: "chunk",
                                    data: {
                                        content: word,
                                        fullContent: fullContent,
                                        tokenCount: tokenCount
                                    },
                                    timestamp: new Date().toISOString()
                                };
                                res.write(`event: chunk\ndata: ${JSON.stringify(chunkEvent)}\n\n`);
                                // CRITICAL: Flush immediately to send chunk to client without buffering
                                if (typeof res.flush === 'function') {
                                    res.flush();
                                }
                                // Smaller delay for word-by-word streaming (smooth animation)
                                await new Promise(resolve => setTimeout(resolve, 30));
                            }
                        }
                    }
                }
                // Parse metadata from markdown (same as ingredients-based generation)
                const lines = fullContent.split('\n');
                let recipeName = 'Tarif';
                let prepTime = 15;
                let cookTime = 20;
                // Extract recipe name from first line (# Recipe Name)
                if (lines[0]?.startsWith('# ')) {
                    recipeName = lines[0].substring(2).trim();
                }
                // Extract times from second line
                const timeLine = lines[1] || '';
                const prepMatch = timeLine.match(/\*\*Hazırlık:\*\*\s*(\d+)\s*dakika/i);
                const cookMatch = timeLine.match(/\*\*Pişirme:\*\*\s*(\d+)\s*dakika/i);
                if (prepMatch)
                    prepTime = parseInt(prepMatch[1]);
                if (cookMatch)
                    cookTime = parseInt(cookMatch[1]);
                console.log(`📝 [MARKDOWN-PARSE] Extracted: name="${recipeName}", prep=${prepTime}min, cook=${cookTime}min`);
                // Extract ingredients from markdown
                const extractedIngredients = extractIngredientsFromMarkdown(fullContent);
                // Send completion event with markdown content
                const recipeData = {
                    recipeName: recipeName,
                    name: recipeName, // Alias for compatibility
                    recipeContent: fullContent, // The full markdown content
                    prepTime: prepTime,
                    cookTime: cookTime,
                    servings: 1,
                    tokenCount: tokenCount,
                    extractedIngredients, // For iOS memory system
                    // Empty nutrition fields - will be calculated on-demand by iOS
                    calories: "",
                    carbohydrates: "",
                    fiber: "",
                    protein: "",
                    fat: "",
                    sugar: "",
                    glycemicLoad: ""
                };
                console.log(`📊 [NUTRITION-CHECK] Recipe data nutrition fields: calories="${recipeData.calories}", carbs="${recipeData.carbohydrates}", protein="${recipeData.protein}"`);
                const completedEvent = {
                    type: "completed",
                    data: recipeData,
                    timestamp: new Date().toISOString()
                };
                // Write the completion event
                res.write(`event: completed\ndata: ${JSON.stringify(completedEvent)}\n\n`);
                // CRITICAL FIX: Ensure the buffer is flushed before ending
                // Without this, the last SSE event may be truncated
                if (typeof res.flush === 'function') {
                    res.flush();
                }
                // End the response stream
                res.end();
            }
            catch (error) {
                console.error('❌ [RECIPE] Streaming error:', error);
                const errorEvent = {
                    type: "error",
                    data: {
                        error: "Recipe generation failed",
                        message: error instanceof Error ? error.message : "Unknown error"
                    },
                    timestamp: new Date().toISOString()
                };
                res.write(`event: error\ndata: ${JSON.stringify(errorEvent)}\n\n`);
                res.end();
            }
        }
        catch (error) {
            console.error('❌ Generate spontaneous recipe error:', error);
            if (!res.headersSent) {
                res.status(500).json({
                    success: false,
                    error: 'Failed to generate spontaneous recipe'
                });
            }
        }
    });
});
// Endpoint: Generate recipe photo using Imagen 4 Ultra
exports.generateRecipePhoto = (0, https_1.onRequest)({
    timeoutSeconds: 180,
    memory: '512MiB',
    cpu: 1,
    concurrency: 2
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed' });
                return;
            }
            const { recipeName, ingredients, directions, mealType, styleType, userId } = req.body;
            if (!recipeName || !ingredients || !directions || !mealType || !styleType) {
                res.status(400).json({
                    error: 'recipeName, ingredients, directions, mealType, and styleType are required'
                });
                return;
            }
            console.log(`📸 [PHOTO] Starting photo generation for: ${recipeName}`);
            const result = await generateRecipePhotoFlow({
                recipeName,
                ingredients,
                directions,
                mealType,
                styleType,
                aspectRatio: req.body.aspectRatio || '1:1',
                qualityLevel: req.body.qualityLevel || 'ultra',
                resolution: req.body.resolution || '2K',
                userId: userId || 'anonymous'
            });
            res.json({
                success: true,
                data: {
                    imageUrl: result.imageUrl,
                    prompt: result.prompt,
                    generationTime: result.generationTime,
                    metadata: result.metadata,
                    recipeName
                }
            });
            console.log(`✅ [PHOTO] Photo generation completed for: ${recipeName}`);
        }
        catch (error) {
            console.error('❌ Generate recipe photo error:', error);
            if (!res.headersSent) {
                res.status(500).json({
                    success: false,
                    error: 'Failed to generate recipe photo',
                    message: error instanceof Error ? error.message : 'Unknown error'
                });
            }
        }
    });
});
// REMOVED: transcribeAudio endpoint - not used by iOS app
// REMOVED: Memory management endpoints - not used by iOS app
// - embedText
// - processMessage
// - searchSimilarMessages
// - processConversationBoundary
// REMOVED: chatText endpoint - consolidating into diabetesAssistantStream only
// ============================================
// HELPER FUNCTIONS
// ============================================
async function getCurrentOrCreateSession(userId) {
    const sessionsRef = db.collection('conversations').doc(userId).collection('sessions');
    // Check for active session (within last 5 minutes)
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const activeSessions = await sessionsRef
        .where('endTime', '==', null)
        .where('startTime', '>', fiveMinutesAgo)
        .orderBy('startTime', 'desc')
        .limit(1)
        .get();
    if (!activeSessions.empty) {
        return activeSessions.docs[0].id;
    }
    // Create new session
    const newSession = {
        sessionId: `session_${Date.now()}`,
        userId,
        messages: [],
        startTime: new Date().toISOString(),
        messageCount: 0
    };
    const docRef = await sessionsRef.add(newSession);
    return docRef.id;
}
// @ts-ignore - unused but kept for reference
async function _updateConversationSession(userId, message) {
    const sessionId = await getCurrentOrCreateSession(userId);
    const sessionRef = db.collection('conversations').doc(userId).collection('sessions').doc(sessionId);
    const sessionDoc = await sessionRef.get();
    if (!sessionDoc.exists)
        return;
    const session = sessionDoc.data();
    // Keep only last 5 turns (10 messages) in full text
    const updatedMessages = [...session.messages, message];
    const messagesToKeep = updatedMessages.slice(-10);
    await sessionRef.update({
        messages: messagesToKeep,
        messageCount: session.messageCount + 1,
        lastActivity: new Date().toISOString()
    });
    // If we have more than 10 messages, consider boundary processing
    if (session.messageCount > 10 && session.messageCount % 10 === 0) {
        // Trigger async boundary processing
        processSessionBoundary(userId, sessionId).catch(console.error);
    }
}
async function processSessionBoundary(userId, sessionId) {
    try {
        // This would be called to process conversation boundary
        // For now, we'll just log it
        console.log(`Processing session boundary for ${userId}/${sessionId}`);
    }
    catch (error) {
        console.error('Failed to process session boundary:', error);
    }
}
// REMOVED: Unused memory management system (intent classification, session management, vector similarity)
// The iOS app uses a different memory architecture via memory-sync endpoints
// ============================================
// NUTRITION EXTRACTION ENDPOINT
// ============================================
// Import the new direct API extractor
const nutrition_extractor_1 = require("./nutrition-extractor");
// Endpoint: Extract nutrition information from image using Direct Gemini API
exports.extractNutritionFromImage = (0, https_1.onRequest)({
    timeoutSeconds: 120,
    memory: '512MiB',
    cpu: 1,
    concurrency: 3
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            // Validate request method
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed. Use POST.' });
                return;
            }
            // Extract and validate input
            const { imageBase64, language = 'tr', maxWidth = 1024, userId } = req.body;
            if (!imageBase64) {
                res.status(400).json({
                    error: 'Missing required field: imageBase64',
                    message: 'Please provide a base64 encoded image'
                });
                return;
            }
            console.log(`🏷️ [NUTRITION-DIRECT] Processing nutrition extraction with direct API (${language} language)`);
            const startTime = Date.now();
            // Use the new direct API extractor with responseSchema
            const result = await (0, nutrition_extractor_1.extractNutritionWithResponseSchema)({
                imageBase64,
                language,
                maxWidth,
                userId
            });
            // Track cost for nutrition extraction
            if (result.usage) {
                await (0, cost_tracker_1.logTokenUsage)({
                    featureName: model_pricing_1.FeatureName.NUTRITION_CALCULATION,
                    modelName: 'gemini-2.5-flash', // gemini-flash-latest maps to 2.5 Flash
                    inputTokens: result.usage.inputTokens,
                    outputTokens: result.usage.outputTokens,
                    userId,
                    metadata: { language, confidence: result.metadata.confidence }
                });
            }
            const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
            console.log(`✅ [NUTRITION-DIRECT] Completed extraction in ${totalTime}s with 99%+ reliability`);
            res.json({
                success: true,
                data: result,
                metadata: {
                    processingTime: `${totalTime}s`,
                    timestamp: new Date().toISOString(),
                    version: '2.0.0-direct-api',
                    method: 'direct-gemini-api-with-response-schema'
                }
            });
        }
        catch (error) {
            console.error('❌ [NUTRITION-DIRECT] Extraction failed:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({
                success: false,
                error: 'Nutrition extraction failed',
                message: errorMessage,
                timestamp: new Date().toISOString(),
                method: 'direct-gemini-api-with-response-schema'
            });
        }
    });
});
// REMOVED: nutritionApiHealth - not used by iOS app
// ============================================
// MEAL TRANSCRIPTION ENDPOINT
// ============================================
// Import the meal transcription function
const transcribeMeal_1 = require("./transcribeMeal");
// Endpoint: Transcribe Turkish audio and extract meal data using Gemini 2.5 Flash
exports.transcribeMeal = (0, https_1.onRequest)({
    timeoutSeconds: 60,
    memory: '512MiB',
    cpu: 1,
    concurrency: 5
}, async (req, res) => {
    corsHandler(req, res, async () => {
        try {
            // Validate request method
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Method not allowed. Use POST.' });
                return;
            }
            // Extract and validate input
            const { audioData, mimeType, userId, currentTime } = req.body;
            if (!audioData) {
                res.status(400).json({
                    success: false,
                    error: 'Missing required field: audioData',
                    message: 'Please provide a base64 encoded audio file'
                });
                return;
            }
            if (!userId) {
                res.status(400).json({
                    success: false,
                    error: 'Missing required field: userId',
                    message: 'User ID required'
                });
                return;
            }
            console.log(`🎤 [TRANSCRIBE-MEAL-ENDPOINT] Processing audio for user ${userId}`);
            const startTime = Date.now();
            // Call the transcription function
            const result = await (0, transcribeMeal_1.transcribeMealAudio)({
                audioData,
                mimeType: mimeType || 'audio/m4a',
                userId: userId,
                currentTime: currentTime || new Date().toISOString()
            });
            const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
            if (result.success) {
                console.log(`✅ [TRANSCRIBE-MEAL-ENDPOINT] Completed in ${totalTime}s - ${result.data.foods.length} foods, ${result.data.totalCarbs}g carbs`);
            }
            else {
                console.log(`❌ [TRANSCRIBE-MEAL-ENDPOINT] Failed in ${totalTime}s: ${result.error}`);
            }
            // Return response with metadata
            res.json({
                ...result,
                metadata: {
                    processingTime: `${totalTime}s`,
                    timestamp: new Date().toISOString(),
                    version: '1.0.0-gemini-2.5-flash'
                }
            });
        }
        catch (error) {
            console.error('❌ [TRANSCRIBE-MEAL-ENDPOINT] Unexpected error:', error);
            const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
            res.status(500).json({
                success: false,
                error: 'Meal transcription failed',
                message: errorMessage,
                timestamp: new Date().toISOString()
            });
        }
    });
});
// ============================================
// COST TRACKING & REPORTING ENDPOINTS
// ============================================
// REMOVED: Cost tracking endpoints - not needed
// ============================================
// ACTIVE EXPORTS - ONLY ESSENTIAL FUNCTIONS
// ============================================
// Export ONLY the streaming diabetes assistant (consolidated endpoint)
var diabetes_assistant_stream_1 = require("./diabetes-assistant-stream");
Object.defineProperty(exports, "diabetesAssistantStream", { enumerable: true, get: function () { return diabetes_assistant_stream_1.diabetesAssistantStream; } });
// Export session metadata generation endpoint
var generate_session_metadata_1 = require("./generate-session-metadata");
Object.defineProperty(exports, "generateSessionMetadata", { enumerable: true, get: function () { return generate_session_metadata_1.generateSessionMetadata; } });
exports.calculateRecipeNutrition = (0, https_1.onRequest)({
    cors: true,
    maxInstances: 10,
    memory: '512MiB',
    timeoutSeconds: 90 // Gemini 2.5 Pro needs 35-45s for medical-grade calculations
}, async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        const input = req.body;
        // Validate input
        if (!input.recipeName || !input.recipeContent) {
            res.status(400).json({
                success: false,
                error: 'Missing required fields: recipeName, recipeContent'
            });
            return;
        }
        // Determine recipe type
        const isManualRecipe = input.recipeType === "manual" || input.servings === null;
        console.log(`🍽️ [NUTRITION-CALC] Analyzing nutrition for: ${input.recipeName}`);
        console.log(`🍽️ [NUTRITION-CALC] Recipe Type: ${isManualRecipe ? 'MANUAL' : 'AI-GENERATED'}`);
        console.log(`🍽️ [NUTRITION-CALC] Servings: ${input.servings ?? 'null (manual recipe)'}`);
        // Load nutrition calculator prompt
        const nutritionPrompt = genkit_instance_1.ai.prompt('recipe_nutrition_calculator');
        // Call Gemini 2.5 Pro for nutrition analysis
        const result = await nutritionPrompt({
            recipeName: input.recipeName,
            recipeContent: input.recipeContent,
            servings: input.servings ?? 1, // Default to 1 if null (manual recipes)
            recipeType: isManualRecipe ? "manual" : "aiGenerated"
        }, {
            model: (0, providers_1.getTier3Model)() // Explicitly use Gemini 2.5 Pro
        });
        // Log the complete AI response with all reasoning
        console.log(`\n${'='.repeat(80)}`);
        console.log(`🤖 [NUTRITION-CALC] COMPLETE AI OUTPUT`);
        console.log(`${'='.repeat(80)}`);
        console.log(JSON.stringify(result.output, null, 2));
        console.log(`${'='.repeat(80)}\n`);
        if (isManualRecipe) {
            // Manual recipe: return totalRecipe format
            const manualResult = result.output;
            console.log(`✅ [NUTRITION-CALC] Manual Recipe Calculation complete:`);
            console.log(`   Total Weight: ${manualResult.totalRecipe.weight}g`);
            console.log(`   Total Calories: ${manualResult.totalRecipe.calories} kcal`);
            console.log(`   Total Carbs: ${manualResult.totalRecipe.carbohydrates}g, Protein: ${manualResult.totalRecipe.protein}g, Fat: ${manualResult.totalRecipe.fat}g`);
            console.log(`   Total Glycemic Load: ${manualResult.totalRecipe.glycemicLoad}`);
            // Log reasoning if available
            if (manualResult.nutritionCalculation?.calculationNotes) {
                console.log(`\n📋 [NUTRITION-CALC] CALCULATION NOTES:`);
                console.log(manualResult.nutritionCalculation.calculationNotes);
            }
            res.status(200).json({
                success: true,
                data: manualResult
            });
        }
        else {
            // AI-generated recipe: return existing format
            const nutrition = result.output;
            console.log(`✅ [NUTRITION-CALC] AI Recipe Calculation complete:`);
            console.log(`   Calories: ${nutrition.calories} kcal/100g`);
            console.log(`   Carbs: ${nutrition.carbohydrates}g, Protein: ${nutrition.protein}g, Fat: ${nutrition.fat}g`);
            console.log(`   Glycemic Load: ${nutrition.glycemicLoad}`);
            // Log per-portion values
            if (nutrition.perPortion) {
                console.log(`\n   Per-Portion Values:`);
                console.log(`   Weight: ${nutrition.perPortion.weight}g`);
                console.log(`   Calories: ${nutrition.perPortion.calories} kcal`);
                console.log(`   Carbs: ${nutrition.perPortion.carbohydrates}g, Protein: ${nutrition.perPortion.protein}g, Fat: ${nutrition.perPortion.fat}g`);
                console.log(`   Glycemic Load: ${nutrition.perPortion.glycemicLoad}`);
            }
            // Log reasoning if available
            if (nutrition.nutritionCalculation?.calculationNotes) {
                console.log(`\n📋 [NUTRITION-CALC] CALCULATION NOTES:`);
                console.log(nutrition.nutritionCalculation.calculationNotes);
            }
            res.status(200).json({
                success: true,
                data: nutrition
            });
        }
    }
    catch (error) {
        console.error('❌ [NUTRITION-CALC] Error:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Nutrition calculation failed'
        });
    }
});
//# sourceMappingURL=index.js.map