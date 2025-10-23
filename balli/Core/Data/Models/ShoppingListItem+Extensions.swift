//
//  ShoppingListItem+Extensions.swift
//  balli
//
//  Shopping list item convenience methods and computed properties
//

import Foundation
import CoreData

// MARK: - Computed Properties
extension ShoppingListItem {
    
    /// Display name with quantity if available
    var displayName: String {
        if let quantity = quantity, !quantity.isEmpty {
            return "\(quantity) \(name)"
        }
        return name
    }
    
    /// Display category with fallback
    var displayCategory: String {
        return category ?? "Genel"
    }
    
    /// Whether the item has notes
    var hasNotes: Bool {
        guard let notes = notes else { return false }
        return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Days since created
    var daysSinceCreated: Int {
        Calendar.current.dateComponents([.day], from: dateCreated, to: Date()).day ?? 0
    }
}

// MARK: - Static Methods
extension ShoppingListItem {
    
    /// Creates a new shopping list item
    static func create(
        name: String,
        category: String? = nil,
        quantity: String? = nil,
        brand: String? = nil,
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) -> ShoppingListItem {
        let item = ShoppingListItem(context: context)
        item.name = name.capitalized
        item.category = category
        item.quantity = quantity
        item.brand = brand
        item.notes = notes
        
        // Set sort order to be last
        item.sortOrder = getNextSortOrder(in: context)
        
        return item
    }
    
    /// Gets the next available sort order
    private static func getNextSortOrder(in context: NSManagedObjectContext) -> Int32 {
        let request: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: false)]
        request.fetchLimit = 1
        
        do {
            let items = try context.fetch(request)
            return (items.first?.sortOrder ?? 0) + 1
        } catch {
            return 0
        }
    }
}

// MARK: - Fetch Requests
extension ShoppingListItem {
    
    /// Fetch request for all incomplete items, sorted by sort order (newest first)
    static func fetchIncompleteItems() -> NSFetchRequest<ShoppingListItem> {
        let request: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == false")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: false)]
        return request
    }
    
    /// Fetch request for all completed items, sorted by completion date
    static func fetchCompletedItems() -> NSFetchRequest<ShoppingListItem> {
        let request: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == true")
        request.sortDescriptors = [NSSortDescriptor(key: "dateCompleted", ascending: false)]
        return request
    }
    
    /// Fetch request for items by category
    static func fetchItems(in category: String) -> NSFetchRequest<ShoppingListItem> {
        let request: NSFetchRequest<ShoppingListItem> = ShoppingListItem.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "sortOrder", ascending: false)
        ]
        return request
    }
}

// MARK: - Categories
extension ShoppingListItem {
    
    enum ShoppingCategory: String, CaseIterable {
        case dairy = "Süt Ürünleri"
        case meat = "Et & Balık"
        case fruits = "Meyve & Sebze"
        case grains = "Tahıl & Ekmek"
        case snacks = "Atıştırmalık"
        case drinks = "İçecek"
        case cleaning = "Temizlik"
        case personal = "Kişisel Bakım"
        case general = "Genel"
        
        var icon: String {
            switch self {
            case .dairy: return "🥛"
            case .meat: return "🥩"
            case .fruits: return "🍎"
            case .grains: return "🍞"
            case .snacks: return "🍿"
            case .drinks: return "🥤"
            case .cleaning: return "🧽"
            case .personal: return "🧴"
            case .general: return "🛒"
            }
        }
    }
    
    /// Get all available categories
    static var allCategories: [String] {
        return ShoppingCategory.allCases.map { $0.rawValue }
    }
    
    /// Get icon for category
    var categoryIcon: String {
        guard let category = category,
              let shoppingCategory = ShoppingCategory(rawValue: category) else {
            return ShoppingCategory.general.icon
        }
        return shoppingCategory.icon
    }
}

// MARK: - Validation
extension ShoppingListItem {
    
    /// Validates the shopping list item
    var isValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Validation error messages
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Ürün adı boş olamaz")
        }
        
        if let quantity = quantity, !quantity.isEmpty {
            // Basic quantity validation could be added here
        }
        
        return errors
    }
}