//
//  ShoppingListViewSimple.swift
//  balli
//
//  Simplified shopping list with intuitive inline editing and iOS 26 Liquid Glass design
//

import SwiftUI
import CoreData
import OSLog

struct ShoppingListViewSimple: View {
    private let logger = AppLoggers.Shopping.list

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ShoppingListItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \ShoppingListItem.sortOrder, ascending: false)
        ],
        animation: .spring()
    ) private var items: FetchedResults<ShoppingListItem>

    // Performance optimization
    private let fetchBatchSize = 20

    // Ingredient parser for text input
    @State private var ingredientParser = IngredientParser()
    @State private var showCompletedItems = false

    private var uncheckedItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted && !$0.isFromRecipe }
    }

    private var completedItems: [ShoppingListItem] {
        items.filter { $0.isCompleted && !$0.isFromRecipe }
    }

    // Group recipe items by recipe
    private var recipeGroups: [(recipeName: String, recipeId: UUID, items: [ShoppingListItem])] {
        let recipeItems = items.filter { $0.isFromRecipe }

        // Group by recipe ID (which is unique)
        let grouped = Dictionary(grouping: recipeItems) { item in
            item.recipeId ?? UUID()
        }

        return grouped.compactMap { recipeId, items in
            guard let firstItem = items.first else { return nil }
            let recipeName = firstItem.recipeName ?? "Tarif"
            return (recipeName: recipeName, recipeId: recipeId, items: items)
        }.sorted { $0.items.first?.dateCreated ?? Date() > $1.items.first?.dateCreated ?? Date() }
    }

    @MainActor
    var body: some View {
        NavigationStack {
            // Use ZStack to properly layer the input container
            ZStack(alignment: .bottom) {
                // Main content with Liquid Glass background
                List {
                    // Show recipe sections first
                    ForEach(recipeGroups, id: \.recipeId) { group in
                        RecipeShoppingSection(
                            recipeName: group.recipeName,
                            recipeId: group.recipeId,
                            items: group.items,
                            onItemToggle: { toggleItem($0) },
                            onItemDelete: { deleteItem($0) },
                            onItemSave: { item, text, quantity in saveItem(item, newText: text, newQuantity: quantity) },
                            onNoteUpdate: { item, note in updateItemNote(item, note: note) }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    // Show individual unchecked items
                    ForEach(uncheckedItems, id: \.id) { item in
                        EditableItemRow(
                            item: item,
                            onSave: { text, quantity in saveItem(item, newText: text, newQuantity: quantity) },
                            onDelete: { deleteItem(item) },
                            onToggle: { toggleItem(item) },
                            onNoteUpdate: { note in updateItemNote(item, note: note) }
                        )
                        .id(item.id)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    // Show completed items toggle button with Liquid Glass
                    if !completedItems.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring()) {
                                    showCompletedItems.toggle()
                                }
                            }) {
                                HStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                                    Image(systemName: showCompletedItems ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("\(completedItems.count) tamamlandı")
                                        .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .medium, design: .rounded))
                                }
                                .foregroundColor(AppTheme.primaryPurple)
                                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                                .padding(.vertical, ResponsiveDesign.Spacing.small)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.vertical, ResponsiveDesign.Spacing.small)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    // Show completed items when toggled
                    if showCompletedItems && !completedItems.isEmpty {
                        ForEach(completedItems, id: \.id) { item in
                            EditableItemRow(
                                item: item,
                                onSave: { text, quantity in saveItem(item, newText: text, newQuantity: quantity) },
                                onDelete: { deleteItem(item) },
                                onToggle: { toggleItem(item) },
                                onNoteUpdate: { note in updateItemNote(item, note: note) }
                            )
                            .id(item.id)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }

                    // Empty state with Liquid Glass - only show if ALL lists are empty
                    if uncheckedItems.isEmpty && completedItems.isEmpty && recipeGroups.isEmpty {
                        VStack(spacing: ResponsiveDesign.Spacing.medium) {
                            Spacer()
                                .frame(height: ResponsiveDesign.height(60))

                            Image(systemName: "basket")
                                .font(.system(size: 80, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.3))

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
                .background(
                    ZStack {
                        Color.appBackground(for: colorScheme)
                            .ignoresSafeArea()

                        // Subtle glass layer for depth
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppTheme.primaryPurple.opacity(0.03),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                    }
                )
                .padding(.bottom, 0)

                // Input container at bottom with Liquid Glass
                VStack {
                    Spacer()
                    ShoppingListInputContainer(
                        onAddIngredients: { ingredients in
                            addIngredients(ingredients)
                        }
                    )
                }
            }
            .navigationTitle("Alışveriş Listesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Alışveriş Listesi")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .fontWeight(.semibold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Open Apple Maps directly with market search
                        if let url = URL(string: "maps://?q=Market") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "map")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(18), weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                    }
                }
            }
        }
    }

    private func addIngredients(_ ingredients: [ParsedIngredient]) {
        Task {
            let _ = await ingredientParser.createShoppingItems(
                from: ingredients,
                in: viewContext
            )

            await MainActor.run {
                saveContext()
            }
        }
    }

    private func saveItem(_ item: ShoppingListItem, newText: String, newQuantity: String?) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteItem(item)
            return
        }

        item.name = trimmed.capitalized
        item.quantity = newQuantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        item.lastModified = Date()
        saveContext()
    }

    private func toggleItem(_ item: ShoppingListItem) {
        withAnimation(.spring()) {
            item.isCompleted.toggle()
            item.lastModified = Date()
            saveContext()
        }
    }

    private func deleteItem(_ item: ShoppingListItem) {
        withAnimation(.spring()) {
            viewContext.delete(item)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            logger.error("Failed to save shopping list context: \(error.localizedDescription)")
        }
    }

    private func updateItemNote(_ item: ShoppingListItem, note: String?) {
        item.notes = note?.isEmpty == true ? nil : note
        item.lastModified = Date()
        saveContext()
    }

}

