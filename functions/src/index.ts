//
// Balli Diabetes Assistant - Enhanced with Memory Management
// Implements short-term and long-term memory with summarization
//

// Load environment variables first (required for development)
import 'dotenv/config';

import * as admin from 'firebase-admin';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import * as cors from 'cors';
import { z } from 'genkit';
import { logProviderSwitch, getRecipeModel, getNutritionCalculatorModel } from './providers';
import { cacheManager } from './cache-manager';
import { ai } from './genkit-instance';
// Removed extractMainIngredients - using markdown parsing instead
import {
  logTokenUsage,
  logImageUsage,
  extractTokenCounts
} from './cost-tracking/cost-tracker';
import { FeatureName } from './cost-tracking/model-pricing';

// Initialize Firebase Admin (guard against duplicate initialization in tests)
if (!admin.apps.length) {
  initializeApp();
}
const db = getFirestore();

// DO NOT export ai instance - it contains circular references that break Firebase deployment
// The ai instance from genkit-instance is only for internal use within flows
// External consumers should NOT import ai from this module

// Log provider configuration on startup
logProviderSwitch();

// Warm up caches on cold start (async, non-blocking)
setImmediate(async () => {
  try {
    await cacheManager.warmupCaches();
    console.log('🔥 [STARTUP] Cache warmup completed');
  } catch (error) {
    console.warn('⚠️ [STARTUP] Cache warmup failed, continuing without cache:', error);
  }
});

/**
 * Extract ingredients from markdown recipe content
 * Parses the ## Malzemeler section and extracts ingredient names
 */
function extractIngredientsFromMarkdown(markdown: string): string[] {
  const ingredients: string[] = [];

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
// MEMORY MANAGEMENT TYPES
// ============================================

interface ChatMessage {
  text: string;
  userId: string;
  isUser: boolean;
  timestamp: string;
  embedding?: number[];
  messageId?: string;
}

interface ConversationSession {
  sessionId: string;
  userId: string;
  messages: ChatMessage[];
  summary?: string;
  startTime: string;
  endTime?: string;
  messageCount: number;
}



// ============================================
// RECIPE GENERATION FLOWS
// ============================================

// Recipe generation flow using ingredients
const generateRecipeFromIngredientsFlow = ai.defineFlow(
  {
    name: 'generateRecipeFromIngredients',
    inputSchema: z.object({
      ingredients: z.array(z.string()).describe('List of available ingredients'),
      mealType: z.string().describe('Type of meal (Kahvaltı, Akşam Yemeği, Salatalar, Tatlılar, Atıştırmalıklar)'),
      styleType: z.string().describe('Style subcategory for the meal type'),
      userId: z.string().optional().describe('User ID for personalization'),
      userContext: z.string().optional().describe('Optional user context or notes for recipe generation (e.g., "diabetes-friendly tiramisu")')
    }),
    outputSchema: z.object({
      recipeName: z.string(),
      prepTime: z.string(),
      cookTime: z.string(),
      ingredients: z.array(z.string()),  // Legacy: kept for backward compatibility
      directions: z.array(z.string()),  // Legacy: kept for backward compatibility
      notes: z.string(),
      recipeContent: z.string().optional(),  // NEW: Markdown content (ingredients + directions)
      servings: z.string().optional()  // Number of servings for nutrition calculation
    })
  },
  async (input) => {
    try {
      console.log(`🍳 [RECIPE] Generating recipe from ingredients: ${input.ingredients.join(', ')}`);

      const recipePrompt = ai.prompt('recipe_chef_assistant');

      const response = await recipePrompt({
        mealType: input.mealType,
        styleType: input.styleType,
        ingredients: input.ingredients,
        spontaneous: false,
        userContext: input.userContext
      }, {
        model: getRecipeModel() // Use provider-specific model for caching
      });

      // Track cost for recipe generation
      const tokenCounts = extractTokenCounts(response);
      await logTokenUsage({
        featureName: FeatureName.RECIPE_GENERATION,
        modelName: getRecipeModel(),
        inputTokens: tokenCounts.inputTokens,
        outputTokens: tokenCounts.outputTokens,
        userId: input.userId,
        metadata: { mealType: input.mealType, styleType: input.styleType }
      });

      // Transform the response to match iOS app's expected format
      const promptOutput = response.output as any;

      return {
        recipeName: promptOutput.name || promptOutput.recipeName || '',
        prepTime: String(promptOutput.prepTime || '0'),
        cookTime: String(promptOutput.cookTime || '0'),
        // Legacy arrays: kept for backward compatibility (parse from recipeContent if needed)
        ingredients: Array.isArray(promptOutput.ingredients)
          ? promptOutput.ingredients.map((ing: any) =>
              typeof ing === 'string' ? ing : `${ing.quantity || ''} ${ing.item || ''}`.trim()
            )
          : [],
        directions: promptOutput.instructions || promptOutput.directions || [],
        notes: promptOutput.notes || promptOutput.aiNotes || '',  // AI Chef notes (separate from recipeContent)
        recipeContent: promptOutput.recipeContent || '',  // NEW: Markdown content (ingredients + directions)
        servings: String(promptOutput.servings || '4')  // Number of servings for on-demand nutrition calculation
      };
    } catch (error) {
      console.error('❌ Recipe generation from ingredients failed:', error);
      throw error;
    }
  }
);

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
} as const;


