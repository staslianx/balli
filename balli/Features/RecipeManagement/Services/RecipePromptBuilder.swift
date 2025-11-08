//
//  RecipePromptBuilder.swift
//  balli
//
//  Builds structured prompts for recipe generation with memory system
//  Converts mealType/styleType to detailed AI prompts
//  Swift 6 strict concurrency compliant
//

import Foundation
import OSLog

/// Builds AI prompts for recipe generation from meal and style types
enum RecipePromptBuilder {
    private static let logger = AppLoggers.Recipe.generation

    // MARK: - Main Prompt Building

    /// Build a comprehensive prompt for recipe generation
    /// - Parameters:
    ///   - mealType: Type of meal (e.g., "Kahvaltı", "Öğle Yemeği", "Akşam Yemeği")
    ///   - styleType: Style subcategory (e.g., "Geleneksel", "Hafif", "Protein Ağırlıklı")
    ///   - recentRecipes: Recent recipes from same category for diversity
    ///   - userPreferences: Optional user preferences (dietary restrictions, allergies)
    /// - Returns: Structured prompt for Gemini API
    static func buildPrompt(
        mealType: String,
        styleType: String,
        recentRecipes: [RecentRecipe] = [],
        userPreferences: UserRecipePreferences? = nil
    ) -> String {
        logger.debug("Building prompt for mealType: \(mealType), styleType: \(styleType), recent recipes: \(recentRecipes.count)")

        // Start with base prompt structure
        var prompt = buildBasePrompt(mealType: mealType, styleType: styleType)

        // Add recent recipes section for diversity
        if !recentRecipes.isEmpty {
            prompt += "\n\n" + buildRecentRecipesSection(recentRecipes)
        }

        // Add user preferences if available
        if let preferences = userPreferences {
            prompt += "\n\n" + buildPreferencesSection(preferences)
        }

        // Add Turkish cuisine emphasis
        prompt += "\n\n" + buildCuisineGuidelines()

        // Add output format requirements
        prompt += "\n\n" + buildOutputFormatRequirements()

        logger.info("Generated prompt with \(prompt.count) characters")
        return prompt
    }

    // MARK: - Base Prompt

    /// Build base prompt from meal and style types
    private static func buildBasePrompt(mealType: String, styleType: String) -> String {
        let mealDescription = getMealDescriptionTurkish(mealType)
        let styleDescription = getStyleDescriptionTurkish(styleType)

        return """
        Türk mutfağından bir \(mealDescription) tarifi oluştur.
        Stil: \(styleDescription)

        Tarif özellikleri:
        - Türkiye'de kolay bulunabilir malzemeler kullan
        - Net ve anlaşılır Türkçe talimatlar ver
        - Gerçekçi hazırlık ve pişirme süreleri belirt
        - Porsiyon sayısını belirt (genellikle 4 kişilik)
        - Tüm içerik SADECE TÜRKÇE olmalı (İngilizce çeviri ekleme)
        """
    }

    // MARK: - Meal Descriptions

    /// Get Turkish-only description for meal type
    private static func getMealDescriptionTurkish(_ mealType: String) -> String {
        switch mealType.lowercased() {
        case "kahvaltı", "breakfast":
            return "kahvaltı"
        case "öğle yemeği", "lunch":
            return "öğle yemeği"
        case "akşam yemeği", "dinner":
            return "akşam yemeği"
        case "atıştırmalık", "snack", "atıştırmalıklar":
            return "atıştırmalık"
        case "tatlı", "dessert", "tatlılar":
            return "tatlı"
        case "salata", "salad", "salatalar":
            return "salata"
        case "çorba", "soup":
            return "çorba"
        case "içecek", "beverage":
            return "içecek"
        default:
            return mealType
        }
    }

    // MARK: - Style Descriptions

