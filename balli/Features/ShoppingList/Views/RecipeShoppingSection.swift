//
//  RecipeShoppingSection.swift
//  balli
//
//  Single-item recipe display for shopping list with modal ingredient view
//

import SwiftUI
import CoreData

// MARK: - Recipe Shopping Section (Single Item Display)
struct RecipeShoppingSection: View {
    let recipeName: String
    let recipeId: UUID
    let items: [ShoppingListItem]
    let onItemToggle: (ShoppingListItem) -> Void
    let onItemDelete: (ShoppingListItem) -> Void
    let onItemSave: (ShoppingListItem, String, String) -> Void
    let onNoteUpdate: (ShoppingListItem, String?) -> Void
    let onRecipeDelete: () -> Void

    @State private var showIngredientsSheet = false
    @Environment(\.colorScheme) private var colorScheme

    private var uncheckedItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted }
    }

    private var completedItems: [ShoppingListItem] {
        items.filter { $0.isCompleted }
    }

    private var allItemsCompleted: Bool {
        items.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Checkbox for marking entire recipe as complete
            Button(action: {
                // Toggle all items in recipe to match the target state
                let targetState = !allItemsCompleted
                for item in items {
                    if item.isCompleted != targetState {
                        onItemToggle(item)
                    }
                }
            }) {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(allItemsCompleted ? AppTheme.primaryPurple : Color.clear)
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .opacity(allItemsCompleted ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)

            // Recipe name display (like ingredient) - tappable to open sheet
            Button(action: { showIngredientsSheet = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                        Text(recipeName)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Show ingredient count
                        if uncheckedItems.count > 0 {
                            Text("\(uncheckedItems.count) malzeme")
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Tarif badge button - lighter purple fill to match individual ingredient pills
                    Button(action: { showIngredientsSheet = true }) {
                        Text("Tarif")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple.opacity(0.15))
                            )
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .background(.clear)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onRecipeDelete) {
                Label("Sil", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showIngredientsSheet) {
            RecipeIngredientsSheet(
                recipeName: recipeName,
                recipeId: recipeId,
                items: items,
                onItemToggle: onItemToggle,
                onItemDelete: onItemDelete,
                onItemSave: onItemSave,
                onNoteUpdate: onNoteUpdate
            )
        }
    }
}

// MARK: - Recipe Ingredients Sheet
struct RecipeIngredientsSheet: View {
    let recipeName: String
    let recipeId: UUID
    let items: [ShoppingListItem]
    let onItemToggle: (ShoppingListItem) -> Void
    let onItemDelete: (ShoppingListItem) -> Void
    let onItemSave: (ShoppingListItem, String, String) -> Void
    let onNoteUpdate: (ShoppingListItem, String?) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    private var uncheckedItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted }
    }

    private var completedItems: [ShoppingListItem] {
        items.filter { $0.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    // Unchecked items
                    ForEach(uncheckedItems, id: \.id) { item in
                        RecipeItemRow(
                            item: item,
                            onToggle: { onItemToggle(item) },
                            onDelete: { onItemDelete(item) },
                            onSave: { text, quantity in onItemSave(item, text, quantity) },
                            onNoteUpdate: { note in onNoteUpdate(item, note) }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                    // Completed items section
                    if !completedItems.isEmpty {
                        Section {
                            ForEach(completedItems, id: \.id) { item in
                                RecipeItemRow(
                                    item: item,
                                    onToggle: { onItemToggle(item) },
                                    onDelete: { onItemDelete(item) },
                                    onSave: { text, quantity in onItemSave(item, text, quantity) },
                                    onNoteUpdate: { note in onNoteUpdate(item, note) }
                                )
                                .opacity(0.6)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        } header: {
                            Text("\(completedItems.count) tamamlandı")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }

                    // Extra space for input container
                    Color.clear
                        .frame(height: 120)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))

                // Input container at bottom with Liquid Glass
                VStack {
                    Spacer()
                    RecipeIngredientsInputContainer(
                        recipeName: recipeName,
                        recipeId: recipeId
                    )
                }
            }
            .navigationTitle(recipeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Recipe Item Row
struct RecipeItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSave: (String, String) -> Void
    let onNoteUpdate: (String?) -> Void

    @State private var isEditing = false
    @State private var editedText = ""
    @State private var editedQuantity = ""
    @State private var isEditingQuantity = false
    @FocusState private var isFieldFocused: Bool
    @FocusState private var isQuantityFocused: Bool
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Checkbox
            Button(action: onToggle) {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(item.isCompleted ? AppTheme.primaryPurple : Color.clear)
                    )
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .opacity(item.isCompleted ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)

            // Text/TextField with quantity support and glass effects
            if isEditing {
                VStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                    TextField("Ürün adı", text: $editedText)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .fontWeight(.semibold)
                        .focused($isFieldFocused)
                        .onSubmit {
                            saveAndStopEditing()
                        }
                        .onAppear {
                            isFieldFocused = true
                        }
                        .onChange(of: isFieldFocused) { _, focused in
                            if !focused {
                                saveAndStopEditing()
                            }
                        }
                        .liquidGlassTextField(style: .regular)

                    TextField("Miktar (ör: x2, 1 kg)", text: $editedQuantity)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .liquidGlassTextField(style: .thin)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(item.isCompleted ? .secondary : .primary)
                            .strikethrough(item.isCompleted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditing()
                            }

                        // Note display
                        if let notes = item.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }

                    // Quantity display (inline editable) - matches main shopping list style
                    if isEditingQuantity {
                        TextField("x1", text: $editedQuantity)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                            .multilineTextAlignment(.center)
                            .focused($isQuantityFocused)
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple.opacity(0.15))
                            )
                            .frame(width: ResponsiveDesign.width(70))
                            .onSubmit {
                                saveQuantityAndStopEditing()
                            }
                            .onChange(of: isQuantityFocused) { _, focused in
                                if !focused {
                                    saveQuantityAndStopEditing()
                                }
                            }
                            .onAppear {
                                isQuantityFocused = true
                            }
                            .transition(.scale.combined(with: .opacity))
                    } else if let quantity = item.quantity, !quantity.isEmpty {
                        Text(quantity)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .background(
                                Capsule()
                                    .fill(AppTheme.primaryPurple.opacity(0.15))
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.smooth(duration: 0.25)) {
                                    startEditingQuantity()
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
    }

    private func startEditing() {
        editedText = item.name
        editedQuantity = item.quantity ?? ""
        isEditing = true
    }

    private func saveAndStopEditing() {
        isEditing = false
        isFieldFocused = false
        if editedText != item.name || editedQuantity != (item.quantity ?? "") {
            onSave(editedText, editedQuantity.isEmpty ? "" : editedQuantity)
        }
    }

    private func startEditingQuantity() {
        editedQuantity = item.quantity ?? ""
        isEditingQuantity = true
    }

    private func saveQuantityAndStopEditing() {
        isEditingQuantity = false
        isQuantityFocused = false
        let newQuantity = editedQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        if newQuantity != (item.quantity ?? "") {
            onSave(item.name, newQuantity.isEmpty ? "" : newQuantity)
        }
    }
}

// MARK: - Recipe Ingredients Input Container
struct RecipeIngredientsInputContainer: View {
    let recipeName: String
    let recipeId: UUID

    // MARK: - State
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    // CRITICAL FIX: Lazy initialize heavy services
    @State private var ingredientParser: IngredientParser?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @ViewBuilder
    private var messageBoxView: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            // Text area at the top
            TextField("Malzemelerini ekle", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .lineLimit(1...6)
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.top, ResponsiveDesign.Spacing.medium)
                .submitLabel(.send)
                .onSubmit {
                    if !inputText.isEmpty {
                        sendIngredients()
                    }
                }
                .autocorrectionDisabled(true)
                .keyboardType(.default)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.height > 0 {
                                isInputFocused = false
                            }
                        }
                )

            // Send button at the bottom
            HStack {
                Spacer()

                Button(action: sendIngredients) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(36), weight: .regular, design: .rounded))
                        .foregroundColor(inputText.isEmpty ? Color(.systemGray3) : AppTheme.primaryPurple)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.trailing, ResponsiveDesign.height(6))
            }
            .padding(.bottom, ResponsiveDesign.Spacing.xSmall)
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputText.isEmpty)
    }

    @ViewBuilder
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                messageBoxView
            }
            .padding(.horizontal)
            .padding(.bottom, ResponsiveDesign.Spacing.medium)
        }
    }

    var body: some View {
        inputAreaView
    }

    // MARK: - Helper Functions

    private func getIngredientParser() -> IngredientParser {
        if let parser = ingredientParser {
            return parser
        }
        let newParser = IngredientParser()
        ingredientParser = newParser
        return newParser
    }

    // MARK: - Actions

    private func sendIngredients() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        Task {
            let parser = getIngredientParser()
            let ingredients = await parser.parseIngredients(from: text)

            await MainActor.run {
                if !ingredients.isEmpty {
                    do {
                        // Create ShoppingListItem entities from parsed ingredients
                        for ingredient in ingredients {
                            let item = ShoppingListItem.create(
                                name: ingredient.name,
                                category: ingredient.category,
                                quantity: ingredient.displayQuantity,
                                notes: nil,
                                in: viewContext
                            )
                            // Mark as recipe ingredient
                            item.isFromRecipe = true
                            item.recipeId = recipeId
                            item.recipeName = recipeName
                            item.dateCreated = Date()
                            item.sortOrder = Int32(Date().timeIntervalSince1970)
                        }

                        // Save context
                        try viewContext.save()
                        inputText = ""

                        // Keep focus for continuous adding
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            isInputFocused = true
                        }
                    } catch {
                        // Error already handled and displayed to user
                    }
                }
            }
        }
    }
}