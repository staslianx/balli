//
//  EditShoppingItemSheet.swift
//  balli
//
//  Sheet for editing existing shopping list items
//

import SwiftUI

struct EditShoppingItemSheet: View {
    let item: ShoppingListItem
    let onSave: (ShoppingListItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var itemName: String
    @State private var quantity: String
    @State private var category: String
    @State private var notes: String
    @State private var brand: String
    @FocusState private var nameFieldFocused: Bool
    
    init(item: ShoppingListItem, onSave: @escaping (ShoppingListItem) -> Void) {
        self.item = item
        self.onSave = onSave
        
        // Initialize state from item
        _itemName = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity ?? "")
        _category = State(initialValue: item.category ?? ShoppingListItem.ShoppingCategory.general.rawValue)
        _notes = State(initialValue: item.notes ?? "")
        _brand = State(initialValue: item.brand ?? "")
    }
    
    private var canSave: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasChanges: Bool {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return trimmedName != item.name ||
               (trimmedQuantity.isEmpty ? nil : trimmedQuantity) != item.quantity ||
               (trimmedNotes.isEmpty ? nil : trimmedNotes) != item.notes ||
               (trimmedBrand.isEmpty ? nil : trimmedBrand) != item.brand
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                Section("Ürün Bilgileri") {
                    // Item name
                    HStack {
                        Image(systemName: "cart.badge.plus")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)
                        
                        TextField("Ürün adı *", text: $itemName)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .focused($nameFieldFocused)
                            .submitLabel(.next)
                    }
                    
                    // Quantity
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)
                        
                        TextField("Miktar (örn: 2 adet, 1 kg)", text: $quantity)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .submitLabel(.next)
                    }
                    
                    // Brand
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)
                        
                        TextField("Marka (isteğe bağlı)", text: $brand)
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .submitLabel(.next)
                    }
                }
                
                // Notes Section
                Section("Notlar") {
                    HStack(alignment: .top) {
                        Image(systemName: "note.text")
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(width: 24)
                            .padding(.top, 4)
                        
                        TextField(
                            "Ek notlar (isteğe bağlı)",
                            text: $notes,
                            axis: .vertical
                        )
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .lineLimit(3...6)
                    }
                }
                
                // Item Status Section
                Section("Durum") {
                    HStack {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCompleted ? AppTheme.success : .secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.isCompleted ? "Tamamlandı" : "Bekliyor")
                                .font(.system(size: 17, weight: .regular, design: .rounded))
                                .foregroundColor(.primary)
                            
                            if item.isCompleted, let completedDate = item.dateCompleted {
                                Text("Tamamlanma: \(completedDate, style: .date)")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Oluşturma: \(item.dateCreated, style: .date)")
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Ürünü Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveChanges()
                    }
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .fontWeight(.semibold)
                    .disabled(!canSave || !hasChanges)
                }
            }
        }
    }
    
    private func saveChanges() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update item properties
        item.name = trimmedName
        item.quantity = trimmedQuantity.isEmpty ? nil : trimmedQuantity
        item.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        item.brand = trimmedBrand.isEmpty ? nil : trimmedBrand
        
        onSave(item)
        dismiss()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let item = ShoppingListItem.create(
        name: "Test Ürün",
        category: "Genel",
        quantity: "1 adet",
        notes: "Test notu",
        in: context
    )
    
    EditShoppingItemSheet(
        item: item,
        onSave: { _ in }
    )
}