    /// Get Turkish-only description for style type
    private static func getStyleDescriptionTurkish(_ styleType: String) -> String {
        switch styleType.lowercased() {
        case "geleneksel", "traditional":
            return "Geleneksel Türk mutfağı tarzında"

        case "hafif", "light", "hafif salata":
            return "Hafif ve sağlıklı, düşük kalorili"

        case "protein ağırlıklı", "high protein":
            return "Yüksek protein içerikli, kas yapımını destekleyen"

        case "vejeteryan", "vegetarian":
            return "Et içermeyen, vejeteryan"

        case "vegan":
            return "Hayvansal ürün içermeyen, vegan"

        case "hızlı", "quick":
            return "30 dakikada hazırlanabilir, hızlı"

        case "özel günler", "special occasions", "sana özel tatlılar":
            return "Özel ve lezzetli"

        case "çocuk dostu", "kid-friendly":
            return "Çocukların sevdiği, kolay yenilebilir"

        case "düşük karbonhidrat", "low carb":
            return "Düşük karbonhidrat içerikli, ketojenik"

        case "glutensiz", "gluten-free":
            return "Gluten içermeyen"

        case "laktoz içermez", "lactose-free":
            return "Süt ürünü içermeyen"

        case "karbohidrat ve protein uyumu":
            return "Dengeli karbonhidrat ve protein içeren"

        case "tam buğday makarna":
            return "Tam buğday ürünleri ile hazırlanan"

        case "doyurucu salata":
            return "Doyurucu ve besleyici"

        case "custom":
            return "Özel tarif"

        default:
            return styleType
        }
    }

    // MARK: - Recent Recipes Section

    /// Build recent recipes section for diversity
    /// Shows AI the recent recipes to avoid repetition
    private static func buildRecentRecipesSection(_ recentRecipes: [RecentRecipe]) -> String {
        let recipesList = recentRecipes
            .map { "- \($0.title)" }
            .joined(separator: "\n")

        return """
        SON YAPTIĞIM TARİFLER / RECENT RECIPES I'VE MADE:
        \(recipesList)

        Lütfen bunlardan farklı bir tarif yap - ana malzemeleri, pişirme yöntemini veya öğün türünü değiştirerek yeni bir şeyler dene.
        Make it feel different from these - vary the main ingredients, cooking style, or meal type to keep things fresh.
        """
    }

    // MARK: - User Preferences

    /// Build user preferences section
    private static func buildPreferencesSection(_ preferences: UserRecipePreferences) -> String {
        var sections: [String] = []

        // Dietary restrictions
        if !preferences.dietaryRestrictions.isEmpty {
            let restrictions = preferences.dietaryRestrictions.joined(separator: ", ")
            sections.append("Diyet kısıtlamaları / Dietary restrictions: \(restrictions)")
        }

        // Allergies
        if !preferences.allergies.isEmpty {
            let allergies = preferences.allergies.joined(separator: ", ")
            sections.append("Alerjiler / Allergies: ASLA kullanma / NEVER use: \(allergies)")
        }

        // Disliked ingredients
        if !preferences.dislikedIngredients.isEmpty {
            let disliked = preferences.dislikedIngredients.joined(separator: ", ")
            sections.append("Sevmediği malzemeler / Disliked ingredients: Mümkünse kullanma / Avoid if possible: \(disliked)")
        }

        // Preferred proteins
        if !preferences.preferredProteins.isEmpty {
            let proteins = preferences.preferredProteins.joined(separator: ", ")
            sections.append("Tercih edilen proteinler / Preferred proteins: \(proteins)")
        }

        // Cooking skill level
        if let skillLevel = preferences.cookingSkillLevel {
            sections.append("Pişirme becerisi / Cooking skill: \(skillLevel)")
        }

        guard !sections.isEmpty else {
            return ""
        }

        return """
        KULLANICI TERCİHLERİ / USER PREFERENCES:
        \(sections.joined(separator: "\n"))
        """
    }

    // MARK: - Cuisine Guidelines

    /// Build Turkish cuisine guidelines
    private static func buildCuisineGuidelines() -> String {
        return """
        DİYABET DOSTU MUTFAK KILAVUZU:
        - Bu tarif DİYABET HASTASI için - kan şekeri kontrolü çok önemli!
        - Düşük glisemik indeksli malzemeler tercih et
        - Rafine şeker ve beyaz un kullanma
        - Kompleks karbonhidrat kullan (tam buğday, bulgur, kinoa)
        - Bol lif içeren sebzeler ekle
        - Yağsız protein kaynakları tercih et
        - Porsiyonları makul tut
        - Türk mutfağı lezzetlerini sağlıklı versiyonlarıyla sun
        - Yerel ve taze malzemeler kullan
        - Dengeli ve doyurucu olsun
        """
    }

    // MARK: - Output Format

