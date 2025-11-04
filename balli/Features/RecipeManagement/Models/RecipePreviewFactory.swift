//
//  RecipePreviewFactory.swift
//  balli
//
//  Factory for creating preview recipe data for developer mode
//  Swift 6 strict concurrency compliant
//

import Foundation
import CoreData

/// Recipe creation data structure
struct RecipePreviewData {
    let name: String
    let servings: Int16
    let prepTime: Int16
    let cookTime: Int16
    let calories: Double
    let totalCarbs: Double
    let fiber: Double
    let sugars: Double
    let protein: Double
    let totalFat: Double
    let ingredients: [String]
    let instructions: [String]
    let source: String
    let author: String
    let yieldText: String
    let description: String
    let storyTitle: String
}

/// Factory for creating recipe preview data
@MainActor
struct RecipePreviewFactory {

    /// Create a RecipeDetailData from preview data
    static func create(from data: RecipePreviewData) -> RecipeDetailData {
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)

        recipe.id = UUID()
        recipe.name = data.name
        recipe.servings = data.servings
        recipe.prepTime = data.prepTime
        recipe.cookTime = data.cookTime
        recipe.calories = data.calories
        recipe.totalCarbs = data.totalCarbs
        recipe.fiber = data.fiber
        recipe.sugars = data.sugars
        recipe.protein = data.protein
        recipe.totalFat = data.totalFat
        recipe.ingredients = data.ingredients as NSArray
        recipe.instructions = data.instructions as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: data.source,
            author: data.author,
            yieldText: data.yieldText,
            recipeDescription: data.description,
            storyTitle: data.storyTitle,
            storyThumbnailURL: nil
        )
    }

    // MARK: - Predefined Preview Recipes

    static var tamarindLassi: RecipeDetailData {
        create(from: RecipePreviewData(
            name: "Tamarind-Peach Lassi",
            servings: 4,
            prepTime: 10,
            cookTime: 5,
            calories: 150,
            totalCarbs: 35,
            fiber: 2,
            sugars: 28,
            protein: 4,
            totalFat: 2,
            ingredients: [
                "1 cup tamarind pulp",
                "2 ripe peaches, peeled and chopped",
                "2 cups plain yogurt",
                "1/4 cup honey or sugar",
                "1 cup ice cubes",
                "Fresh mint leaves for garnish",
                "1/4 teaspoon ground cardamom",
                "Pinch of salt"
            ],
            instructions: [
                "Blend tamarind pulp with peaches until smooth",
                "Add yogurt, honey, and cardamom to the blender",
                "Blend on high speed for 30 seconds until well combined",
                "Add ice cubes and blend until frothy and smooth",
                "Taste and adjust sweetness if needed",
                "Pour into glasses and garnish with fresh mint leaves",
                "Serve immediately while cold and frothy"
            ],
            source: "Better Homes & Gardens",
            author: "Danielle Centoni",
            yieldText: "4 servings",
            description: "Tamarind pulp can be found in jars on the international foods aisle. Or look for tamarind pods in the produce section and peel the sticky pulp away from the seeds. Using peaches adds fresh sweetness to balance the tart tamarind flavor. This tropical-inspired lassi is perfect for hot summer days and brings a unique twist to the traditional yogurt-based drink. The combination of tangy tamarind and sweet peaches creates a refreshing beverage that's both exotic and familiar.",
            storyTitle: "Pucker Up! Here's Seven Tantalizing Reasons to Embrace Tamarind"
        ))
    }

    static var avocadoToast: RecipeDetailData {
        create(from: RecipePreviewData(
            name: "Perfect Avocado Toast",
            servings: 2,
            prepTime: 5,
            cookTime: 3,
            calories: 280,
            totalCarbs: 25,
            fiber: 8,
            sugars: 2,
            protein: 8,
            totalFat: 18,
            ingredients: [
                "2 slices whole grain sourdough bread",
                "1 large ripe avocado",
                "1 tablespoon fresh lemon juice",
                "2 tablespoons extra virgin olive oil",
                "1/4 teaspoon red pepper flakes",
                "Sea salt and black pepper to taste",
                "2 poached eggs (optional)",
                "Microgreens or arugula for topping",
                "Everything bagel seasoning"
            ],
            instructions: [
                "Toast the sourdough bread until golden and crispy",
                "While bread toasts, mash avocado with lemon juice and salt",
                "Drizzle toasted bread with olive oil",
                "Spread mashed avocado generously on each slice",
                "Top with poached eggs if using",
                "Sprinkle with red pepper flakes, everything bagel seasoning, and microgreens",
                "Season with freshly cracked black pepper and serve immediately"
            ],
            source: "Bon Appétit",
            author: "Molly Baz",
            yieldText: "2 toasts",
            description: "The key to perfect avocado toast is using high-quality bread and ripe avocados. Look for avocados that yield slightly when gently pressed. Sourdough adds a tangy flavor that complements the creamy avocado beautifully. Don't skip the lemon juice—it prevents browning and adds brightness. This simple yet satisfying breakfast has become a modern classic for good reason. The healthy fats from avocado keep you full until lunch, while the whole grain bread provides sustained energy.",
            storyTitle: "The Rise of Avocado Toast: From Café Trend to Kitchen Staple"
        ))
    }

    static var chocolateCake: RecipeDetailData {
        create(from: RecipePreviewData(
            name: "Molten Chocolate Lava Cake",
            servings: 4,
            prepTime: 15,
            cookTime: 12,
            calories: 420,
            totalCarbs: 45,
            fiber: 3,
            sugars: 32,
            protein: 6,
            totalFat: 24,
            ingredients: [
                "6 oz dark chocolate (70% cocoa), chopped",
                "1/2 cup unsalted butter, plus extra for ramekins",
                "2 large eggs",
                "2 large egg yolks",
                "1/4 cup granulated sugar",
                "2 tablespoons all-purpose flour",
                "1 teaspoon vanilla extract",
                "Pinch of salt",
                "Cocoa powder for dusting",
                "Vanilla ice cream for serving"
            ],
            instructions: [
                "Preheat oven to 425°F (220°C). Butter four 6-ounce ramekins and dust with cocoa powder",
                "Melt chocolate and butter together in a double boiler, stirring until smooth",
                "In a separate bowl, whisk eggs, egg yolks, and sugar until thick and pale",
                "Fold melted chocolate mixture into egg mixture",
                "Gently fold in flour, vanilla, and salt until just combined",
                "Divide batter evenly among prepared ramekins",
                "Bake for 12-14 minutes until edges are set but center still jiggles",
                "Let cool for 1 minute, then invert onto plates",
                "Dust with cocoa powder and serve immediately with vanilla ice cream"
            ],
            source: "Cook's Illustrated",
            author: "Jean-Georges Vongerichten",
            yieldText: "4 individual cakes",
            description: "This molten chocolate lava cake is the ultimate chocolate lover's dessert. The secret to the perfect molten center is precise timing—the edges should be set while the middle remains gloriously gooey. Use high-quality dark chocolate for the best flavor. These elegant individual cakes are surprisingly easy to make and never fail to impress dinner guests. The contrast between the warm, flowing center and cold vanilla ice cream creates an unforgettable taste experience. Don't overbake or you'll lose that signature lava flow!",
            storyTitle: "The Invention of Molten Chocolate Cake: A Delicious Accident"
        ))
    }

    static var greekSalad: RecipeDetailData {
        create(from: RecipePreviewData(
            name: "Authentic Greek Salad",
            servings: 4,
            prepTime: 15,
            cookTime: 0,
            calories: 180,
            totalCarbs: 12,
            fiber: 3,
            sugars: 6,
            protein: 6,
            totalFat: 14,
            ingredients: [
                "4 large ripe tomatoes, cut into wedges",
                "1 English cucumber, sliced into half-moons",
                "1 red onion, thinly sliced",
                "1 green bell pepper, cut into rings",
                "1 cup Kalamata olives",
                "8 oz feta cheese, cut into thick slices",
                "1/4 cup extra virgin olive oil",
                "2 tablespoons red wine vinegar",
                "1 teaspoon dried oregano",
                "Sea salt and black pepper to taste",
                "Fresh oregano for garnish"
            ],
            instructions: [
                "Cut tomatoes into wedges and place in a large bowl",
                "Add cucumber half-moons, sliced onion, and bell pepper rings",
                "Add Kalamata olives to the bowl",
                "In a small bowl, whisk together olive oil, vinegar, and dried oregano",
                "Pour dressing over vegetables and toss gently",
                "Season with salt and pepper to taste",
                "Top with thick slices of feta cheese",
                "Garnish with fresh oregano and serve immediately"
            ],
            source: "Mediterranean Living",
            author: "Maria Papadopoulos",
            yieldText: "4 servings",
            description: "In Greece, this salad is called 'Horiatiki' and is a staple of Mediterranean cuisine. The key is using ripe, flavorful tomatoes and authentic Greek feta cheese. Traditional Greek salad doesn't include lettuce—it's all about the vegetables and that creamy, salty feta. Use the best quality olive oil you can find, as it's a main component of the dressing. This refreshing salad is perfect alongside grilled meats or fish, or enjoy it on its own with crusty bread to soak up the delicious juices that collect at the bottom of the bowl.",
            storyTitle: "The Mediterranean Diet: Why Greek Salad is More Than Just Vegetables"
        ))
    }

    static var smoothieBowl: RecipeDetailData {
        create(from: RecipePreviewData(
            name: "Berry Bliss Smoothie Bowl",
            servings: 2,
            prepTime: 10,
            cookTime: 0,
            calories: 320,
            totalCarbs: 48,
            fiber: 9,
            sugars: 28,
            protein: 12,
            totalFat: 10,
            ingredients: [
                "2 cups frozen mixed berries (strawberries, blueberries, raspberries)",
                "1 frozen banana",
                "1/2 cup Greek yogurt",
                "1/4 cup almond milk",
                "1 tablespoon honey",
                "1 tablespoon chia seeds",
                "Toppings: fresh berries, granola, coconut flakes",
                "Toppings: sliced banana, hemp seeds, almond butter drizzle"
            ],
            instructions: [
                "Add frozen berries and banana to a high-speed blender",
                "Add Greek yogurt, almond milk, and honey",
                "Blend on high until thick and creamy (mixture should be thicker than a smoothie)",
                "Add a splash more almond milk if needed to blend",
                "Pour into two bowls",
                "Top with fresh berries, granola, coconut flakes, and banana slices",
                "Drizzle with almond butter and sprinkle with hemp seeds and chia seeds",
                "Serve immediately with a spoon"
            ],
            source: "Minimalist Baker",
            author: "Dana Shultz",
            yieldText: "2 bowls",
            description: "Smoothie bowls are thicker than regular smoothies and eaten with a spoon, making them feel more like a satisfying meal. The key is using frozen fruit to achieve that thick, ice cream-like consistency. Don't add too much liquid or it will be too thin. Get creative with toppings—the beautiful presentation makes breakfast feel special. This antioxidant-rich bowl provides sustained energy from complex carbs, protein from Greek yogurt, and healthy fats from seeds and nut butter. It's Instagram-worthy and nutritious!",
            storyTitle: "Smoothie Bowl Revolution: The Breakfast That Broke the Internet"
        ))
    }
}