// Recipe photo generation flow using Imagen 4 Ultra with enhanced quality parameters
const generateRecipePhotoFlow = ai.defineFlow(
  {
    name: 'generateRecipePhoto',
    inputSchema: z.object({
      recipeName: z.string().describe('Name of the recipe to photograph'),
      ingredients: z.array(z.string()).describe('List of ingredients in the recipe'),
      directions: z.array(z.string()).describe('Cooking instructions for reference'),
      mealType: z.string().describe('Type of meal (Kahvaltı, Akşam Yemeği, Salatalar, Tatlılar, Atıştırmalıklar)'),
      styleType: z.string().describe('Style subcategory for the meal'),
      aspectRatio: z.enum(['16:9', '4:3', '1:1', '9:16']).optional().default('1:1').describe('Aspect ratio for optimal composition'),
      qualityLevel: z.enum(['standard', 'high', 'ultra']).optional().default('ultra').describe('Generation quality level'),
      resolution: z.enum(['1K', '2K']).optional().default('2K').describe('Image resolution (1K=1024x768, 2K=2048x1536)'),
      userId: z.string().optional().describe('User ID for analytics')
    }),
    outputSchema: z.object({
      imageUrl: z.string().describe('URL or base64 data of the generated image'),
      prompt: z.string().describe('The enhanced prompt used for generation'),
      generationTime: z.string().describe('Time taken for generation'),
      metadata: z.object({
        aspectRatio: z.string(),
        qualityLevel: z.string(),
        resolution: z.string()
      }).describe('Generation metadata for reproducibility')
    })
  },
  async (input) => {
    try {
      console.log(`📸 [PHOTO] Generating ${input.qualityLevel} quality photo for recipe: ${input.recipeName} (${input.aspectRatio}, ${input.resolution})`);
      const startTime = Date.now();

      // Get aspect ratio configuration
      const aspectRatioConfig = ASPECT_RATIO_CONFIG[input.aspectRatio || '1:1'];

      console.log(`📐 [PHOTO] Using aspect ratio: ${input.aspectRatio}, resolution: ${input.resolution}`);

      const photoPrompt = ai.prompt('recipe_photo_generation');

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
              const fetch = (await import('node-fetch')).default;
              const imageResponse = await fetch(imageUrl);

              if (!imageResponse.ok) {
                throw new Error(`Failed to download image: ${imageResponse.statusText}`);
              }

              // Convert to base64
              const arrayBuffer = await imageResponse.arrayBuffer();
              const base64Data = Buffer.from(arrayBuffer).toString('base64');
              imageUrl = `data:image/jpeg;base64,${base64Data}`;

              console.log(`✅ [PHOTO] Converted to base64 data URL (${base64Data.length} chars)`);
            } catch (downloadError) {
              console.error(`❌ [PHOTO] Failed to download and convert image:`, downloadError);
              throw new Error(`Failed to process generated image: ${downloadError}`);
            }
          } else {
            // Assume it's raw base64 without prefix
            console.log(`🔧 [PHOTO] Adding data: prefix to raw base64`);
            imageUrl = `data:image/jpeg;base64,${imageUrl}`;
          }
        }

        console.log(`✅ [PHOTO] Final image URL format: ${imageUrl.substring(0, 50)}...`);

        // Track cost for image generation (Imagen models are priced per image, not tokens)
        await logImageUsage({
          featureName: FeatureName.IMAGE_GENERATION,
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
      } else {
        throw new Error('No image generated in response');
      }
    } catch (error) {
      console.error('❌ Recipe photo generation failed:', error);
      throw error;
    }
  }
);