    /// Build output format requirements
    private static func buildOutputFormatRequirements() -> String {
        return """
        ÇIKTI FORMATI:
        Lütfen aşağıdaki yapıda JSON döndür:
        {
          "recipeName": "Tarif adı (SADECE Türkçe)",
          "description": "Kısa, samimi bir açıklama (arkadaşına anlatıyormuş gibi)",
          "servings": 4,
          "prepTime": 15,
          "cookTime": 30,
          "ingredients": [
            {"quantity": "200 g", "item": "tavuk göğsü"},
            {"quantity": "2 adet", "item": "domates"}
          ],
          "instructions": [
            "Önce tavukları küp küp doğra. Sonra bir güzel baharatlayıver.",
            "Tavayı kızdır, domates ve biberleri at. Güzelce sotele."
          ],
          "metadata": {
            "cuisine": "Türk",
            "primaryProtein": "Tavuk",
            "cookingMethod": "Tava",
            "mealType": "Akşam Yemeği",
            "difficulty": "Kolay",
            "dietaryTags": ["Yüksek Protein"]
          }
        }

        ÖNEMLİ:
        - Samimi ve arkadaşça bir dil kullan (sanki bir arkadaşına anlatıyormuş gibi)
        - "Sen" diliyle yaz: "doğra", "ekle", "karıştır"
        - Malzeme miktarlarını net belirt (gram, adet, su bardağı, yemek kaşığı)
        - Talimatları detaylandır ama samimi tut
        - Pişirme sürelerini ve sıcaklıkları belirt
        - TÜM İÇERİK SADECE TÜRKÇE OLMALI (İngilizce ekleme!)
        - Küçük harfle yaz (tarif adı hariç)

        BESİN DEĞERLERİ:
        "description" alanına beslenme değerlerini de ekle (kişi başı yaklaşık):
        - Kalori: ~350 kcal
        - Karbonhidrat: ~35g
        - Protein: ~25g
        - Yağ: ~12g
        - Lif: ~8g
        - Şeker: ~5g (düşük tutmaya çalış!)
        - Glisemik Yük: ~15 (orta - diyabet dostu)

        Örnek açıklama formatı:
        "Doyurucu ve sağlıklı bir akşam yemeği. Her porsiyon yaklaşık 350 kalori, 35g karbonhidrat (çoğu lifli), 25g protein içeriyor."
        """
    }

    // MARK: - Prompt Variants

    /// Build a prompt specifically for ingredient-based generation
    static func buildIngredientsPrompt(
        mealType: String,
        styleType: String,
        availableIngredients: [String],
        userPreferences: UserRecipePreferences? = nil
    ) -> String {
        logger.debug("Building ingredients-based prompt with \(availableIngredients.count) ingredients")

        var prompt = buildBasePrompt(mealType: mealType, styleType: styleType)

        // Add ingredients constraint
        let ingredientsList = availableIngredients.joined(separator: ", ")
        prompt += """

        MEVCut MALZEMELer / AVAILABLE INGREDIENTS:
        Bu malzemeleri mümkün olduğunca kullan / Use these ingredients as much as possible:
        \(ingredientsList)

        Not: Temel malzemeler (tuz, karabiber, sıvı yağ, etc.) eklenebilir
        Note: Basic ingredients (salt, pepper, oil, etc.) can be added
        """

        // Add user preferences if available
        if let preferences = userPreferences {
            prompt += "\n\n" + buildPreferencesSection(preferences)
        }

        prompt += "\n\n" + buildCuisineGuidelines()
        prompt += "\n\n" + buildOutputFormatRequirements()

        return prompt
    }
}

// MARK: - User Recipe Preferences Model

/// User preferences for recipe generation
struct UserRecipePreferences: Sendable {
    let dietaryRestrictions: [String]
    let allergies: [String]
    let dislikedIngredients: [String]
    let preferredProteins: [String]
    let cookingSkillLevel: String?

    init(
        dietaryRestrictions: [String] = [],
        allergies: [String] = [],
        dislikedIngredients: [String] = [],
        preferredProteins: [String] = [],
        cookingSkillLevel: String? = nil
    ) {
        self.dietaryRestrictions = dietaryRestrictions
        self.allergies = allergies
        self.dislikedIngredients = dislikedIngredients
        self.preferredProteins = preferredProteins
        self.cookingSkillLevel = cookingSkillLevel
    }

    /// Empty preferences (no constraints)
    static let empty = UserRecipePreferences()
}
