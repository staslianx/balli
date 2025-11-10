//
//  RecipePreferencesView.swift
//  balli
//
//  User preferences for recipe generation with diversity system
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import OSLog

@MainActor
struct RecipePreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RecipePreferencesViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // Dietary Restrictions Section
                Section {
                    ForEach(viewModel.dietaryRestrictions, id: \.self) { restriction in
                        HStack {
                            Text(restriction)
                            Spacer()
                            Button {
                                viewModel.removeDietaryRestriction(restriction)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button {
                        viewModel.showingAddDietaryRestriction = true
                    } label: {
                        Label("Add Dietary Restriction", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Dietary Restrictions")
                } footer: {
                    Text("Recipes will strictly follow these restrictions (e.g., vegetarian, vegan, gluten-free)")
                }

                // Allergens Section
                Section {
                    ForEach(viewModel.allergens, id: \.self) { allergen in
                        HStack {
                            Text(allergen)
                            Spacer()
                            Button {
                                viewModel.removeAllergen(allergen)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button {
                        viewModel.showingAddAllergen = true
                    } label: {
                        Label("Add Allergen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Allergens")
                } footer: {
                    Text("Recipes will never include these ingredients")
                }

                // Favorite Cuisines
                Section {
                    ForEach(viewModel.favoriteCuisines, id: \.self) { cuisine in
                        HStack {
                            Text(cuisine)
                            Spacer()
                            Button {
                                viewModel.removeFavoriteCuisine(cuisine)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button {
                        viewModel.showingAddFavoriteCuisine = true
                    } label: {
                        Label("Add Favorite Cuisine", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Favorite Cuisines")
                } footer: {
                    Text("These cuisines will appear more often")
                }

                // Health Goals
                Section {
                    ForEach(viewModel.healthGoals, id: \.self) { goal in
                        HStack {
                            Text(goal)
                            Spacer()
                            Button {
                                viewModel.removeHealthGoal(goal)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button {
                        viewModel.showingAddHealthGoal = true
                    } label: {
                        Label("Add Health Goal", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Health Goals")
                } footer: {
                    Text("Recipes will try to align with these goals (e.g., low-carb, high-protein)")
                }

                // Diversity Settings
                Section {
                    Toggle("Enable Diversity Scoring", isOn: $viewModel.diversityEnabled)

                    if viewModel.diversityEnabled {
                        Toggle("Seasonal Suggestions", isOn: $viewModel.seasonalEnabled)
                        Toggle("Surprise Me Mode", isOn: $viewModel.surpriseMeEnabled)
                    }
                } header: {
                    Text("Diversity Settings")
                } footer: {
                    Text("Diversity scoring ensures variety in your recipes over time")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Recipe Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.savePreferences()
                            dismiss()
                        }
                    }
                }
            }
            .alert("Add Dietary Restriction", isPresented: $viewModel.showingAddDietaryRestriction) {
                TextField("e.g., Vegetarian", text: $viewModel.newItemText)
                Button("Add") {
                    viewModel.addDietaryRestriction(viewModel.newItemText)
                    viewModel.newItemText = ""
                }
                Button("Cancel", role: .cancel) {
                    viewModel.newItemText = ""
                }
            }
            .alert("Add Allergen", isPresented: $viewModel.showingAddAllergen) {
                TextField("e.g., Peanuts", text: $viewModel.newItemText)
                Button("Add") {
                    viewModel.addAllergen(viewModel.newItemText)
                    viewModel.newItemText = ""
                }
                Button("Cancel", role: .cancel) {
                    viewModel.newItemText = ""
                }
            }
            .alert("Add Favorite Cuisine", isPresented: $viewModel.showingAddFavoriteCuisine) {
                TextField("e.g., Italian", text: $viewModel.newItemText)
                Button("Add") {
                    viewModel.addFavoriteCuisine(viewModel.newItemText)
                    viewModel.newItemText = ""
                }
                Button("Cancel", role: .cancel) {
                    viewModel.newItemText = ""
                }
            }
            .alert("Add Health Goal", isPresented: $viewModel.showingAddHealthGoal) {
                TextField("e.g., Low-carb", text: $viewModel.newItemText)
                Button("Add") {
                    viewModel.addHealthGoal(viewModel.newItemText)
                    viewModel.newItemText = ""
                }
                Button("Cancel", role: .cancel) {
                    viewModel.newItemText = ""
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class RecipePreferencesViewModel: ObservableObject {
    @Published var dietaryRestrictions: [String] = []
    @Published var allergens: [String] = []
    @Published var favoriteCuisines: [String] = []
    @Published var healthGoals: [String] = []
    @Published var diversityEnabled: Bool = true
    @Published var seasonalEnabled: Bool = true
    @Published var surpriseMeEnabled: Bool = false

    @Published var showingAddDietaryRestriction = false
    @Published var showingAddAllergen = false
    @Published var showingAddFavoriteCuisine = false
    @Published var showingAddHealthGoal = false
    @Published var newItemText = ""

    private let preferencesKey = "balli.recipePreferences"
    private let logger = AppLoggers.App.configuration

    init() {
        loadPreferences()
    }

    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(SavedPreferences.self, from: data) {
            dietaryRestrictions = decoded.dietaryRestrictions
            allergens = decoded.allergens
            favoriteCuisines = decoded.favoriteCuisines
            healthGoals = decoded.healthGoals
            diversityEnabled = decoded.diversityEnabled
            seasonalEnabled = decoded.seasonalEnabled
            surpriseMeEnabled = decoded.surpriseMeEnabled
        }
    }

    func savePreferences() async {
        let preferences = SavedPreferences(
            dietaryRestrictions: dietaryRestrictions,
            allergens: allergens,
            favoriteCuisines: favoriteCuisines,
            healthGoals: healthGoals,
            diversityEnabled: diversityEnabled,
            seasonalEnabled: seasonalEnabled,
            surpriseMeEnabled: surpriseMeEnabled
        )

        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }

        logger.info("Saved recipe preferences")
    }

    // MARK: - Dietary Restrictions

    func addDietaryRestriction(_ restriction: String) {
        let trimmed = restriction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !dietaryRestrictions.contains(trimmed) else { return }
        dietaryRestrictions.append(trimmed)
    }

    func removeDietaryRestriction(_ restriction: String) {
        dietaryRestrictions.removeAll { $0 == restriction }
    }

    // MARK: - Allergens

    func addAllergen(_ allergen: String) {
        let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !allergens.contains(trimmed) else { return }
        allergens.append(trimmed)
    }

    func removeAllergen(_ allergen: String) {
        allergens.removeAll { $0 == allergen }
    }

    // MARK: - Favorite Cuisines

    func addFavoriteCuisine(_ cuisine: String) {
        let trimmed = cuisine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !favoriteCuisines.contains(trimmed) else { return }
        favoriteCuisines.append(trimmed)
    }

    func removeFavoriteCuisine(_ cuisine: String) {
        favoriteCuisines.removeAll { $0 == cuisine }
    }

    // MARK: - Health Goals

    func addHealthGoal(_ goal: String) {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !healthGoals.contains(trimmed) else { return }
        healthGoals.append(trimmed)
    }

    func removeHealthGoal(_ goal: String) {
        healthGoals.removeAll { $0 == goal }
    }
}

// MARK: - Models

struct SavedPreferences: Codable {
    let dietaryRestrictions: [String]
    let allergens: [String]
    let favoriteCuisines: [String]
    let healthGoals: [String]
    let diversityEnabled: Bool
    let seasonalEnabled: Bool
    let surpriseMeEnabled: Bool
}

// MARK: - Preview

#Preview {
    RecipePreferencesView()
}
