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
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ShoppingListItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \ShoppingListItem.sortOrder, ascending: false)
        ],
        animation: .spring()
    ) private var items: FetchedResults<ShoppingListItem>

    @StateObject private var viewModel: ShoppingListViewModel

    init(viewContext: NSManagedObjectContext? = nil) {
        // Accept optional injected viewContext for preview support
        // If nil, ViewModel will use environment context via updateContext() in onAppear
        let context = viewContext ?? PersistenceController.preview.container.viewContext
        _viewModel = StateObject(wrappedValue: ShoppingListViewModel(viewContext: context))
    }

    // Computed properties using ViewModel
    private var uncheckedItems: [ShoppingListItem] {
        viewModel.uncheckedItems(from: Array(items))
    }

    private var completedItems: [ShoppingListItem] {
        viewModel.completedItems(from: Array(items))
    }

    private var recipeGroups: [(recipeName: String, recipeId: UUID, items: [ShoppingListItem], allCompleted: Bool)] {
        viewModel.recipeGroups(from: Array(items))
    }

    private var completedRecipeGroups: [(recipeName: String, recipeId: UUID, items: [ShoppingListItem])] {
        viewModel.completedRecipeGroups(from: Array(items))
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
                    if !completedItems.isEmpty || !completedRecipeGroups.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: viewModel.toggleCompletedSection) {
                                HStack(spacing: ResponsiveDesign.Spacing.xSmall) {
                                    Image(systemName: viewModel.showCompletedItems ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("\(completedItems.count + completedRecipeGroups.count) tamamlandı")
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
                    if viewModel.showCompletedItems {
                        // Show completed recipe groups
                        ForEach(completedRecipeGroups, id: \.recipeId) { group in
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

                        // Show completed standalone items
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
                        onAddIngredients: viewModel.addIngredients
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
            .onAppear {
                // Inject the actual viewContext into ViewModel on appear
                viewModel.updateContext(viewContext)
            }
        }
    }

    // MARK: - Helper Functions (delegate to ViewModel)

    private func saveItem(_ item: ShoppingListItem, newText: String, newQuantity: String?) {
        viewModel.saveItem(item, newText: newText, newQuantity: newQuantity)
    }

    private func toggleItem(_ item: ShoppingListItem) {
        viewModel.toggleItem(item, allItems: Array(items))
    }

    private func deleteItem(_ item: ShoppingListItem) {
        viewModel.deleteItem(item)
    }

    private func updateItemNote(_ item: ShoppingListItem, note: String?) {
        viewModel.updateItemNote(item, note: note)
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