struct EditableItemRow: View {
    let item: ShoppingListItem
    let onSave: (String, String?) -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    let onNoteUpdate: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var editQuantity = ""
    @State private var editNote = ""
    @State private var isEditingQuantity = false
    @State private var isEditingNote = false
    @FocusState private var isFieldFocused: Bool
    @FocusState private var isQuantityFocused: Bool
    @FocusState private var isNoteFocused: Bool

    @MainActor
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
                    TextField("Ürün adı", text: $editText)
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

                    TextField("Miktar (ör: x2, 1 kg)", text: $editQuantity)
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

                        // Note/Suggestion below the name with glass effect
                        if isEditingNote {
                            TextField("Not ekle...", text: $editNote)
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .focused($isNoteFocused)
                                .onSubmit {
                                    saveNoteAndStopEditing()
                                }
                                .onChange(of: isNoteFocused) { _, focused in
                                    if !focused {
                                        saveNoteAndStopEditing()
                                    }
                                }
                                .liquidGlassTextField(style: .thin)
                        } else if let notes = item.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundColor(notes.contains("balli'den öneri:") ? AppTheme.primaryPurple : .secondary)
                                .italic()
                                .onTapGesture {
                                    startEditingNote()
                                }
                        }
                    }

                    // Quantity display with bordered prominent style
                    if isEditingQuantity {
                        TextField("x1", text: $editQuantity)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($isQuantityFocused)
                            .padding(.horizontal, ResponsiveDesign.width(12))
                            .padding(.vertical, ResponsiveDesign.height(6))
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.primaryPurple)
                            .frame(minWidth: ResponsiveDesign.width(60))
                            .onSubmit {
                                saveQuantityAndStopEditing()
                            }
                            .onAppear {
                                isQuantityFocused = true
                            }
                            .onChange(of: isQuantityFocused) { _, focused in
                                if !focused {
                                    saveQuantityAndStopEditing()
                                }
                            }
                    } else if let quantity = item.quantity, !quantity.isEmpty {
                        Button(action: { startEditingQuantity() }) {
                            Text(quantity)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primaryPurple)
                    }
                }
            }
        }
        .padding(.vertical, ResponsiveDesign.Spacing.medium)
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    private func startEditing() {
        editText = item.name
        editQuantity = item.quantity ?? ""
        isEditing = true
    }

    private func saveAndStopEditing() {
        isEditing = false
        isFieldFocused = false
        if editText != item.name || editQuantity != (item.quantity ?? "") {
            onSave(editText, editQuantity.isEmpty ? nil : editQuantity)
        }
    }

    private func startEditingQuantity() {
        editQuantity = item.quantity ?? ""
        isEditingQuantity = true
    }

    private func saveQuantityAndStopEditing() {
        isEditingQuantity = false
        isQuantityFocused = false
        let newQuantity = editQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
        if newQuantity != (item.quantity ?? "") {
            onSave(item.name, newQuantity.isEmpty ? nil : newQuantity)
        }
    }

    private func startEditingNote() {
        editNote = item.notes ?? ""
        isEditingNote = true
        isNoteFocused = true
    }

    private func saveNoteAndStopEditing() {
        isEditingNote = false
        isNoteFocused = false
        let newNote = editNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if newNote != (item.notes ?? "") {
            onNoteUpdate(newNote)
        }
    }
}

#Preview {
    NavigationStack {
        ShoppingListViewSimple()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
