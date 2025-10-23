//
//  AddShoppingItemSheet.swift
//  balli
//
//  Sheet for adding new shopping list items with categories, notes, and quantity
//

import SwiftUI

struct AddShoppingItemSheet: View {
    @Binding var itemName: String
    @Binding var quantity: String
    @Binding var category: String
    
    let onSave: (String, String?, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var notes = ""
    @State private var brand = ""
    @FocusState private var nameFieldFocused: Bool
    
    private var canSave: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            }
            .navigationTitle("Yeni Ürün")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveItem()
                    }
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            nameFieldFocused = true
        }
    }
    
    private func saveItem() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let _ = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        
        onSave(
            trimmedName,
            trimmedQuantity.isEmpty ? nil : trimmedQuantity,
            trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        
        dismiss()
    }
}

// MARK: - Category Picker View
struct CategoryPickerView: View {
    @Binding var selectedCategory: String
    
    private let categories = ShoppingListItem.ShoppingCategory.allCases
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(categories, id: \.self) { category in
                Button(action: {
                    selectedCategory = category.rawValue
                }) {
                    VStack(spacing: 4) {
                        Text(category.icon)
                            .font(.title2)
                        
                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedCategory == category.rawValue ? 
                                  AppTheme.primaryPurple.opacity(0.15) : 
                                  Color(.tertiarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selectedCategory == category.rawValue ? 
                                   AppTheme.primaryPurple : Color.clear, 
                                   lineWidth: 1.5)
                    )
                    .foregroundColor(selectedCategory == category.rawValue ? 
                                    AppTheme.primaryPurple : .primary)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: selectedCategory)
            }
        }
    }
}

#Preview {
    @Previewable @State var itemName = ""
    @Previewable @State var quantity = ""
    @Previewable @State var category = ShoppingListItem.ShoppingCategory.general.rawValue
    
    AddShoppingItemSheet(
        itemName: $itemName,
        quantity: $quantity,
        category: $category,
        onSave: { _, _, _ in }
    )
}