//
//  EditableFoodItem.swift
//  balli
//
//  Editable version of food item for user corrections
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Editable version of food item for user corrections
struct EditableFoodItem: Identifiable, Sendable, Equatable {
    let id: UUID
    var name: String
    var amount: String
    var carbs: String  // String for TextField

    init(id: UUID = UUID(), name: String, amount: String?, carbs: Int?) {
        self.id = id
        self.name = name
        self.amount = amount ?? ""
        self.carbs = carbs.map { "\($0)" } ?? ""
    }

    /// Convert to Int for saving
    var carbsInt: Int? {
        Int(carbs)
    }
}
