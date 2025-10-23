"use strict";
/**
 * Analytics Manager
 *
 * Aggregates diversity metrics and provides insights over time.
 * Helps users understand their recipe variety patterns.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateDiversityMetrics = calculateDiversityMetrics;
exports.saveDiversityMetrics = saveDiversityMetrics;
exports.getLatestMetrics = getLatestMetrics;
exports.generateInsights = generateInsights;
exports.aggregateAllUserMetrics = aggregateAllUserMetrics;
exports.getUserDiversitySummary = getUserDiversitySummary;
const firestore_1 = require("firebase-admin/firestore");
const genkit_instance_1 = require("../genkit-instance");
// ============================================================================
// METRICS CALCULATION
// ============================================================================
/**
 * Calculate diversity metrics for a user over a time window
 *
 * @param userId - User ID
 * @param windowDays - Number of days to analyze (default: 30)
 * @returns Comprehensive diversity metrics
 */
async function calculateDiversityMetrics(userId, windowDays = 30) {
    try {
        // Fetch recipes from the time window
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - windowDays);
        const snapshot = await genkit_instance_1.db
            .collection('recipe_memory')
            .where('userId', '==', userId)
            .where('createdAt', '>=', firestore_1.Timestamp.fromDate(cutoffDate))
            .orderBy('createdAt', 'desc')
            .get();
        const recipes = snapshot.docs.map((doc) => doc.data());
        console.log(`📊 [ANALYTICS] Analyzing ${recipes.length} recipes for user ${userId} (last ${windowDays} days)`);
        // Calculate distributions
        const cuisineDistribution = calculateDistribution(recipes, (r) => r.metadata.cuisine);
        const proteinDistribution = calculateDistribution(recipes, (r) => r.metadata.primaryProtein);
        const cookingMethodDistribution = calculateDistribution(recipes, (r) => r.metadata.cookingMethod);
        // Calculate diversity scores over time (if available)
        const diversityScores = recipes
            .map((r) => r.similarityScore)
            .filter((score) => score !== undefined);
        const averageDiversityScore = diversityScores.length > 0
            ? diversityScores.reduce((a, b) => a + b, 0) / diversityScores.length
            : 0;
        // Detect trend (compare first half vs second half)
        const trend = detectTrend(diversityScores);
        // Find underrepresented categories
        const underrepresentedCuisines = findUnderrepresented(cuisineDistribution, ALL_CUISINES, recipes.length);
        const underrepresentedProteins = findUnderrepresented(proteinDistribution, ALL_PROTEINS, recipes.length);
        const suggestedCookingMethods = findUnderrepresented(cookingMethodDistribution, ALL_COOKING_METHODS, recipes.length);
        // Build metrics object
        const metrics = {
            userId,
            windowStartDate: firestore_1.Timestamp.fromDate(cutoffDate),
            windowEndDate: firestore_1.Timestamp.now(),
            cuisineDistribution,
            proteinDistribution,
            cookingMethodDistribution,
            averageDiversityScore,
            diversityTrend: trend,
            underrepresentedCuisines,
            underrepresentedProteins,
            suggestedCookingMethods,
            totalRecipes: recipes.length,
            uniqueCuisines: Object.keys(cuisineDistribution).length,
            uniqueProteins: Object.keys(proteinDistribution).length,
            calculatedAt: firestore_1.Timestamp.now(),
        };
        console.log(`✅ [ANALYTICS] Calculated metrics for user ${userId}`);
        return metrics;
    }
    catch (error) {
        console.error(`❌ [ANALYTICS] Error calculating metrics:`, error);
        throw new Error(`Failed to calculate diversity metrics: ${error}`);
    }
}
/**
 * Save diversity metrics to Firestore
 */