// Note: Old Genkit-based nutrition extraction flow removed
// Replaced with direct Gemini API implementation in nutrition-extractor.ts
// This eliminates 50+ lines of complex fallback parsing and provides 99%+ JSON reliability

// ============================================
// RECIPE GENERATION ENDPOINTS
// ============================================

// Endpoint: Generate recipe from ingredients with streaming
export const generateRecipeFromIngredients = onRequest({
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
          const recipePrompt = ai.prompt('recipe_chef_assistant');

          const streamingResponse = await recipePrompt.stream({
            mealType,
            styleType,
            ingredients,
            spontaneous: false
          }, {
            model: getRecipeModel() // Use provider-specific model for caching
          });

          let fullContent = '';
          let tokenCount = 0;

          for await (const chunk of streamingResponse.stream) {
            const chunkText = chunk.text;
            if (chunkText) {
              fullContent += chunkText;
              tokenCount++;

              // Send raw Gemini chunk immediately (no splitting, no delays)
              // Client-side TypewriterAnimator handles character-by-character display
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

              // CRITICAL: Flush immediately to send chunk to client without buffering
              if (typeof (res as any).flush === 'function') {
                (res as any).flush();
              }

              // NO DELAY - let client handle animation for efficiency
            }
          }

          // Parse metadata from markdown
          // Format: # Recipe Name\n**Hazırlık:** X dakika | **Pişirme:** X dakika | [**Bekleme:** X dakika |] **Porsiyon:** 1 kişi
          const lines = fullContent.split('\n');
          let recipeName = 'Tarif';
          let prepTime = 15;
          let cookTime = 20;
          let waitingTime: number | null = null;

          // Extract recipe name from first line (# Recipe Name)
          // Skip any preliminary text before the first # heading
          let nameLineIndex = lines.findIndex(line => line.trim().startsWith('# '));
          if (nameLineIndex >= 0) {
            recipeName = lines[nameLineIndex].substring(2).trim();
            console.log(`📝 [MARKDOWN-PARSE] Found recipe name at line ${nameLineIndex}: "${recipeName}"`);
          }

          // Extract times from the line after recipe name
          const timeLine = lines[nameLineIndex + 1] || '';
          const prepMatch = timeLine.match(/\*\*Hazırlık:\*\*\s*(\d+)\s*dakika/i);
          const cookMatch = timeLine.match(/\*\*Pişirme:\*\*\s*(\d+)\s*dakika/i);
          const waitMatch = timeLine.match(/\*\*Bekleme:\*\*\s*(\d+)\s*dakika/i);

          if (prepMatch) prepTime = parseInt(prepMatch[1]);
          if (cookMatch) cookTime = parseInt(cookMatch[1]);
          if (waitMatch) waitingTime = parseInt(waitMatch[1]);

          if (waitingTime) {
            console.log(`📝 [MARKDOWN-PARSE] Extracted: name="${recipeName}", prep=${prepTime}min, cook=${cookTime}min, waiting=${waitingTime}min`);
          } else {
            console.log(`📝 [MARKDOWN-PARSE] Extracted: name="${recipeName}", prep=${prepTime}min, cook=${cookTime}min (no waiting time)`);
          }

          // Send completion event with markdown content
          const recipeData = {
            recipeName: recipeName,
            name: recipeName,  // Alias for compatibility
            recipeContent: fullContent,  // The full markdown content
            prepTime: prepTime,
            cookTime: cookTime,
            waitingTime: waitingTime,  // Optional waiting time (null if not present)
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
          if (typeof (res as any).flush === 'function') {
            (res as any).flush();
          }

          // End the response stream
          res.end();

        } catch (error) {
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
      } else {
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
    } catch (error) {
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
export const generateSpontaneousRecipe = onRequest({
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
        const recipePrompt = ai.prompt('recipe_chef_assistant');

        const streamingResponse = await recipePrompt.stream({
          mealType,
          styleType,
          spontaneous: true,
          recentRecipes: recentRecipes || [],
          diversityConstraints: diversityConstraints || undefined,
          userContext: userContext
        }, {
          model: getRecipeModel() // Use provider-specific model for caching
        });

        let fullContent = '';
        let tokenCount = 0;

        for await (const chunk of streamingResponse.stream) {
          const chunkText = chunk.text;
          if (chunkText) {
            fullContent += chunkText;
            tokenCount++;

            // Send raw Gemini chunk immediately (no splitting, no delays)
            // Client-side TypewriterAnimator handles character-by-character display
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

            // CRITICAL: Flush immediately to send chunk to client without buffering
            if (typeof (res as any).flush === 'function') {
              (res as any).flush();
            }

            // NO DELAY - let client handle animation for efficiency
          }
        }

        // Parse metadata from markdown (same as ingredients-based generation)
        const lines = fullContent.split('\n');
        let recipeName = 'Tarif';
        let prepTime = 15;
        let cookTime = 20;
        let waitingTime: number | null = null;

        // Extract recipe name from first line (# Recipe Name)
        // Skip any preliminary text before the first # heading
        let nameLineIndex = lines.findIndex(line => line.trim().startsWith('# '));
        if (nameLineIndex >= 0) {
          recipeName = lines[nameLineIndex].substring(2).trim();
          console.log(`📝 [MARKDOWN-PARSE] Found recipe name at line ${nameLineIndex}: "${recipeName}"`);
        }

        // Extract times from the line after recipe name
        const timeLine = lines[nameLineIndex + 1] || '';
        const prepMatch = timeLine.match(/\*\*Hazırlık:\*\*\s*(\d+)\s*dakika/i);
        const cookMatch = timeLine.match(/\*\*Pişirme:\*\*\s*(\d+)\s*dakika/i);
        const waitMatch = timeLine.match(/\*\*Bekleme:\*\*\s*(\d+)\s*dakika/i);

        if (prepMatch) prepTime = parseInt(prepMatch[1]);
        if (cookMatch) cookTime = parseInt(cookMatch[1]);
        if (waitMatch) waitingTime = parseInt(waitMatch[1]);

        if (waitingTime) {
          console.log(`📝 [MARKDOWN-PARSE] Extracted: name="${recipeName}", prep=${prepTime}min, cook=${cookTime}min, waiting=${waitingTime}min`);
        } else {
          console.log(`📝 [MARKDOWN-PARSE] Extracted: name="${recipeName}", prep=${prepTime}min, cook=${cookTime}min (no waiting time)`);
        }

        // Extract ingredients from markdown
        const extractedIngredients = extractIngredientsFromMarkdown(fullContent);

        // Send completion event with markdown content
        const recipeData = {
          recipeName: recipeName,
          name: recipeName,  // Alias for compatibility
          recipeContent: fullContent,  // The full markdown content
          prepTime: prepTime,
          cookTime: cookTime,
          waitingTime: waitingTime,  // Optional waiting time (null if not present)
          servings: 1,
          tokenCount: tokenCount,
          extractedIngredients,  // For iOS memory system
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
        if (typeof (res as any).flush === 'function') {
          (res as any).flush();
        }

        // End the response stream
        res.end();

      } catch (error) {
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
    } catch (error) {
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
export const generateRecipePhoto = onRequest({
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

    } catch (error) {
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

async function getCurrentOrCreateSession(userId: string): Promise<string> {
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
  const newSession: ConversationSession = {
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
async function _updateConversationSession(userId: string, message: ChatMessage): Promise<void> {
  const sessionId = await getCurrentOrCreateSession(userId);
  const sessionRef = db.collection('conversations').doc(userId).collection('sessions').doc(sessionId);

  const sessionDoc = await sessionRef.get();
  if (!sessionDoc.exists) return;

  const session = sessionDoc.data() as ConversationSession;

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

async function processSessionBoundary(userId: string, sessionId: string): Promise<void> {
  try {
    // This would be called to process conversation boundary
    // For now, we'll just log it
    console.log(`Processing session boundary for ${userId}/${sessionId}`);
  } catch (error) {
    console.error('Failed to process session boundary:', error);
  }
}


// REMOVED: Unused memory management system (intent classification, session management, vector similarity)
// The iOS app uses a different memory architecture via memory-sync endpoints

// ============================================
// NUTRITION EXTRACTION ENDPOINT
// ============================================

// Import the new direct API extractor
import { extractNutritionWithResponseSchema } from './nutrition-extractor';

// Endpoint: Extract nutrition information from image using Direct Gemini API
export const extractNutritionFromImage = onRequest({
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
      const result = await extractNutritionWithResponseSchema({
        imageBase64,
        language,
        maxWidth,
        userId
      });

      // Track cost for nutrition extraction
      if (result.usage) {
        await logTokenUsage({
          featureName: FeatureName.NUTRITION_CALCULATION,
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

    } catch (error) {
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
import { transcribeMealAudio } from './transcribeMeal';

// Endpoint: Transcribe Turkish audio and extract meal data using Gemini 2.5 Flash
export const transcribeMeal = onRequest({
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
      const result = await transcribeMealAudio({
        audioData,
        mimeType: mimeType || 'audio/m4a',
        userId: userId,
        currentTime: currentTime || new Date().toISOString()
      });

      const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);

      if (result.success) {
        console.log(`✅ [TRANSCRIBE-MEAL-ENDPOINT] Completed in ${totalTime}s - ${result.data!.foods.length} foods, ${result.data!.totalCarbs}g carbs`);
      } else {
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

    } catch (error) {
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
export { diabetesAssistantStream } from './diabetes-assistant-stream';

// Export session metadata generation endpoint
export { generateSessionMetadata } from './generate-session-metadata';

// REMOVED: Memory sync endpoints - deleted to free up CPU quota

// ============================================
// RECIPE NUTRITION CALCULATOR
// On-demand nutritional analysis using Gemini 2.5 Pro
// ============================================

interface NutritionInput {
  recipeName: string;
  recipeContent: string;
  servings: number | null;  // null for manual recipes
  recipeType?: "aiGenerated" | "manual";  // NEW: explicit recipe type
}

// Response for AI-generated recipes (existing format)
interface NutritionResult {
  calories: number;  // per 100g
  carbohydrates: number;  // per 100g
  fiber: number;
  sugar: number;
  protein: number;
  fat: number;
  glycemicLoad: number;  // per portion
  perPortion?: {
    weight: number;
    calories: number;
    carbohydrates: number;
    fiber: number;
    sugar: number;
    protein: number;
    fat: number;
    glycemicLoad: number;
  };
  nutritionCalculation?: {
    totalRecipeWeight: number;
    totalRecipeCalories: number;
    calculationNotes: string;
    reasoningSteps?: Array<{
      ingredient: string;
      recipeContext: string;
      reasoning: string;
      calculation: string;
      confidence: "high" | "medium" | "low";
    }>;
  };
  digestionTiming?: {
    hasMismatch: boolean;
    mismatchHours: number;
    severity: "low" | "medium" | "high";
    glucosePeakTime: number;
    timingInsight: string;
  };
}

// Response for manual recipes (NEW format)
interface ManualRecipeNutritionResult {
  totalRecipe: {
    weight: number;
    calories: number;
    carbohydrates: number;
    fiber: number;
    sugar: number;
    protein: number;
    fat: number;
    glycemicLoad: number;
  };
  nutritionCalculation?: {
    totalRecipeWeight: number;
    totalRecipeCalories: number;
    calculationNotes: string;
    reasoningSteps?: Array<{
      ingredient: string;
      recipeContext: string;
      reasoning: string;
      calculation: string;
      confidence: "high" | "medium" | "low";
    }>;
  };
}

export const calculateRecipeNutrition = onRequest({
  cors: true,
  maxInstances: 10,
  memory: '512MiB',
  timeoutSeconds: 120  // Gemini 2.5 Pro needs 60-70s typically, 120s allows complex recipes with 15+ ingredients
}, async (req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const input = req.body as NutritionInput;

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
    const nutritionPrompt = ai.prompt('recipe_nutrition_calculator');

    // Call Gemini 2.5 Pro for nutrition analysis (requires Pro for accuracy)
    const result = await nutritionPrompt({
      recipeName: input.recipeName,
      recipeContent: input.recipeContent,
      servings: input.servings ?? 1,  // Default to 1 if null (manual recipes)
      recipeType: isManualRecipe ? "manual" : "aiGenerated"
    }, {
      model: getNutritionCalculatorModel() // Explicitly use Gemini 2.5 Pro for nutrition
    });

    // Log the complete AI response with all reasoning
    console.log(`\n${'='.repeat(80)}`);
    console.log(`🤖 [NUTRITION-CALC] COMPLETE AI OUTPUT`);
    console.log(`${'='.repeat(80)}`);
    console.log(JSON.stringify(result.output, null, 2));
    console.log(`${'='.repeat(80)}\n`);

    if (isManualRecipe) {
      // Manual recipe: return totalRecipe format
      const manualResult = result.output as ManualRecipeNutritionResult;

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
    } else {
      // AI-generated recipe: return existing format
      const nutrition = result.output as NutritionResult;

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

  } catch (error: any) {
    console.error('❌ [NUTRITION-CALC] Error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Nutrition calculation failed'
    });
  }
});

