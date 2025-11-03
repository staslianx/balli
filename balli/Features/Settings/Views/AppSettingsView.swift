//
//  AppSettingsView.swift
//  balli
//
//  App settings and configuration view
//

import SwiftUI
import OSLog

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.userManager) private var userManager
    @Environment(\.managedObjectContext) private var viewContext

    private let logger = Logger(subsystem: "com.anaxoniclabs.balli", category: "settings")

    @State private var notificationsEnabled = true
    @State private var selectedLanguage = "Türkçe"
    @AppStorage("selectedTheme") private var selectedTheme = "Sistem"
    @State private var glucoseUnit = "mg/dL"
    @State private var autoScanEnabled = true
    
    // Developer Settings
    @State private var appSettings = AppSettings.load()
    @State private var showingCleanupDialog = false
    @State private var showingDataSummary = false
    @State private var dataSummary: DeveloperDataSummary?
    @ObservedObject private var developerDataManager = DeveloperDataManager.shared
    
    // Developer mode visibility - always show the toggle so users can enable it
    private var showDeveloperSettings: Bool {
        true // Always show so users can access the toggle
    }
    
    let languages = ["Türkçe", "English"]
    let themes = ["Sistem", "Açık", "Koyu"]
    let glucoseUnits = ["mg/dL", "mmol/L"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Account Section
                Section("Hesap") {
                    HStack(spacing: 16) {
                        Text(userManager.currentUser?.emoji ?? "👤")
                            .font(.system(size: 48))
                            .frame(width: 64, height: 64)
                            .background(
                                Circle()
                                    .fill((userManager.currentUser?.themeColor ?? AppTheme.primaryPurple).opacity(0.1))
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(userManager.currentUserDisplayName)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text(userManager.currentUserEmail)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if userManager.isTestUser {
                            Text("TEST")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 12)
                }

                // Appearance Section
                Section("Görünüm") {
                    Picker("Tema", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme).tag(theme)
                        }
                    }
                    .tint(AppTheme.primaryPurple)
                    .onChange(of: selectedTheme) { _, newValue in
                        updateAppearance(newValue)
                    }
                }

                // Health & Data Section
                Section("Sağlık & Veri") {
                    NavigationLink(destination: HealthKitManagerView()) {
                        Label("Apple Sağlık", systemImage: "heart.text.square.fill")
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: DexcomConnectionView()) {
                        Label {
                            Text("Dexcom CGM")
                        } icon: {
                            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                .rotationEffect(.degrees(-90))
                        }
                    }
                    .tint(AppTheme.primaryPurple)

                    Toggle(isOn: $notificationsEnabled) {
                        Label("Bildirimler", systemImage: "bell.fill")
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: ExportDataView()) {
                        Label("Verileri Dışarı Aktar", systemImage: "square.and.arrow.up.fill")
                    }
                    .tint(AppTheme.primaryPurple)
                }

                // Diagnostics Section
                Section("Tanı") {
                    NavigationLink(destination: DexcomDiagnosticsView()) {
                        Label("Dexcom Tanılama", systemImage: "stethoscope")
                    }
                    .tint(AppTheme.primaryPurple)

                    NavigationLink(destination: AIDiagnosticsView()) {
                        Label("AI İşlemleri Tanılama", systemImage: "brain")
                    }
                    .tint(AppTheme.primaryPurple)
                }

                // Support & Info Section
                Section {
                    if let emailURL = URL(string: "mailto:destek@balli.app") {
                        Link(destination: emailURL) {
                            Label("İletişim", systemImage: "envelope.fill")
                        }
                        .tint(AppTheme.primaryPurple)
                    }

                    NavigationLink(destination: AboutView()) {
                        Label("Hakkında", systemImage: "info.circle.fill")
                    }
                    .tint(AppTheme.primaryPurple)

                    HStack {
                        Label("Sürüm", systemImage: "app.badge.fill")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                // Account Actions Section
                Section {
                    Button(action: {
                        Task { @MainActor in
                            // Clear user selection to show user selection modal
                            userManager.clearUserSelection()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(AppTheme.primaryPurple)
                                .frame(width: 24)

                            Text("Kullanıcı Değiştir")
                                .foregroundColor(.primary)
                        }
                    }

                    Button(role: .destructive, action: {
                        Task { @MainActor in
                            // Reset app configuration
                            await AppConfigurationManager.shared.resetConfiguration()

                            // Clear user selection
                            userManager.clearUserSelection()

                            // Notify the app about logout
                            NotificationCenter.default.post(
                                name: Notification.Name("UserDidLogout"),
                                object: nil
                            )

                            dismiss()
                        }
                    }) {
                        Label("Çıkış Yap", systemImage: "door.left.hand.open")
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updateAppearance(selectedTheme)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.primaryPurple)
                }
            }
        }
        .captureWindow() // Capture window for child views (DexcomConnectionView OAuth)
    }

    // MARK: - Computed Bindings

    private var serhatModeBinding: Binding<Bool> {
        Binding(
            get: {
                MainActor.assumeIsolated {
                    appSettings.isSerhatModeEnabled
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    if newValue {
                        appSettings.enableSerhatMode()
                    } else {
                        // Show cleanup options before disabling
                        if appSettings.autoCleanupOnToggleOff {
                            showingCleanupDialog = true
                        } else {
                            appSettings.disableSerhatMode()
                        }
                    }
                }
            }
        )
    }

    // MARK: - Developer Settings Views

    private var developerModeToggle: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
                .foregroundColor(appSettings.isSerhatModeEnabled ? .orange : AppTheme.primaryPurple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Serhat Mode")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                
                Text("Developer testing mode")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: serhatModeBinding)
            .tint(.orange)
        }
        .alert("Disable Developer Mode", isPresented: $showingCleanupDialog) {
            Button("Keep Data") {
                Task {
                    try? await developerDataManager.performCleanup(option: .keepAll)
                    await MainActor.run {
                        appSettings.disableSerhatMode()
                    }
                }
            }
            
            Button("Delete Session") {
                Task {
                    try? await developerDataManager.performCleanup(option: .deleteCurrentSession)
                    await MainActor.run {
                        appSettings.disableSerhatMode()
                    }
                }
            }
            
            Button("Delete All", role: .destructive) {
                Task {
                    try? await developerDataManager.performCleanup(option: .deleteAllDeveloperData)
                    await MainActor.run {
                        appSettings.disableSerhatMode()
                    }
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What should happen to your developer testing data?")
        }
    }
    
    private var developerModeInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                    .frame(width: 24)
                
                Text("Session Info")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("User ID:")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("serhat-developer-mode")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Session Duration:")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(appSettings.formattedSessionDuration)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .padding(.leading, 30)
        }
    }
    
    private var developerDataActions: some View {
        VStack(spacing: 8) {
            // Data Summary Button
            Button(action: {
                Task {
                    do {
                        let summary = try await developerDataManager.getDeveloperDataSummary()
                        await MainActor.run {
                            dataSummary = summary
                            showingDataSummary = true
                        }
                    } catch {
                        logger.error("Failed to get developer data summary: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("View Data Summary")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Cleanup Actions
            Button(action: {
                Task {
                    try? await developerDataManager.performCleanup(option: .deleteCurrentSession)
                }
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("Clear Current Session")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
        .alert("Developer Data Summary", isPresented: $showingDataSummary) {
            Button("OK") { }
        } message: {
            if let summary = dataSummary {
                Text(summary.displayText)
            } else {
                Text("No data available")
            }
        }
    }

    // MARK: - User Switching Section

    private var userSwitchingSection: some View {
        VStack(spacing: 8) {
            // Current User Display
            HStack {
                Image(systemName: "person.2.circle")
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick User Switch")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.orange)

                    Text("Current: \(userManager.currentUserDisplayName)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // User Switch Buttons
            HStack(spacing: 12) {
                ForEach(AppUser.allCases, id: \.self) { user in
                    Button(action: {
                        userManager.switchToUser(user)
                    }) {
                        HStack(spacing: 6) {
                            Text(user.emoji)
                                .font(.system(size: 14))

                            Text(user.displayName)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .fontWeight(.medium)
                        }
                        .foregroundColor(userManager.currentUser == user ? AppTheme.foregroundOnColor(for: colorScheme) : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(userManager.currentUser == user ? user.themeColor : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.leading, 30)
        }
    }

    // MARK: - Memory & Embedding Tools

    private var memoryAndEmbeddingTools: some View {
        VStack(spacing: 8) {
            // Memory Statistics
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory & Vector Tools")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.orange)

                    Text("AI memory and embedding utilities")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Tool Buttons
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        await testEmbeddingGeneration()
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("Test Embedding Generation")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }

                Button(action: {
                    Task {
                        await testMemorySearch()
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass.circle")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("Test Memory Search")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }

                Button(action: {
                    Task {
                        await clearMemoryData()
                    }
                }) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.orange)
                            .frame(width: 24)

                        Text("Clear Memory Data")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
            }
            .padding(.leading, 30)
        }
    }

    // MARK: - Developer Tool Actions

    private func testEmbeddingGeneration() async {
        logger.debug("🧪 Testing embedding generation...")
        // This could trigger a test embedding call
    }

    private func testMemorySearch() async {
        logger.debug("🧪 Testing memory search...")
        // This could trigger a test memory search
    }

    private func clearMemoryData() async {
        logger.info("🧪 Clearing memory data for current user")
        // This could clear memory entries for the current user
    }

    // MARK: - Theme Management

    private func updateAppearance(_ theme: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        for window in windowScene.windows {
            switch theme {
            case "Açık":
                window.overrideUserInterfaceStyle = .light
            case "Koyu":
                window.overrideUserInterfaceStyle = .dark
            default: // "Sistem"
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    // MARK: - Recipe Preview Helpers

    private func createTamarindLassiRecipe() -> RecipeDetailData {
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Tamarind-Peach Lassi"
        recipe.servings = 4
        recipe.prepTime = 10
        recipe.cookTime = 5
        recipe.calories = 150
        recipe.totalCarbs = 35
        recipe.fiber = 2
        recipe.sugars = 28
        recipe.protein = 4
        recipe.totalFat = 2
        recipe.ingredients = [
            "1 cup tamarind pulp",
            "2 ripe peaches, peeled and chopped",
            "2 cups plain yogurt",
            "1/4 cup honey or sugar",
            "1 cup ice cubes",
            "Fresh mint leaves for garnish",
            "1/4 teaspoon ground cardamom",
            "Pinch of salt"
        ] as NSArray
        recipe.instructions = [
            "Blend tamarind pulp with peaches until smooth",
            "Add yogurt, honey, and cardamom to the blender",
            "Blend on high speed for 30 seconds until well combined",
            "Add ice cubes and blend until frothy and smooth",
            "Taste and adjust sweetness if needed",
            "Pour into glasses and garnish with fresh mint leaves",
            "Serve immediately while cold and frothy"
        ] as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: "Better Homes & Gardens",
            author: "Danielle Centoni",
            yieldText: "4 servings",
            recipeDescription: "Tamarind pulp can be found in jars on the international foods aisle. Or look for tamarind pods in the produce section and peel the sticky pulp away from the seeds. Using peaches adds fresh sweetness to balance the tart tamarind flavor. This tropical-inspired lassi is perfect for hot summer days and brings a unique twist to the traditional yogurt-based drink. The combination of tangy tamarind and sweet peaches creates a refreshing beverage that's both exotic and familiar.",
            storyTitle: "Pucker Up! Here's Seven Tantalizing Reasons to Embrace Tamarind",
            storyThumbnailURL: nil
        )
    }

    private func createAvocadoToastRecipe() -> RecipeDetailData {
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Perfect Avocado Toast"
        recipe.servings = 2
        recipe.prepTime = 5
        recipe.cookTime = 3
        recipe.calories = 280
        recipe.totalCarbs = 25
        recipe.fiber = 8
        recipe.sugars = 2
        recipe.protein = 8
        recipe.totalFat = 18
        recipe.ingredients = [
            "2 slices whole grain sourdough bread",
            "1 large ripe avocado",
            "1 tablespoon fresh lemon juice",
            "2 tablespoons extra virgin olive oil",
            "1/4 teaspoon red pepper flakes",
            "Sea salt and black pepper to taste",
            "2 poached eggs (optional)",
            "Microgreens or arugula for topping",
            "Everything bagel seasoning"
        ] as NSArray
        recipe.instructions = [
            "Toast the sourdough bread until golden and crispy",
            "While bread toasts, mash avocado with lemon juice and salt",
            "Drizzle toasted bread with olive oil",
            "Spread mashed avocado generously on each slice",
            "Top with poached eggs if using",
            "Sprinkle with red pepper flakes, everything bagel seasoning, and microgreens",
            "Season with freshly cracked black pepper and serve immediately"
        ] as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: "Bon Appétit",
            author: "Molly Baz",
            yieldText: "2 toasts",
            recipeDescription: "The key to perfect avocado toast is using high-quality bread and ripe avocados. Look for avocados that yield slightly when gently pressed. Sourdough adds a tangy flavor that complements the creamy avocado beautifully. Don't skip the lemon juice—it prevents browning and adds brightness. This simple yet satisfying breakfast has become a modern classic for good reason. The healthy fats from avocado keep you full until lunch, while the whole grain bread provides sustained energy.",
            storyTitle: "The Rise of Avocado Toast: From Café Trend to Kitchen Staple",
            storyThumbnailURL: nil
        )
    }

    private func createChocolateCakeRecipe() -> RecipeDetailData {
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Molten Chocolate Lava Cake"
        recipe.servings = 4
        recipe.prepTime = 15
        recipe.cookTime = 12
        recipe.calories = 420
        recipe.totalCarbs = 45
        recipe.fiber = 3
        recipe.sugars = 32
        recipe.protein = 6
        recipe.totalFat = 24
        recipe.ingredients = [
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
        ] as NSArray
        recipe.instructions = [
            "Preheat oven to 425°F (220°C). Butter four 6-ounce ramekins and dust with cocoa powder",
            "Melt chocolate and butter together in a double boiler, stirring until smooth",
            "In a separate bowl, whisk eggs, egg yolks, and sugar until thick and pale",
            "Fold melted chocolate mixture into egg mixture",
            "Gently fold in flour, vanilla, and salt until just combined",
            "Divide batter evenly among prepared ramekins",
            "Bake for 12-14 minutes until edges are set but center still jiggles",
            "Let cool for 1 minute, then invert onto plates",
            "Dust with cocoa powder and serve immediately with vanilla ice cream"
        ] as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: "Cook's Illustrated",
            author: "Jean-Georges Vongerichten",
            yieldText: "4 individual cakes",
            recipeDescription: "This molten chocolate lava cake is the ultimate chocolate lover's dessert. The secret to the perfect molten center is precise timing—the edges should be set while the middle remains gloriously gooey. Use high-quality dark chocolate for the best flavor. These elegant individual cakes are surprisingly easy to make and never fail to impress dinner guests. The contrast between the warm, flowing center and cold vanilla ice cream creates an unforgettable taste experience. Don't overbake or you'll lose that signature lava flow!",
            storyTitle: "The Invention of Molten Chocolate Cake: A Delicious Accident",
            storyThumbnailURL: nil
        )
    }

    private func createGreekSaladRecipe() -> RecipeDetailData {
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Authentic Greek Salad"
        recipe.servings = 4
        recipe.prepTime = 15
        recipe.cookTime = 0
        recipe.calories = 180
        recipe.totalCarbs = 12
        recipe.fiber = 3
        recipe.sugars = 6
        recipe.protein = 6
        recipe.totalFat = 14
        recipe.ingredients = [
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
        ] as NSArray
        recipe.instructions = [
            "Cut tomatoes into wedges and place in a large bowl",
            "Add cucumber half-moons, sliced onion, and bell pepper rings",
            "Add Kalamata olives to the bowl",
            "In a small bowl, whisk together olive oil, vinegar, and dried oregano",
            "Pour dressing over vegetables and toss gently",
            "Season with salt and pepper to taste",
            "Top with thick slices of feta cheese",
            "Garnish with fresh oregano and serve immediately"
        ] as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: "Mediterranean Living",
            author: "Maria Papadopoulos",
            yieldText: "4 servings",
            recipeDescription: "In Greece, this salad is called 'Horiatiki' and is a staple of Mediterranean cuisine. The key is using ripe, flavorful tomatoes and authentic Greek feta cheese. Traditional Greek salad doesn't include lettuce—it's all about the vegetables and that creamy, salty feta. Use the best quality olive oil you can find, as it's a main component of the dressing. This refreshing salad is perfect alongside grilled meats or fish, or enjoy it on its own with crusty bread to soak up the delicious juices that collect at the bottom of the bowl.",
            storyTitle: "The Mediterranean Diet: Why Greek Salad is More Than Just Vegetables",
            storyThumbnailURL: nil
        )
    }

    private func createSmoothieBowlRecipe() -> RecipeDetailData {
        let context = Persistence.PersistenceController(inMemory: true).viewContext
        let recipe = Recipe(context: context)
        recipe.id = UUID()
        recipe.name = "Berry Bliss Smoothie Bowl"
        recipe.servings = 2
        recipe.prepTime = 10
        recipe.cookTime = 0
        recipe.calories = 320
        recipe.totalCarbs = 48
        recipe.fiber = 9
        recipe.sugars = 28
        recipe.protein = 12
        recipe.totalFat = 10
        recipe.ingredients = [
            "2 cups frozen mixed berries (strawberries, blueberries, raspberries)",
            "1 frozen banana",
            "1/2 cup Greek yogurt",
            "1/4 cup almond milk",
            "1 tablespoon honey",
            "1 tablespoon chia seeds",
            "Toppings: fresh berries, granola, coconut flakes",
            "Toppings: sliced banana, hemp seeds, almond butter drizzle"
        ] as NSArray
        recipe.instructions = [
            "Add frozen berries and banana to a high-speed blender",
            "Add Greek yogurt, almond milk, and honey",
            "Blend on high until thick and creamy (mixture should be thicker than a smoothie)",
            "Add a splash more almond milk if needed to blend",
            "Pour into two bowls",
            "Top with fresh berries, granola, coconut flakes, and banana slices",
            "Drizzle with almond butter and sprinkle with hemp seeds and chia seeds",
            "Serve immediately with a spoon"
        ] as NSArray
        recipe.dateCreated = Date()
        recipe.lastModified = Date()
        recipe.source = "manual"

        return RecipeDetailData(
            recipe: recipe,
            recipeSource: "Minimalist Baker",
            author: "Dana Shultz",
            yieldText: "2 bowls",
            recipeDescription: "Smoothie bowls are thicker than regular smoothies and eaten with a spoon, making them feel more like a satisfying meal. The key is using frozen fruit to achieve that thick, ice cream-like consistency. Don't add too much liquid or it will be too thin. Get creative with toppings—the beautiful presentation makes breakfast feel special. This antioxidant-rich bowl provides sustained energy from complex carbs, protein from Greek yogurt, and healthy fats from seeds and nut butter. It's Instagram-worthy and nutritious!",
            storyTitle: "Smoothie Bowl Revolution: The Breakfast That Broke the Internet",
            storyThumbnailURL: nil
        )
    }
}

// MARK: - Recipe Preview Row Component

struct RecipePreviewRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.2))
                )

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Placeholder Views for Navigation Links
struct NotificationSettingsView: View {
    var body: some View {
        Form {
            Section("Bildirim Türleri") {
                Toggle("Kan Şekeri Hatırlatıcıları", isOn: .constant(true))
                Toggle("Öğün Hatırlatıcıları", isOn: .constant(true))
                Toggle("İlaç Hatırlatıcıları", isOn: .constant(false))
            }
            
            Section("Zaman Ayarları") {
                DatePicker("Sabah Hatırlatıcı", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                DatePicker("Akşam Hatırlatıcı", selection: .constant(Date()), displayedComponents: .hourAndMinute)
            }
        }
        .navigationTitle("Bildirim Ayarları")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CameraSettingsView: View {
    var body: some View {
        Form {
            Section("Kamera Kalitesi") {
                Picker("Kalite", selection: .constant("Yüksek")) {
                    Text("Yüksek").tag("Yüksek")
                    Text("Orta").tag("Orta")
                    Text("Düşük").tag("Düşük")
                }
                .pickerStyle(.segmented)
            }
            
            Section("AI Analiz") {
                Toggle("Gelişmiş Analiz", isOn: .constant(true))
                Toggle("Güven Skoru Göster", isOn: .constant(true))
            }
        }
        .navigationTitle("Kamera Ayarları")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
                Text("Veri Güvenliği")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("balli uygulaması verilerini güvenle saklar:")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
                    DataPrivacyRow(icon: "lock.shield", title: "Yerel Depolama", description: "Tüm veriler cihazında saklanır")
                    DataPrivacyRow(icon: "eye.slash", title: "Gizlilik", description: "Kişisel veriler paylaşılmaz")
                    DataPrivacyRow(icon: "key", title: "Şifreleme", description: "Veriler şifrelenerek korunur")
                }
                
                Spacer(minLength: ResponsiveDesign.Spacing.large)
            }
            .padding()
        }
        .navigationTitle("Veri & Gizlilik")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataPrivacyRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.primaryPurple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ExportDataView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.primaryPurple.opacity(0.5))
            
            Text("Verilerini Dışa Aktar")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Kan şekeri ölçümlerini, öğün kayıtlarını ve diğer sağlık verilerini CSV formatında dışa aktarabilirsin.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Export data action
            }) {
                Text("Verileri Dışa Aktar")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.primaryPurple)
                    .cornerRadius(ResponsiveDesign.CornerRadius.medium)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Veri Dışa Aktarma")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        VStack {
            Spacer()

            // Centered Balli text logo
            Image("balli-text-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)

            Spacer()

            // Bottom Anaxonic Labs logo (smaller)
            Image("anaxonic-labs")
                .resizable()
                .scaledToFit()
                .frame(width: 250)
                .padding(.bottom, 0)
        }
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AppSettingsView()
}
