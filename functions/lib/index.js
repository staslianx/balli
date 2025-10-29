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
exports.calculateRecipeNutrition = exports.recallFromPastSessions = exports.testEdamamNutrition = exports.syncUserPreferences = exports.syncGlucosePatterns = exports.syncRecipePreferences = exports.syncConversationSummaries = exports.syncUserFacts = exports.generateSessionMetadata = exports.diabetesAssistantStream = exports.transcribeMeal = exports.extractNutritionFromImage = exports.generateRecipePhoto = exports.generateSpontaneousRecipe = exports.generateRecipeFromIngredients = void 0;
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
const recipe_memory_1 = require("./services/recipe-memory");
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
// Configure CORS
const corsHandler = cors.default({
    origin: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
});
// ============================================
// GENKIT FLOWS FOR MEMORY MANAGEMENT
// ============================================
// Flow: Generate text embeddings using text-embedding-004
const generateEmbeddingFlow = genkit_instance_1.ai.defineFlow({
    name: 'generateEmbedding',
    inputSchema: genkit_1.z.object({
        text: genkit_1.z.string().describe('Text to generate embedding for')
    }),
    outputSchema: genkit_1.z.object({
        embedding: genkit_1.z.array(genkit_1.z.number()).describe('Embedding vector'),
        dimensions: genkit_1.z.number().describe('Number of dimensions')
    })
}, async (input) => {
    try {
        const response = await genkit_instance_1.ai.embed({
            embedder: (0, providers_1.getEmbedder)(),
            content: input.text
        });
        // Extract the actual embedding vector from the response
        const embeddingVector = Array.isArray(response) ? response[0]?.embedding : response;
        const embedding = Array.isArray(embeddingVector) ? embeddingVector : [];
        return {
            embedding: embedding,
            dimensions: embedding.length
        };
    }
    catch (error) {
        console.error('❌ Embedding generation failed:', error);
        throw error;
    }
});
// Flow: Summarize conversation using Gemini 2.5 Flash Lite
const summarizeConversationFlow = genkit_instance_1.ai.defineFlow({
    name: 'summarizeConversation',
    inputSchema: genkit_1.z.object({
        messages: genkit_1.z.array(genkit_1.z.object({
            text: genkit_1.z.string(),
            isUser: genkit_1.z.boolean()
        })).describe('Messages to summarize'),
        userId: genkit_1.z.string().describe('User ID for context')
    }),
    outputSchema: genkit_1.z.object({
        summary: genkit_1.z.string().describe('Concise summary of conversation'),
        keyFacts: genkit_1.z.array(genkit_1.z.string()).describe('Important facts extracted'),
        topics: genkit_1.z.array(genkit_1.z.string()).describe('Main topics discussed')
    })
}, async (input) => {
    const conversationText = input.messages
        .map(msg => `${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}`)
        .join('\n');
    const prompt = `Summarize this conversation between a diabetes patient and their assistant.
Extract key facts about the user and main topics discussed.

Conversation:
${conversationText}

Provide:
1. A concise summary (2-3 sentences)
2. Key facts about the user (health info, preferences, etc)
3. Main topics discussed

Format as JSON with fields: summary, keyFacts (array), topics (array)`;
    try {
        // Using Gemini 2.5 Flash Lite for efficient summarization
        const response = await genkit_instance_1.ai.generate({
            model: (0, providers_1.getSummaryModel)(),
            prompt: prompt,
            output: { format: 'json' },
            config: {
                temperature: 0.3,
                maxOutputTokens: 1024
            }
        });
        const result = JSON.parse(response.text);
        return {
            summary: result.summary || 'No summary generated',
            keyFacts: result.keyFacts || [],
            topics: result.topics || []
        };
    }
    catch (error) {
        console.error('❌ Summarization failed:', error);
        return {
            summary: 'Failed to generate summary',
            keyFacts: [],
            topics: []
        };
    }
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
        userId: genkit_1.z.string().optional().describe('User ID for personalization')
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
            spontaneous: false
        }, {
            model: (0, providers_1.getRecipeModel)() // Use provider-specific model for caching
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
                            fullContent += chunkText;
                            tokenCount++;
                            // Send chunk to client
                            const chunkEvent = {
                                type: "chunk",
                                data: {
                                    content: chunkText,
                                    fullContent: fullContent,
                                    tokenCount: tokenCount
                                },
                                timestamp: new Date().toISOString()
                            };
                            res.write(`event: chunk\ndata: ${JSON.stringify(chunkEvent)}\n\n`);
                        }
                    }
                    // Sanitize JSON by fixing control characters in string values
                    // Gemini sometimes outputs raw newlines in strings which break JSON.parse()
                    const sanitizeJSON = (jsonStr) => {
                        let result = '';
                        let inString = false;
                        let escapeNext = false;
                        for (let i = 0; i < jsonStr.length; i++) {
                            const char = jsonStr[i];
                            if (escapeNext) {
                                result += char;
                                escapeNext = false;
                                continue;
                            }
                            if (char === '\\') {
                                result += char;
                                escapeNext = true;
                                continue;
                            }
                            if (char === '"') {
                                result += char;
                                inString = !inString;
                                continue;
                            }
                            // Only escape control characters when inside a string
                            if (inString) {
                                if (char === '\n')
                                    result += '\\n';
                                else if (char === '\r')
                                    result += '\\r';
                                else if (char === '\t')
                                    result += '\\t';
                                else
                                    result += char;
                            }
                            else {
                                result += char;
                            }
                        }
                        return result;
                    };
                    // Parse the final JSON response
                    let parsedRecipe;
                    try {
                        const sanitizedContent = sanitizeJSON(fullContent);
                        parsedRecipe = JSON.parse(sanitizedContent);
                    }
                    catch (parseError) {
                        // Try to extract JSON from the content
                        const jsonMatch = fullContent.match(/\{[\s\S]*\}/);
                        if (jsonMatch) {
                            const sanitizedMatch = sanitizeJSON(jsonMatch[0]);
                            parsedRecipe = JSON.parse(sanitizedMatch);
                        }
                        else {
                            console.error('❌ [JSON-PARSE] Failed to parse recipe JSON:', parseError);
                            console.error('❌ [JSON-PARSE] Content preview:', fullContent.substring(0, 500));
                            throw new Error('Failed to parse recipe JSON');
                        }
                    }
                    // Send completion event - flatten recipe data for iOS app compatibility
                    // Map 'name' field to 'recipeName' for iOS compatibility
                    const recipeData = {
                        ...parsedRecipe,
                        recipeName: parsedRecipe.name || parsedRecipe.recipeName, // Support both field names
                        fullContent: JSON.stringify(parsedRecipe), // Also provide as fullContent for backward compatibility
                        tokenCount: tokenCount
                    };
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
            const { mealType, memoryEntries } = req.body;
            let { styleType } = req.body;
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
                    recentRecipes: [] // Memory system is handled client-side via extractedIngredients
                }, {
                    model: (0, providers_1.getRecipeModel)() // Use provider-specific model for caching
                });
                let fullContent = '';
                let tokenCount = 0;
                for await (const chunk of streamingResponse.stream) {
                    const chunkText = chunk.text;
                    if (chunkText) {
                        fullContent += chunkText;
                        tokenCount++;
                        // Send chunk to client
                        const chunkEvent = {
                            type: "chunk",
                            data: {
                                content: chunkText,
                                fullContent: fullContent,
                                tokenCount: tokenCount
                            },
                            timestamp: new Date().toISOString()
                        };
                        res.write(`event: chunk\ndata: ${JSON.stringify(chunkEvent)}\n\n`);
                    }
                }
                // Sanitize JSON by fixing control characters in string values
                // Gemini sometimes outputs raw newlines in strings which break JSON.parse()
                const sanitizeJSON = (jsonStr) => {
                    let result = '';
                    let inString = false;
                    let escapeNext = false;
                    for (let i = 0; i < jsonStr.length; i++) {
                        const char = jsonStr[i];
                        if (escapeNext) {
                            result += char;
                            escapeNext = false;
                            continue;
                        }
                        if (char === '\\') {
                            result += char;
                            escapeNext = true;
                            continue;
                        }
                        if (char === '"') {
                            result += char;
                            inString = !inString;
                            continue;
                        }
                        // Only escape control characters when inside a string
                        if (inString) {
                            if (char === '\n')
                                result += '\\n';
                            else if (char === '\r')
                                result += '\\r';
                            else if (char === '\t')
                                result += '\\t';
                            else
                                result += char;
                        }
                        else {
                            result += char;
                        }
                    }
                    return result;
                };
                // Parse the final JSON response
                let parsedRecipe;
                try {
                    const sanitizedContent = sanitizeJSON(fullContent);
                    parsedRecipe = JSON.parse(sanitizedContent);
                }
                catch (parseError) {
                    // Try to extract JSON from the content
                    const jsonMatch = fullContent.match(/\{[\s\S]*\}/);
                    if (jsonMatch) {
                        const sanitizedMatch = sanitizeJSON(jsonMatch[0]);
                        parsedRecipe = JSON.parse(sanitizedMatch);
                    }
                    else {
                        console.error('❌ [JSON-PARSE] Failed to parse recipe JSON:', parseError);
                        console.error('❌ [JSON-PARSE] Content preview:', fullContent.substring(0, 500));
                        throw new Error('Failed to parse recipe JSON');
                    }
                }
                // Extract main ingredients for memory system (streaming mode)
                // CRITICAL: Wrap in try-catch to prevent blocking stream completion
                let extractedIngredients = [];
                try {
                    const recipeContent = parsedRecipe.recipeContent || '';
                    const recipeName = parsedRecipe.name || parsedRecipe.recipeName || '';
                    console.log(`🔍 [STREAMING-EXTRACTION] Recipe generated: "${recipeName}"`);
                    console.log(`🔍 [STREAMING-EXTRACTION] Extracting main ingredients using Gemini...`);
                    extractedIngredients = await (0, recipe_memory_1.extractMainIngredients)(recipeContent, recipeName);
                    if (extractedIngredients.length === 0) {
                        console.log(`⚠️ [STREAMING-EXTRACTION] WARNING: Failed to extract ingredients!`);
                    }
                    else {
                        console.log(`✅ [STREAMING-EXTRACTION] Extracted ${extractedIngredients.length} main ingredients:`);
                        console.log(`✅ [STREAMING-EXTRACTION] [${extractedIngredients.join(', ')}]`);
                    }
                }
                catch (extractionError) {
                    console.error(`❌ [STREAMING-EXTRACTION] Extraction failed, continuing without ingredients:`, extractionError);
                    extractedIngredients = []; // Ensure it's always an array
                }
                // Send completion event - flatten recipe data for iOS app compatibility
                // Map 'name' field to 'recipeName' for iOS compatibility
                const recipeData = {
                    ...parsedRecipe,
                    recipeName: parsedRecipe.name || parsedRecipe.recipeName, // Support both field names
                    fullContent: JSON.stringify(parsedRecipe), // Also provide as fullContent for backward compatibility
                    tokenCount: tokenCount,
                    extractedIngredients // ADD extracted ingredients for iOS memory system
                };
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
// Refactored to be intent-aware (unused - kept for future use)
// @ts-ignore - unused but kept for reference
async function _getMemoryContext(userId, query, intent) {
    try {
        console.log(`🧠 [MEMORY] Getting context for intent: ${intent.category} (confidence: ${intent.confidence})`);
        let context = '';
        const contextNeeded = intent.contextNeeded;
        // IMMEDIATE CONTEXT: Always include last few messages for conversation continuity
        if (contextNeeded.immediate) {
            const immediateMessages = sessionManager.getLastNMessages(userId, 3);
            if (immediateMessages.length > 0) {
                context += '## Immediate Context (Last Messages):\n';
                immediateMessages.forEach(msg => {
                    context += `${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}\n`;
                });
                context += '\n';
            }
        }
        // SESSION CONTEXT: Include current session messages (beyond immediate)
        if (contextNeeded.session) {
            const sessionMessages = sessionManager.getSessionMessages(userId);
            if (sessionMessages.length > 3) { // More than immediate context
                const olderSessionMessages = sessionMessages.slice(0, -3); // Exclude last 3 already included
                if (olderSessionMessages.length > 0) {
                    context += '## Session Context (Earlier in Conversation):\n';
                    // Limit to last 10 messages to avoid context overload
                    const limitedMessages = olderSessionMessages.slice(-10);
                    limitedMessages.forEach(msg => {
                        context += `${msg.isUser ? 'User' : 'Assistant'}: ${msg.text}\n`;
                    });
                    context += '\n';
                }
            }
        }
        // HISTORICAL CONTEXT: Search previous sessions for relevant information
        if (contextNeeded.historical) {
            console.log(`🔍 [MEMORY] Searching historical context for: ${query}`);
            try {
                const longTermMemory = await searchLongTermMemory(userId, query);
                if (longTermMemory) {
                    context += '## Historical Context (Previous Sessions):\n';
                    context += longTermMemory;
                    context += '\n';
                }
            }
            catch (searchError) {
                console.warn('⚠️ [MEMORY] Historical context search failed:', searchError);
            }
        }
        // VECTOR SEARCH: Semantic similarity for relevant past conversations
        if (contextNeeded.vectorSearch) {
            console.log(`🎯 [MEMORY] Performing vector search for: ${query}`);
            try {
                const vector = await vectorSimilarMessages(userId, query, 5);
                if (vector.results.length > 0) {
                    context += '## Semantic Matches (Relevant Past Discussions):\n';
                    vector.results.forEach(m => {
                        context += `${m.isUser ? 'User' : 'Assistant'}: ${m.text}\n`;
                    });
                    context += '\n';
                }
            }
            catch (e) {
                console.warn('⚠️ [MEMORY] Vector similarity search failed:', e);
            }
        }
        // Add intent information for debugging
        console.log(`📊 [MEMORY] Context built - Intent: ${intent.category}, Length: ${context.length} chars`);
        return context || null;
    }
    catch (error) {
        console.error('❌ [MEMORY] Failed to get memory context:', error);
        return null;
    }
}
// Legacy function removed - now using intent-aware getMemoryContext directly
// Search long-term memory using keyword search
async function searchLongTermMemory(userId, query) {
    try {
        const memoryDoc = await db.collection('longTermMemory').doc(userId).get();
        if (!memoryDoc.exists) {
            return null;
        }
        const memory = memoryDoc.data();
        let relevantContent = '';
        // Simple keyword search in summaries
        const queryKeywords = query.toLowerCase().split(' ').filter(word => word.length > 2);
        if (memory.summaries?.length > 0) {
            const relevantSummaries = memory.summaries.filter(summary => {
                const summaryText = summary.summary.toLowerCase();
                return queryKeywords.some(keyword => summaryText.includes(keyword));
            });
            if (relevantSummaries.length > 0) {
                relevantContent += 'Relevant previous conversations:\n';
                relevantSummaries.slice(-3).forEach(summary => {
                    relevantContent += `- ${summary.summary}\n`;
                });
            }
        }
        // Search in user facts
        if (memory.facts?.length > 0) {
            const relevantFacts = memory.facts.filter(fact => {
                const factText = fact.toLowerCase();
                return queryKeywords.some(keyword => factText.includes(keyword));
            });
            if (relevantFacts.length > 0) {
                relevantContent += 'Relevant user information:\n';
                relevantFacts.slice(0, 3).forEach(fact => {
                    relevantContent += `- ${fact}\n`;
                });
            }
        }
        return relevantContent || null;
    }
    catch (error) {
        console.error('Error searching long-term memory:', error);
        return null;
    }
}
// Session boundary detection and handoff (unused - kept for future use)
// @ts-ignore - unused but kept for reference
async function _checkAndHandoffSession(userId) {
    try {
        // Get recent messages to check session length
        const recentMessagesQuery = await db.collection('chat_messages')
            .where('userId', '==', userId)
            .orderBy('timestamp', 'desc')
            .limit(12) // Look at slightly more than our short-term limit
            .get();
        if (recentMessagesQuery.empty)
            return;
        const messages = recentMessagesQuery.docs.map(doc => doc.data());
        // Session boundary criteria:
        // 1. More than 10 messages (5 turns) - need to handoff older messages
        // 2. OR time gap > 30 minutes since last message group
        if (messages.length >= 12) {
            console.log(`📚 [HANDOFF] Session has ${messages.length} messages, triggering handoff for user: ${userId}`);
            // Take the older messages (beyond our short-term memory limit) for summarization
            const messagesToSummarize = messages.slice(10).reverse(); // Get oldest messages beyond our 10-message limit
            if (messagesToSummarize.length >= 2) { // Need at least one exchange to summarize
                await handoffToLongTermMemory(userId, messagesToSummarize);
            }
        }
    }
    catch (error) {
        console.error('Error in session boundary check:', error);
    }
}
// Handoff messages to long-term memory with summarization
async function handoffToLongTermMemory(userId, messages) {
    try {
        console.log(`🔄 [HANDOFF] Processing ${messages.length} messages for long-term storage`);
        // Prepare messages for summarization
        const messagesForSummary = messages.map(msg => ({
            text: msg.text,
            isUser: msg.isUser
        }));
        // Use Gemini 2.5 Flash Lite for summarization
        const summaryResult = await summarizeConversationFlow({
            messages: messagesForSummary,
            userId: userId
        });
        console.log('📝 [HANDOFF] Generated summary:', summaryResult.summary);
        // Store in long-term memory
        const memoryRef = db.collection('longTermMemory').doc(userId);
        const memoryDoc = await memoryRef.get();
        const sessionSummary = {
            sessionId: `session_${Date.now()}`,
            summary: summaryResult.summary,
            timestamp: new Date().toISOString(),
            messageCount: messages.length
        };
        if (memoryDoc.exists) {
            // Update existing memory
            await memoryRef.update({
                summaries: firestore_1.FieldValue.arrayUnion(sessionSummary),
                facts: firestore_1.FieldValue.arrayUnion(...summaryResult.keyFacts),
                lastUpdated: new Date().toISOString()
            });
        }
        else {
            // Create new memory document
            const newMemory = {
                userId,
                facts: summaryResult.keyFacts,
                patterns: [],
                summaries: [sessionSummary],
                preferences: {},
                lastUpdated: new Date().toISOString()
            };
            await memoryRef.set(newMemory);
        }
        // Delete the summarized messages from chat_messages to keep only recent ones
        const batch = db.batch();
        const messagesToDelete = await db.collection('chat_messages')
            .where('userId', '==', userId)
            .orderBy('timestamp', 'asc')
            .limit(messages.length)
            .get();
        messagesToDelete.docs.forEach(doc => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(`✅ [HANDOFF] Completed handoff for ${messages.length} messages`);
    }
    catch (error) {
        console.error('❌ [HANDOFF] Error in handoff process:', error);
    }
}
// ============================================
// INTENT CLASSIFICATION SYSTEM
// ============================================
// @ts-ignore - unused but kept for reference
async function _classifyMessageIntent(message) {
    try {
        const classifierModel = (0, providers_1.getClassifierModel)();
        const classificationPrompt = `Sen bir mesaj analiz uzmanısın. Kullanıcı mesajını analiz ederek hangi tür yanıt ve bağlam gerektirdiğini belirle.

Mesaj: "${message}"

Aşağıdaki kategorilerden birini seç:
1. "greeting" - Basit selamlaşma (Günaydın, Merhaba, Nasılsın, vb.)
2. "health_query" - Sağlık/diyabet ile ilgili soru veya bilgi talebi
3. "memory_recall" - Geçmiş konuşmaları hatırlatma ("hatırlıyor musun", "daha önce konuştuk", vb.)
4. "follow_up" - Mevcut konuya devam etme ("peki ya", "bir de", "ayrıca", vb.)
5. "general" - Diğer genel konuşma

JSON formatında yanıt ver:
{
  "category": "kategori_adı",
  "confidence": 0.95,
  "keywords": ["anahtar", "kelimeler"],
  "contextNeeded": {
    "immediate": true,
    "session": false,
    "historical": false,
    "vectorSearch": false
  },
  "reasoning": "Kısa açıklama"
}

Kurallar:
- Tek kelime selamlaşmalar (Günaydın, Merhaba) → sadece immediate: true
- Sağlık soruları → session: true, vectorSearch: true
- Hatırlama istekleri → historical: true, vectorSearch: true
- Takip soruları → session: true

Sadece JSON yanıt ver, başka bir şey yazma.`;
        const response = await genkit_instance_1.ai.generate({
            model: classifierModel,
            prompt: classificationPrompt,
            config: {
                temperature: 0.1,
                maxOutputTokens: 300
            }
        });
        const responseText = response.text.trim();
        console.log(`🔍 [CLASSIFY] Raw response: ${responseText}`);
        // Parse JSON response
        try {
            const intent = JSON.parse(responseText);
            console.log(`🎯 [CLASSIFY] Message: "${message}" → Category: ${intent.category} (confidence: ${intent.confidence})`);
            return intent;
        }
        catch (parseError) {
            console.warn(`⚠️ [CLASSIFY] Failed to parse JSON, using fallback`, parseError);
            return createFallbackIntent(message);
        }
    }
    catch (error) {
        console.error('❌ [CLASSIFY] Intent classification failed:', error);
        return createFallbackIntent(message);
    }
}
function createFallbackIntent(message) {
    // Simple fallback logic based on keywords
    const lowerMessage = message.toLowerCase().trim();
    const turkishGreetings = ['günaydın', 'merhaba', 'selam', 'nasılsın', 'naber', 'iyi misin'];
    const memoryKeywords = ['hatırla', 'daha önce', 'geçen', 'konuştuk', 'söylemiştim'];
    const healthKeywords = ['şeker', 'kan', 'insülin', 'diyabet', 'glikoz', 'ölçüm', 'kahvaltı', 'yemek'];
    if (turkishGreetings.some(greeting => lowerMessage.includes(greeting) && lowerMessage.length < 15)) {
        return {
            category: 'greeting',
            confidence: 0.8,
            keywords: [lowerMessage],
            contextNeeded: {
                immediate: true,
                session: false,
                historical: false,
                vectorSearch: false
            },
            reasoning: 'Basit selamlaşma tespit edildi'
        };
    }
    if (memoryKeywords.some(keyword => lowerMessage.includes(keyword))) {
        return {
            category: 'memory_recall',
            confidence: 0.7,
            keywords: memoryKeywords.filter(k => lowerMessage.includes(k)),
            contextNeeded: {
                immediate: true,
                session: true,
                historical: true,
                vectorSearch: true
            },
            reasoning: 'Hafıza hatırlatma anahtar kelimesi bulundu'
        };
    }
    if (healthKeywords.some(keyword => lowerMessage.includes(keyword))) {
        return {
            category: 'health_query',
            confidence: 0.7,
            keywords: healthKeywords.filter(k => lowerMessage.includes(k)),
            contextNeeded: {
                immediate: true,
                session: true,
                historical: false,
                vectorSearch: true
            },
            reasoning: 'Sağlık anahtar kelimesi bulundu'
        };
    }
    return {
        category: 'general',
        confidence: 0.5,
        keywords: [],
        contextNeeded: {
            immediate: true,
            session: true,
            historical: false,
            vectorSearch: false
        },
        reasoning: 'Genel kategori (fallback)'
    };
}
class SessionContextManager {
    sessionCaches = new Map();
    MAX_SESSION_MESSAGES = 50; // Keep last 50 messages in session
    SESSION_TIMEOUT = 30 * 60 * 1000; // 30 minutes timeout
    constructor() {
        // Clean up expired sessions every 10 minutes
        setInterval(() => this.cleanupExpiredSessions(), 10 * 60 * 1000);
    }
    generateSessionId() {
        return `session_${Date.now()}_${Math.random().toString(36).substring(2)}`;
    }
    getSessionKey(userId) {
        return `session_${userId}`;
    }
    addMessage(userId, message) {
        const sessionKey = this.getSessionKey(userId);
        let session = this.sessionCaches.get(sessionKey);
        if (!session) {
            // Create new session
            session = {
                userId,
                sessionId: this.generateSessionId(),
                messages: [],
                lastActivity: new Date().toISOString(),
                startTime: new Date().toISOString()
            };
            this.sessionCaches.set(sessionKey, session);
            console.log(`🆕 [SESSION] Created new session ${session.sessionId} for user ${userId}`);
        }
        // Add message to session
        session.messages.push(message);
        session.lastActivity = new Date().toISOString();
        // Keep only recent messages to prevent memory bloat
        if (session.messages.length > this.MAX_SESSION_MESSAGES) {
            const removed = session.messages.splice(0, session.messages.length - this.MAX_SESSION_MESSAGES);
            console.log(`🧹 [SESSION] Trimmed ${removed.length} old messages from session`);
        }
        console.log(`💬 [SESSION] Added message to session ${session.sessionId} (${session.messages.length} total messages)`);
    }
    getSessionMessages(userId) {
        const sessionKey = this.getSessionKey(userId);
        const session = this.sessionCaches.get(sessionKey);
        if (!session) {
            console.log(`📭 [SESSION] No session found for user ${userId}`);
            return [];
        }
        // Check if session is expired
        const now = Date.now();
        const lastActivity = new Date(session.lastActivity).getTime();
        if (now - lastActivity > this.SESSION_TIMEOUT) {
            console.log(`⏰ [SESSION] Session ${session.sessionId} expired, removing`);
            this.sessionCaches.delete(sessionKey);
            return [];
        }
        console.log(`📚 [SESSION] Retrieved ${session.messages.length} messages from session ${session.sessionId}`);
        return [...session.messages]; // Return copy to prevent external mutations
    }
    getLastNMessages(userId, count) {
        const messages = this.getSessionMessages(userId);
        return messages.slice(-count);
    }
    clearSession(userId) {
        const sessionKey = this.getSessionKey(userId);
        const session = this.sessionCaches.get(sessionKey);
        if (session) {
            console.log(`🗑️ [SESSION] Manually clearing session ${session.sessionId} for user ${userId}`);
            this.sessionCaches.delete(sessionKey);
        }
    }
    cleanupExpiredSessions() {
        const now = Date.now();
        let expiredCount = 0;
        for (const [key, session] of this.sessionCaches.entries()) {
            const lastActivity = new Date(session.lastActivity).getTime();
            if (now - lastActivity > this.SESSION_TIMEOUT) {
                this.sessionCaches.delete(key);
                expiredCount++;
            }
        }
        if (expiredCount > 0) {
            console.log(`🧹 [SESSION] Cleaned up ${expiredCount} expired sessions`);
        }
    }
    getSessionStats() {
        let totalMessages = 0;
        for (const session of this.sessionCaches.values()) {
            totalMessages += session.messages.length;
        }
        return {
            totalSessions: this.sessionCaches.size,
            totalMessages
        };
    }
}
// Global session manager instance
const sessionManager = new SessionContextManager();
// ============================================
// MONITORING ENDPOINTS
// ============================================
// REMOVED: sessionStats - health/debug endpoint not needed
// ============================================
// ===== Vector Similarity Helpers =====
function cosineSimilarity(a, b) {
    if (!a || !b || a.length === 0 || b.length === 0 || a.length !== b.length)
        return -1;
    let dot = 0;
    let na = 0;
    let nb = 0;
    for (let i = 0; i < a.length; i++) {
        const x = a[i] || 0;
        const y = b[i] || 0;
        dot += x * y;
        na += x * x;
        nb += y * y;
    }
    const denom = Math.sqrt(na) * Math.sqrt(nb);
    return denom > 0 ? dot / denom : -1;
}
async function vectorSimilarMessages(userId, query, limit = 5) {
    // 1) Compute query embedding
    const embed = await generateEmbeddingFlow({ text: query });
    const queryVec = embed.embedding || [];
    // 2) Fetch recent candidates (bounded for latency)
    const candidateLimit = 400;
    const recent = await db.collection('chat_messages')
        .where('userId', '==', userId)
        .orderBy('timestamp', 'desc')
        .limit(candidateLimit)
        .get();
    const scored = [];
    recent.forEach(doc => {
        const data = doc.data();
        const vec = Array.isArray(data.embedding) ? data.embedding : [];
        if (vec.length > 0 && vec.length === queryVec.length) {
            const sim = cosineSimilarity(queryVec, vec);
            if (isFinite(sim)) {
                scored.push({
                    id: doc.id,
                    text: data.text,
                    isUser: !!data.isUser,
                    timestamp: data.timestamp,
                    similarity: sim,
                    dimensions: vec.length
                });
            }
        }
    });
    scored.sort((a, b) => b.similarity - a.similarity);
    const top = scored.slice(0, Math.max(1, limit));
    return { queryEmbedding: queryVec, results: top };
}
// ============================================
// REMOVED: healthCheck and memoryMetrics - not used by iOS app
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
// ACTIVE EXPORTS - ONLY ESSENTIAL FUNCTIONS
// ============================================
// Export ONLY the streaming diabetes assistant (consolidated endpoint)
var diabetes_assistant_stream_1 = require("./diabetes-assistant-stream");
Object.defineProperty(exports, "diabetesAssistantStream", { enumerable: true, get: function () { return diabetes_assistant_stream_1.diabetesAssistantStream; } });
// Export session metadata generation endpoint
var generate_session_metadata_1 = require("./generate-session-metadata");
Object.defineProperty(exports, "generateSessionMetadata", { enumerable: true, get: function () { return generate_session_metadata_1.generateSessionMetadata; } });
// Export memory sync endpoints (cross-conversation memory)
var memory_sync_1 = require("./memory-sync");
Object.defineProperty(exports, "syncUserFacts", { enumerable: true, get: function () { return memory_sync_1.syncUserFacts; } });
Object.defineProperty(exports, "syncConversationSummaries", { enumerable: true, get: function () { return memory_sync_1.syncConversationSummaries; } });
Object.defineProperty(exports, "syncRecipePreferences", { enumerable: true, get: function () { return memory_sync_1.syncRecipePreferences; } });
Object.defineProperty(exports, "syncGlucosePatterns", { enumerable: true, get: function () { return memory_sync_1.syncGlucosePatterns; } });
Object.defineProperty(exports, "syncUserPreferences", { enumerable: true, get: function () { return memory_sync_1.syncUserPreferences; } });
// Export EDAMAM test endpoint (developer testing only)
var test_edamam_nutrition_1 = require("./test-edamam-nutrition");
Object.defineProperty(exports, "testEdamamNutrition", { enumerable: true, get: function () { return test_edamam_nutrition_1.testEdamamNutrition; } });
// ============================================
// RECALL ENDPOINT - Answer from Past Research Sessions
// ============================================
const recall_flow_1 = require("./flows/recall-flow");
exports.recallFromPastSessions = (0, https_1.onRequest)({
    cors: true,
    maxInstances: 10,
    memory: '512MiB',
    timeoutSeconds: 60
}, async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    try {
        // Validate request body
        const input = req.body;
        if (!input.question || !input.userId) {
            res.status(400).json({
                success: false,
                error: 'Missing required fields: question, userId'
            });
            return;
        }
        console.log(`📚 [RECALL-ENDPOINT] Request from user: ${input.userId}`);
        console.log(`📚 [RECALL-ENDPOINT] Question: ${input.question}`);
        console.log(`📚 [RECALL-ENDPOINT] Matched sessions: ${input.matchedSessions?.length || 0}`);
        // Process recall request
        const result = await (0, recall_flow_1.handleRecall)(input);
        res.status(200).json(result);
    }
    catch (error) {
        console.error('❌ [RECALL-ENDPOINT] Error:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Internal server error'
        });
    }
});
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
        if (!input.recipeName || !input.recipeContent || !input.servings) {
            res.status(400).json({
                success: false,
                error: 'Missing required fields: recipeName, recipeContent, servings'
            });
            return;
        }
        console.log(`🍽️ [NUTRITION-CALC] Analyzing nutrition for: ${input.recipeName}`);
        console.log(`🍽️ [NUTRITION-CALC] Servings: ${input.servings}`);
        // Load nutrition calculator prompt
        const nutritionPrompt = genkit_instance_1.ai.prompt('recipe_nutrition_calculator');
        // Call Gemini 2.5 Pro for nutrition analysis
        const result = await nutritionPrompt({
            recipeName: input.recipeName,
            recipeContent: input.recipeContent,
            servings: input.servings
        }, {
            model: (0, providers_1.getTier3Model)() // Explicitly use Gemini 2.5 Pro
        });
        const nutrition = result.output;
        console.log(`✅ [NUTRITION-CALC] Calculation complete:`);
        console.log(`   Calories: ${nutrition.calories} kcal/100g`);
        console.log(`   Carbs: ${nutrition.carbohydrates}g, Protein: ${nutrition.protein}g, Fat: ${nutrition.fat}g`);
        console.log(`   Glycemic Load: ${nutrition.glycemicLoad}`);
        res.status(200).json({
            success: true,
            data: nutrition
        });
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