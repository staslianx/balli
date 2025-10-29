//
// test-recipe-generation.ts
// Automated testing script for recipe generation with memory functionality
//

import * as dotenv from 'dotenv';
import * as fs from 'fs';
import * as path from 'path';
dotenv.config();

interface MemoryEntry {
  title: string;
  mainIngredient: string;
  cookingMethod: string;
}

interface RecipeResponse {
  name: string;
  calories: number;
  carbohydrates: number;
  fiber: number;
  sugar: number;
  protein: number;
  fat: number;
  glycemicLoad: number;
  servings: number;
  prepTime: number;
  cookTime: number;
  metadata: {
    cuisine: string;
    primaryProtein: string;
    cookingMethod: string;
    mealType: string;
    difficulty: string;
    dietaryTags: string[];
  };
  notes: string;
  recipeContent: string;
  extractedIngredients?: string[];
}

interface TestResult {
  recipeNumber: number;
  category: string;
  subcategory: string;
  recipe: RecipeResponse;
  generationTime: number;
  unique: boolean;
  memoryWorking: boolean;
  issues: string[];
}

// Cloud Function URL
const FUNCTION_URL = 'https://generatespontaneousrecipe-gzc54elfeq-uc.a.run.app';

// Memory storage per subcategory
const memoryStorage: Map<string, MemoryEntry[]> = new Map();

/**
 * Generate a single recipe
 */
