"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getRecentRecipes = getRecentRecipes;
exports.saveRecipeMemory = saveRecipeMemory;
exports.getRecipeById = getRecipeById;
exports.cleanupOldRecipes = cleanupOldRecipes;
const firestore_1 = require("firebase-admin/firestore");
const uuid_1 = require("uuid");
const db = (0, firestore_1.getFirestore)();
const COLLECTION = 'recipe_memory';
// Legacy function removed - metadata is now generated directly by Gemini in structured format
// Previously: parseMetadataFromNotes(notes: string) -> RecipeMetadata
// No longer needed as Gemini 2.5 Flash generates metadata directly in the recipe JSON
/**
 * Get recent recipes for a user within a time window
 */
async function getRecentRecipes(userId, windowDays = 14) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - windowDays);
    try {
        const snapshot = await db
            .collection(COLLECTION)
            .where('userId', '==', userId)
            .where('createdAt', '>=', firestore_1.Timestamp.fromDate(cutoffDate))
            .orderBy('createdAt', 'desc')
            .limit(20) // Reasonable cap for performance
            .get();
        const recipes = [];
        snapshot.forEach((doc) => {
            recipes.push(doc.data());
        });
        return recipes;
    }
    catch (error) {
        console.error('Error fetching recent recipes:', error);
        // Fail gracefully - return empty array so generation continues
        return [];
    }
}
/**
 * Save a new recipe to memory with embedding
 */
async function saveRecipeMemory(params) {
    const { userId, conversationId, recipe, embedding, generationAttempt, wasRetried, similarityScore, } = params;
    const recipeId = (0, uuid_1.v4)();
    const now = firestore_1.Timestamp.now();
    // Use metadata from recipe (Gemini generates this directly now)
    const metadata = recipe.metadata || {};
    // Build recipe memory object (conditionally include optional fields)
    const recipeMemory = {
        recipeId,
        userId,
        conversationId,
        recipeName: recipe.name,
        recipeDescription: recipe.description || '', // Optional field, provide empty string as fallback
        fullRecipeJson: recipe,
        embedding,
        embeddingModel: 'gemini-embedding-001',
        metadata,
        createdAt: now,
        lastAccessedAt: now,
        generationAttempt,
        wasRetried,
        ...(similarityScore !== undefined && { similarityScore }),
    };
    try {
        await db.collection(COLLECTION).doc(recipeId).set(recipeMemory);
        console.log(`✅ Saved recipe memory: ${recipeId} (${recipe.name})`);
        return recipeId;
    }
    catch (error) {
        console.error('❌ Error saving recipe memory:', error);
        throw error;
    }
}
/**
 * Get a specific recipe by ID
 */
async function getRecipeById(recipeId) {
    try {
        const doc = await db.collection(COLLECTION).doc(recipeId).get();
        if (!doc.exists) {
            return null;
        }
        return doc.data();
    }
    catch (error) {
        console.error('Error fetching recipe by ID:', error);
        return null;
    }
}
/**
 * Cleanup old recipes (data retention policy)
 * Can be called by a scheduled function
 */
async function cleanupOldRecipes(userId, retentionDays = 90) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
    try {
        const snapshot = await db
            .collection(COLLECTION)
            .where('userId', '==', userId)
            .where('createdAt', '<', firestore_1.Timestamp.fromDate(cutoffDate))
            .get();
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(`🧹 Cleaned up ${snapshot.size} old recipes for user ${userId}`);
        return snapshot.size;
    }
    catch (error) {
        console.error('Error cleaning up old recipes:', error);
        return 0;
    }
}
//# sourceMappingURL=memory-store.js.map