async function saveDiversityMetrics(metrics) {
    try {
        const docId = `${metrics.userId}_${metrics.windowEndDate.toMillis()}`;
        await genkit_instance_1.db.collection('diversity_metrics').doc(docId).set(metrics);
        console.log(`✅ [ANALYTICS] Saved metrics for user ${metrics.userId}`);
    }
    catch (error) {
        console.error(`❌ [ANALYTICS] Error saving metrics:`, error);
        throw new Error(`Failed to save diversity metrics: ${error}`);
    }
}
/**
 * Get latest diversity metrics for a user
 */
async function getLatestMetrics(userId) {
    try {
        const snapshot = await genkit_instance_1.db
            .collection('diversity_metrics')
            .where('userId', '==', userId)
            .orderBy('calculatedAt', 'desc')
            .limit(1)
            .get();
        if (snapshot.empty) {
            return null;
        }
        return snapshot.docs[0].data();
    }
    catch (error) {
        console.error(`❌ [ANALYTICS] Error fetching metrics:`, error);
        return null;
    }
}
// ============================================================================
// HELPER FUNCTIONS
// ============================================================================
/**
 * Calculate distribution of a specific attribute
 */
function calculateDistribution(recipes, extractor) {
    const distribution = {};
    recipes.forEach((recipe) => {
        const value = extractor(recipe);
        if (value) {
            distribution[value] = (distribution[value] || 0) + 1;
        }
    });
    return distribution;
}
/**
 * Detect trend in diversity scores over time
 */
function detectTrend(scores) {
    if (scores.length < 4) {
        return 'stable'; // Not enough data
    }
    // Split into two halves
    const midpoint = Math.floor(scores.length / 2);
    const firstHalf = scores.slice(0, midpoint);
    const secondHalf = scores.slice(midpoint);
    const avgFirst = firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length;
    const avgSecond = secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length;
    const difference = avgSecond - avgFirst;
    if (difference > 0.05) {
        return 'improving';
    }
    else if (difference < -0.05) {
        return 'declining';
    }
    else {
        return 'stable';
    }
}
/**
 * Find underrepresented categories
 */
function findUnderrepresented(distribution, allOptions, totalRecipes) {
    if (totalRecipes < 5) {
        return []; // Not enough data for recommendations
    }
    // Find options that appear less than 10% of the time or not at all
    const threshold = Math.max(1, totalRecipes * 0.1);
    return allOptions.filter((option) => {
        const count = distribution[option] || 0;
        return count < threshold;
    });
}
// ============================================================================
// REFERENCE DATA
// ============================================================================
const ALL_CUISINES = [
    'Italian',
    'Thai',
    'Mexican',
    'Japanese',
    'Mediterranean',
    'Indian',
    'Chinese',
    'French',
    'Turkish',
    'Korean',
    'Vietnamese',
    'Greek',
    'Spanish',
    'Middle Eastern',
    'American',
];
const ALL_PROTEINS = [
    'chicken',
    'beef',
    'fish',
    'pork',
    'lamb',
    'tofu',
    'vegetarian',
    'eggs',
    'seafood',
    'turkey',
];
const ALL_COOKING_METHODS = [
    'baking',
    'grilling',
    'stir-fry',
    'boiling',
    'steaming',
    'frying',
    'roasting',
    'sautéing',
    'braising',
    'slow-cooking',
];
// ============================================================================
// INSIGHTS GENERATION
// ============================================================================
/**
 * Generate human-readable insights from metrics
 */