async function generateRecipe(
  mealType: string,
  styleType: string,
  recipeNumber: number
): Promise<TestResult> {
  const startTime = Date.now();
  const categoryKey = `${mealType}:${styleType}`;

  console.log(`\n${'='.repeat(80)}`);
  console.log(`🔄 Recipe ${recipeNumber}: ${mealType} - ${styleType}`);
  console.log(`${'='.repeat(80)}`);

  // Get memory entries for this subcategory
  const memoryEntries = memoryStorage.get(categoryKey) || [];

  if (memoryEntries.length > 0) {
    console.log(`\n📝 Memory Context (${memoryEntries.length} entries):`);
    memoryEntries.forEach((entry, i) => {
      console.log(`   ${i + 1}. "${entry.title}" - ${entry.mainIngredient} (${entry.cookingMethod})`);
    });
  }

  const requestBody = {
    mealType,
    styleType,
    memoryEntries
  };

  try {
    const response = await fetch(FUNCTION_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`HTTP ${response.status}: ${errorText}`);
    }

    // Parse SSE stream
    const text = await response.text();
    const lines = text.split('\n');

    let recipe: RecipeResponse | null = null;

    // Look for the "completed" event which contains the final recipe
    for (let i = 0; i < lines.length; i++) {
      if (lines[i] === 'event: completed') {
        // Next line should have the data
        if (i + 1 < lines.length && lines[i + 1].startsWith('data: ')) {
          try {
            const jsonData = JSON.parse(lines[i + 1].substring(6));

            // The recipe data is directly in jsonData.data
            if (jsonData.data) {
              recipe = jsonData.data as RecipeResponse;
              break;
            }
          } catch (e) {
            console.error('Failed to parse completed event:', e);
          }
        }
      }
    }

    if (!recipe) {
      console.error('❌ Failed to parse recipe from response');
      console.error('Total lines:', lines.length);
      console.error('Looking for "event: completed"...');
      const completedIndex = lines.findIndex(l => l === 'event: completed');
      if (completedIndex >= 0) {
        console.error('Found "event: completed" at line', completedIndex);
        console.error('Next line:', lines[completedIndex + 1]?.substring(0, 200));
      } else {
        console.error('No "event: completed" found');
      }
      throw new Error('No recipe data found in response');
    }

    const generationTime = Date.now() - startTime;

    console.log(`\n✅ Generated in ${(generationTime / 1000).toFixed(1)}s`);
    console.log(`\n📖 Recipe: "${recipe.name}"`);
    console.log(`   Protein: ${recipe.metadata.primaryProtein}`);
    console.log(`   Cuisine: ${recipe.metadata.cuisine}`);
    console.log(`   Method: ${recipe.metadata.cookingMethod}`);
    console.log(`\n📊 Nutrition (per 100g):`);
    console.log(`   Calories: ${recipe.calories} kcal`);
    console.log(`   Carbs: ${recipe.carbohydrates}g (Fiber: ${recipe.fiber}g, Sugar: ${recipe.sugar}g)`);
    console.log(`   Protein: ${recipe.protein}g`);
    console.log(`   Fat: ${recipe.fat}g`);
    console.log(`   Glycemic Load: ${recipe.glycemicLoad}`);

    // Check for forbidden words
    const forbiddenWords = ['büyü', 'rüya', 'cennet', 'sihir'];
    const hasForbiddenWords = forbiddenWords.some(word =>
      recipe.name.toLowerCase().includes(word)
    );

    // Extract ingredients from recipe content
    const ingredientSection = recipe.recipeContent.match(/## Malzemeler\n---\n([\s\S]*?)\n\n## Yapılışı/);
    const ingredients = ingredientSection
      ? ingredientSection[1].split('\n').filter(line => line.trim().startsWith('-'))
      : [];

    console.log(`\n🥘 Ingredients (${ingredients.length}):`);
    ingredients.slice(0, 5).forEach(ing => console.log(`   ${ing}`));
    if (ingredients.length > 5) console.log(`   ... and ${ingredients.length - 5} more`);

    // Check uniqueness against memory
    const issues: string[] = [];
    let unique = true;
    let memoryWorking = true;

    if (memoryEntries.length > 0) {
      // Check if name is repeated
      const nameRepeated = memoryEntries.some(e => e.title === recipe.name);
      if (nameRepeated) {
        issues.push(`❌ Recipe name "${recipe.name}" is repeated!`);
        unique = false;
      }

      // Check if protein is overused (more than 2 times in last 3 recipes)
      const recentProteins = memoryEntries.slice(-3).map(e => e.mainIngredient.toLowerCase());
      const proteinCount = recentProteins.filter(p =>
        p.includes(recipe.metadata.primaryProtein.toLowerCase())
      ).length;

      if (proteinCount >= 2) {
        issues.push(`⚠️ Protein "${recipe.metadata.primaryProtein}" used ${proteinCount + 1} times in last 4 recipes`);
        memoryWorking = false;
      }

      // Check if cooking method is overused
      const recentMethods = memoryEntries.slice(-3).map(e => e.cookingMethod.toLowerCase());
      const methodCount = recentMethods.filter(m =>
        m.includes(recipe.metadata.cookingMethod.toLowerCase())
      ).length;

      if (methodCount >= 2) {
        issues.push(`⚠️ Method "${recipe.metadata.cookingMethod}" used ${methodCount + 1} times in last 4 recipes`);
        memoryWorking = false;
      }
    }

    // Validate recipe structure
    if (!recipe.recipeContent.includes('## Malzemeler')) {
      issues.push('❌ Missing "## Malzemeler" section');
    }
    if (!recipe.recipeContent.includes('## Yapılışı')) {
      issues.push('❌ Missing "## Yapılışı" section');
    }
    if (!recipe.recipeContent.includes('---')) {
      issues.push('❌ Missing "---" separator after headers');
    }
    if (recipe.name.split(' ').length > 4) {
      issues.push(`⚠️ Recipe name too long (${recipe.name.split(' ').length} words)`);
    }
    if (hasForbiddenWords) {
      issues.push('❌ Recipe name contains forbidden words (büyü/rüya/cennet/sihir)');
    }

    // For desserts, check sweetener and flour
    if (mealType === 'Tatlılar') {
      const content = recipe.recipeContent.toLowerCase();
      const hasSugar = content.includes('şeker') &&
                      !content.includes('kan şeker') &&
                      !content.includes('şeker tozu değil');
      const hasWhiteFlour = content.includes('beyaz un') ||
                           (content.includes('un') && !content.includes('tam buğday') && !content.includes('badem'));

      if (hasSugar) {
        issues.push('❌ Dessert contains regular sugar (should use stevia/erythritol)');
      }
      if (hasWhiteFlour) {
        issues.push('❌ Dessert contains white flour (should use whole wheat/almond)');
      }
      if (recipe.glycemicLoad > 15) {
        issues.push(`⚠️ Glycemic load ${recipe.glycemicLoad} exceeds diabetes-friendly threshold (15)`);
      }
    }

    // For whole wheat pasta, verify
    if (styleType === 'Tam Buğday Makarna') {
      const content = recipe.recipeContent.toLowerCase();
      const hasWholeWheat = content.includes('tam buğday makarna') || content.includes('tam buğday');
      if (!hasWholeWheat) {
        issues.push('❌ Recipe should specify whole wheat pasta (tam buğday makarna)');
      }
    }

    // Print issues
    if (issues.length > 0) {
      console.log(`\n⚠️ Issues Found (${issues.length}):`);
      issues.forEach(issue => console.log(`   ${issue}`));
    } else {
      console.log(`\n✅ No issues found - recipe passed all checks!`);
    }

    // Store in memory
    const memoryEntry: MemoryEntry = {
      title: recipe.name,
      mainIngredient: recipe.metadata.primaryProtein,
      cookingMethod: recipe.metadata.cookingMethod
    };

    const currentMemory = memoryStorage.get(categoryKey) || [];
    currentMemory.push(memoryEntry);

    // Keep only last 10 for memory context
    if (currentMemory.length > 10) {
      currentMemory.shift();
    }

    memoryStorage.set(categoryKey, currentMemory);
    console.log(`\n💾 Stored in memory (${currentMemory.length} total for this category)`);

    return {
      recipeNumber,
      category: mealType,
      subcategory: styleType,
      recipe,
      generationTime,
      unique,
      memoryWorking,
      issues
    };

  } catch (error) {
    console.error(`\n❌ Error generating recipe:`, error);
    throw error;
  }
}

