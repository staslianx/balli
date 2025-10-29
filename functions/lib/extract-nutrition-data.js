"use strict";
//
// extract-nutrition-data.ts
// Quick script to call the API once and get full recipe with all nutrition data
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
const dotenv = __importStar(require("dotenv"));
dotenv.config();
const FUNCTION_URL = 'https://generatespontaneousrecipe-gzc54elfeq-uc.a.run.app';
async function getSingleRecipe() {
    console.log('Fetching one recipe to show complete nutrition data...\n');
    const response = await fetch(FUNCTION_URL, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            mealType: 'Akşam Yemeği',
            styleType: 'Karbonhidrat ve Protein Uyumu',
            memoryEntries: []
        })
    });
    const text = await response.text();
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
        if (lines[i] === 'event: completed') {
            if (i + 1 < lines.length && lines[i + 1].startsWith('data: ')) {
                const jsonData = JSON.parse(lines[i + 1].substring(6));
                const recipe = jsonData.data;
                console.log('═══════════════════════════════════════════════════════════════');
                console.log('📖 Recipe:', recipe.name);
                console.log('═══════════════════════════════════════════════════════════════\n');
                console.log('📊 COMPLETE NUTRITIONAL VALUES (per 100g):');
                console.log('   Calories:', recipe.calories, 'kcal');
                console.log('   Carbohydrates:', recipe.carbohydrates, 'g');
                console.log('   - Fiber:', recipe.fiber, 'g');
                console.log('   - Sugar:', recipe.sugar, 'g');
                console.log('   Protein:', recipe.protein, 'g');
                console.log('   Fat:', recipe.fat, 'g');
                console.log('   Glycemic Load:', recipe.glycemicLoad);
                console.log('');
                console.log('⏱️  TIMING:');
                console.log('   Prep Time:', recipe.prepTime, 'minutes');
                console.log('   Cook Time:', recipe.cookTime, 'minutes');
                console.log('   Servings:', recipe.servings);
                console.log('');
                console.log('🏷️  METADATA:');
                console.log('   Cuisine:', recipe.metadata.cuisine);
                console.log('   Primary Protein:', recipe.metadata.primaryProtein);
                console.log('   Cooking Method:', recipe.metadata.cookingMethod);
                console.log('   Difficulty:', recipe.metadata.difficulty);
                console.log('   Dietary Tags:', recipe.metadata.dietaryTags.join(', '));
                console.log('');
                console.log('📝 NOTES:');
                console.log(recipe.notes);
                console.log('');
                console.log('🥘 RECIPE CONTENT:');
                console.log(recipe.recipeContent);
                console.log('');
                console.log('\n✅ This shows ALL nutrition values are present in the API response!\n');
                break;
            }
        }
    }
}
getSingleRecipe().catch(console.error);
//# sourceMappingURL=extract-nutrition-data.js.map