function generateInsights(metrics) {
    const insights = {
        summary: '',
        recommendations: [],
        achievements: [],
    };
    // Summary
    const diversityLevel = metrics.averageDiversityScore >= 0.7
        ? 'excellent'
        : metrics.averageDiversityScore >= 0.5
            ? 'good'
            : 'moderate';
    insights.summary = `Your recipe diversity is ${diversityLevel} with ${metrics.uniqueCuisines} different cuisines and ${metrics.uniqueProteins} protein sources over ${metrics.totalRecipes} recipes.`;
    // Achievements
    if (metrics.uniqueCuisines >= 10) {
        insights.achievements.push('🌍 World Explorer: Tried 10+ different cuisines!');
    }
    if (metrics.uniqueProteins >= 6) {
        insights.achievements.push('🥩 Protein Master: Explored 6+ protein sources!');
    }
    if (metrics.diversityTrend === 'improving') {
        insights.achievements.push('📈 Trend Setter: Your diversity is improving over time!');
    }
    // Recommendations
    if (metrics.underrepresentedCuisines.length > 0) {
        const suggestions = metrics.underrepresentedCuisines.slice(0, 3).join(', ');
        insights.recommendations.push(`🍽️ Try new cuisines: ${suggestions}`);
    }
    if (metrics.underrepresentedProteins.length > 0) {
        const suggestions = metrics.underrepresentedProteins.slice(0, 3).join(', ');
        insights.recommendations.push(`🥘 Explore proteins: ${suggestions}`);
    }
    if (metrics.diversityTrend === 'declining') {
        insights.recommendations.push('⚠️ Your variety is declining - try something completely new!');
    }
    // Specific cuisine recommendations
    const topCuisine = Object.entries(metrics.cuisineDistribution)
        .sort(([, a], [, b]) => b - a)[0];
    if (topCuisine && topCuisine[1] > metrics.totalRecipes * 0.4) {
        insights.recommendations.push(`📊 You're cooking a lot of ${topCuisine[0]} - branch out to other cuisines!`);
    }
    return insights;
}
// ============================================================================
// SCHEDULED AGGREGATION (Optional)
// ============================================================================
/**
 * Aggregate metrics for all active users (run as scheduled function)
 *
 * This could be triggered by a Cloud Scheduler job (e.g., weekly)
 */
async function aggregateAllUserMetrics() {
    let processed = 0;
    let errors = 0;
    try {
        // Get all users who have generated recipes in last 30 days
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - 30);
        const snapshot = await genkit_instance_1.db
            .collection('recipe_memory')
            .where('createdAt', '>=', firestore_1.Timestamp.fromDate(cutoffDate))
            .get();
        // Get unique user IDs
        const userIds = new Set();
        snapshot.docs.forEach((doc) => {
            const data = doc.data();
            userIds.add(data.userId);
        });
        console.log(`📊 [ANALYTICS] Aggregating metrics for ${userIds.size} users`);
        // Calculate and save metrics for each user
        for (const userId of userIds) {
            try {
                const metrics = await calculateDiversityMetrics(userId, 30);
                await saveDiversityMetrics(metrics);
                processed++;
            }
            catch (error) {
                console.error(`❌ [ANALYTICS] Error processing user ${userId}:`, error);
                errors++;
            }
        }
        console.log(`✅ [ANALYTICS] Aggregation complete: ${processed} processed, ${errors} errors`);
    }
    catch (error) {
        console.error(`❌ [ANALYTICS] Fatal error in aggregation:`, error);
        throw error;
    }
    return { processed, errors };
}
// ============================================================================
// EXPORT FUNCTIONS
// ============================================================================
/**
 * Get user's diversity summary (for iOS client)
 */
async function getUserDiversitySummary(userId) {
    // Try to get cached metrics first
    let metrics = await getLatestMetrics(userId);
    // If no cached metrics or older than 7 days, recalculate
    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    if (!metrics || metrics.calculatedAt.toMillis() < sevenDaysAgo) {
        console.log(`📊 [ANALYTICS] Recalculating metrics for user ${userId}`);
        metrics = await calculateDiversityMetrics(userId, 30);
        await saveDiversityMetrics(metrics);
    }
    const insights = metrics ? generateInsights(metrics) : {
        summary: 'Start generating recipes to see your diversity metrics!',
        recommendations: [],
        achievements: [],
    };
    return { metrics, insights };
}
//# sourceMappingURL=analytics-manager.js.map