/**
 * Run all 15 recipe tests
 */
async function runTests() {
  console.log(`\n${'█'.repeat(80)}`);
  console.log(`🧪 RECIPE GENERATION TESTING - 15 RECIPES`);
  console.log(`${'█'.repeat(80)}`);
  console.log(`Function URL: ${FUNCTION_URL}`);
  console.log(`Started at: ${new Date().toISOString()}`);

  const results: TestResult[] = [];
  let currentRecipe = 1;

  try {
    // Batch 1: Akşam Yemeği - Karbonhidrat ve Protein Uyumu (3 recipes)
    console.log(`\n\n${'▓'.repeat(80)}`);
    console.log(`📦 BATCH 1: Akşam Yemeği - Karbonhidrat ve Protein Uyumu (3 recipes)`);
    console.log(`${'▓'.repeat(80)}`);

    for (let i = 0; i < 3; i++) {
      const result = await generateRecipe('Akşam Yemeği', 'Karbonhidrat ve Protein Uyumu', currentRecipe++);
      results.push(result);
      await new Promise(resolve => setTimeout(resolve, 2000)); // 2 second delay
    }

    // Batch 2: Akşam Yemeği - Tam Buğday Makarna (2 recipes)
    console.log(`\n\n${'▓'.repeat(80)}`);
    console.log(`📦 BATCH 2: Akşam Yemeği - Tam Buğday Makarna (2 recipes)`);
    console.log(`${'▓'.repeat(80)}`);

    for (let i = 0; i < 2; i++) {
      const result = await generateRecipe('Akşam Yemeği', 'Tam Buğday Makarna', currentRecipe++);
      results.push(result);
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Batch 3: Tatlılar - Sana Özel Tatlılar (5 recipes)
    console.log(`\n\n${'▓'.repeat(80)}`);
    console.log(`📦 BATCH 3: Tatlılar - Sana Özel Tatlılar (5 recipes)`);
    console.log(`${'▓'.repeat(80)}`);

    for (let i = 0; i < 5; i++) {
      const result = await generateRecipe('Tatlılar', 'Sana Özel Tatlılar', currentRecipe++);
      results.push(result);
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Batch 4: Atıştırmalıklar (2 recipes)
    console.log(`\n\n${'▓'.repeat(80)}`);
    console.log(`📦 BATCH 4: Atıştırmalıklar (2 recipes)`);
    console.log(`${'▓'.repeat(80)}`);

    for (let i = 0; i < 2; i++) {
      const result = await generateRecipe('Atıştırmalıklar', 'Atıştırmalıklar', currentRecipe++);
      results.push(result);
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Batch 5: Kahvaltı (2 recipes)
    console.log(`\n\n${'▓'.repeat(80)}`);
    console.log(`📦 BATCH 5: Kahvaltı (2 recipes)`);
    console.log(`${'▓'.repeat(80)}`);

    for (let i = 0; i < 2; i++) {
      const result = await generateRecipe('Kahvaltı', 'Kahvaltı', currentRecipe++);
      results.push(result);
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Batch 6: Salatalar - Doyurucu Salata (1 recipe)
    console.log(`\n\n${'▓'.repeat(80)}`);
    console.log(`📦 BATCH 6: Salatalar - Doyurucu Salata (1 recipe)`);
    console.log(`${'▓'.repeat(80)}`);

    const result = await generateRecipe('Salatalar', 'Doyurucu Salata', currentRecipe++);
    results.push(result);

    // Generate test report
    generateReport(results);

  } catch (error) {
    console.error('\n\n❌ Testing failed:', error);
    process.exit(1);
  }
}

/**
 * Generate comprehensive test report
 */
function generateReport(results: TestResult[]) {
  console.log(`\n\n${'█'.repeat(80)}`);
  console.log(`📊 TEST REPORT - RECIPE GENERATION VALIDATION`);
  console.log(`${'█'.repeat(80)}`);

  // Summary statistics
  const totalRecipes = results.length;
  const uniqueRecipes = results.filter(r => r.unique).length;
  const memoryWorkingCount = results.filter(r => r.memoryWorking).length;
  const totalIssues = results.reduce((sum, r) => sum + r.issues.length, 0);
  const avgGenerationTime = results.reduce((sum, r) => sum + r.generationTime, 0) / results.length;

  console.log(`\n📈 Summary Statistics:`);
  console.log(`   Total Recipes: ${totalRecipes}`);
  console.log(`   Unique Recipes: ${uniqueRecipes}/${totalRecipes} (${(uniqueRecipes/totalRecipes*100).toFixed(1)}%)`);
  console.log(`   Memory Working: ${memoryWorkingCount}/${totalRecipes} (${(memoryWorkingCount/totalRecipes*100).toFixed(1)}%)`);
  console.log(`   Total Issues: ${totalIssues}`);
  console.log(`   Avg Generation Time: ${(avgGenerationTime/1000).toFixed(1)}s`);

  // Results by category
  console.log(`\n\n📋 Results by Category:\n`);

  const categories = [...new Set(results.map(r => `${r.category} - ${r.subcategory}`))];

  categories.forEach(category => {
    const categoryResults = results.filter(r => `${r.category} - ${r.subcategory}` === category);
    console.log(`\n${'─'.repeat(80)}`);
    console.log(`📁 ${category} (${categoryResults.length} recipes)`);
    console.log(`${'─'.repeat(80)}`);

    categoryResults.forEach(result => {
      const status = result.issues.length === 0 ? '✅' : '⚠️';
      console.log(`\n${status} Recipe #${result.recipeNumber}: "${result.recipe.name}"`);
      console.log(`   Protein: ${result.recipe.metadata.primaryProtein}`);
      console.log(`   Method: ${result.recipe.metadata.cookingMethod}`);
      console.log(`   Cuisine: ${result.recipe.metadata.cuisine}`);
      console.log(`   Time: ${(result.generationTime/1000).toFixed(1)}s`);
      console.log(`   Unique: ${result.unique ? '✅' : '❌'}`);
      console.log(`   Memory Working: ${result.memoryWorking ? '✅' : '⚠️'}`);

      if (result.issues.length > 0) {
        console.log(`   Issues (${result.issues.length}):`);
        result.issues.forEach(issue => console.log(`      ${issue}`));
      }
    });
  });

  // Critical issues summary
  console.log(`\n\n${'█'.repeat(80)}`);
  console.log(`🚨 Critical Issues Summary`);
  console.log(`${'█'.repeat(80)}`);

  const criticalIssues = results.filter(r =>
    r.issues.some(i => i.startsWith('❌'))
  );

  if (criticalIssues.length > 0) {
    console.log(`\n⚠️ Found ${criticalIssues.length} recipes with critical issues:\n`);
    criticalIssues.forEach(result => {
      console.log(`Recipe #${result.recipeNumber} "${result.recipe.name}":`);
      result.issues.filter(i => i.startsWith('❌')).forEach(issue => {
        console.log(`   ${issue}`);
      });
    });
  } else {
    console.log(`\n✅ No critical issues found!`);
  }

  // Memory effectiveness analysis
  console.log(`\n\n${'█'.repeat(80)}`);
  console.log(`🧠 Memory System Analysis`);
  console.log(`${'█'.repeat(80)}`);

  categories.forEach(category => {
    const categoryResults = results.filter(r => `${r.category} - ${r.subcategory}` === category);

    if (categoryResults.length >= 3) {
      console.log(`\n📁 ${category}:`);

      // Check protein diversity
      const proteins = categoryResults.map(r => r.recipe.metadata.primaryProtein);
      const uniqueProteins = new Set(proteins);
      console.log(`   Protein Diversity: ${uniqueProteins.size}/${proteins.length} unique`);
      console.log(`   Proteins used: ${Array.from(uniqueProteins).join(', ')}`);

      // Check method diversity
      const methods = categoryResults.map(r => r.recipe.metadata.cookingMethod);
      const uniqueMethods = new Set(methods);
      console.log(`   Method Diversity: ${uniqueMethods.size}/${methods.length} unique`);
      console.log(`   Methods used: ${Array.from(uniqueMethods).join(', ')}`);

      // Check cuisine diversity
      const cuisines = categoryResults.map(r => r.recipe.metadata.cuisine);
      const uniqueCuisines = new Set(cuisines);
      console.log(`   Cuisine Diversity: ${uniqueCuisines.size}/${cuisines.length} unique`);
      console.log(`   Cuisines used: ${Array.from(uniqueCuisines).join(', ')}`);
    }
  });

  // Final verdict
  console.log(`\n\n${'█'.repeat(80)}`);
  console.log(`🎯 Final Verdict`);
  console.log(`${'█'.repeat(80)}`);

  const passRate = (uniqueRecipes / totalRecipes) * 100;
  const memoryRate = (memoryWorkingCount / totalRecipes) * 100;

  let verdict = '✅ PASS';
  let reason = 'All tests passed successfully!';

  if (passRate < 90) {
    verdict = '❌ FAIL';
    reason = `Uniqueness rate ${passRate.toFixed(1)}% is below 90% threshold`;
  } else if (memoryRate < 70) {
    verdict = '⚠️ WARNING';
    reason = `Memory effectiveness ${memoryRate.toFixed(1)}% is below 70% threshold`;
  } else if (totalIssues > 5) {
    verdict = '⚠️ WARNING';
    reason = `Total issues (${totalIssues}) exceeds acceptable threshold (5)`;
  }

  console.log(`\n${verdict}`);
  console.log(`Reason: ${reason}`);
  console.log(`\nUniqueness Rate: ${passRate.toFixed(1)}%`);
  console.log(`Memory Effectiveness: ${memoryRate.toFixed(1)}%`);
  console.log(`Average Generation Time: ${(avgGenerationTime/1000).toFixed(1)}s`);
  console.log(`Total Issues: ${totalIssues}`);

  // Recommendations
  console.log(`\n\n📝 Recommendations:`);

  if (passRate < 100) {
    console.log(`   1. Review repeated recipes and adjust prompt diversity instructions`);
  }
  if (memoryRate < 90) {
    console.log(`   2. Strengthen memory context passing and diversity constraints`);
  }
  if (avgGenerationTime > 30000) {
    console.log(`   3. Optimize generation time (currently ${(avgGenerationTime/1000).toFixed(1)}s)`);
  }
  if (totalIssues === 0) {
    console.log(`   ✅ No recommendations - system is working perfectly!`);
  }

  console.log(`\n${'█'.repeat(80)}`);
  console.log(`Testing completed at: ${new Date().toISOString()}`);
  console.log(`${'█'.repeat(80)}\n`);

  // Save JSON report
  const jsonReport = {
    testDate: new Date().toISOString(),
    summary: {
      totalRecipes,
      uniqueRecipes,
      uniquenessRate: (uniqueRecipes/totalRecipes*100).toFixed(1) + '%',
      memoryWorkingCount,
      memoryEffectiveness: (memoryWorkingCount/totalRecipes*100).toFixed(1) + '%',
      totalIssues,
      avgGenerationTimeMs: Math.round(avgGenerationTime),
      avgGenerationTimeSec: (avgGenerationTime/1000).toFixed(1) + 's',
      verdict,
      reason
    },
    results: results.map(r => ({
      recipeNumber: r.recipeNumber,
      category: r.category,
      subcategory: r.subcategory,
      recipeName: r.recipe.name,
      metadata: r.recipe.metadata,
      nutrition: {
        calories: r.recipe.calories,
        carbohydrates: r.recipe.carbohydrates,
        protein: r.recipe.protein,
        fat: r.recipe.fat,
        fiber: r.recipe.fiber,
        sugar: r.recipe.sugar,
        glycemicLoad: r.recipe.glycemicLoad
      },
      timing: {
        prepTime: r.recipe.prepTime,
        cookTime: r.recipe.cookTime,
        generationTime: r.generationTime
      },
      recipeContent: r.recipe.recipeContent,
      notes: r.recipe.notes,
      validation: {
        unique: r.unique,
        memoryWorking: r.memoryWorking,
        issues: r.issues
      }
    })),
    categoryAnalysis: categories.map(category => {
      const categoryResults = results.filter(r => `${r.category} - ${r.subcategory}` === category);
      const proteins = categoryResults.map(r => r.recipe.metadata.primaryProtein);
      const methods = categoryResults.map(r => r.recipe.metadata.cookingMethod);
      const cuisines = categoryResults.map(r => r.recipe.metadata.cuisine);

      return {
        category,
        recipeCount: categoryResults.length,
        diversity: {
          proteins: {
            unique: new Set(proteins).size,
            total: proteins.length,
            list: Array.from(new Set(proteins))
          },
          methods: {
            unique: new Set(methods).size,
            total: methods.length,
            list: Array.from(new Set(methods))
          },
          cuisines: {
            unique: new Set(cuisines).size,
            total: cuisines.length,
            list: Array.from(new Set(cuisines))
          }
        }
      };
    })
  };

  const outputPath = path.join(__dirname, '..', 'recipe_generation_test_results.json');
  fs.writeFileSync(outputPath, JSON.stringify(jsonReport, null, 2), 'utf-8');
  console.log(`\n💾 JSON report saved to: ${outputPath}\n`);
}

// Run tests
runTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
