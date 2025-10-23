//
//  UserMedicalProfile+CoreDataClass.swift
//  balli
//
//  Created by Core Data Model Generator
//

import Foundation
import CoreData

@objc(UserMedicalProfile)
public class UserMedicalProfile: NSManagedObject, @unchecked Sendable {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "lastUpdated")
        setPrimitiveValue("1:10", forKey: "insulinToCarbRatio")
        setPrimitiveValue(50, forKey: "correctionFactor")
        setPrimitiveValue(100, forKey: "targetBloodSugar")
        setPrimitiveValue("LADA", forKey: "diabetesType")
        setPrimitiveValue("tr", forKey: "preferredLanguage")
        setPrimitiveValue([] as NSArray, forKey: "restrictions")
        setPrimitiveValue([] as NSArray, forKey: "preferredCuisines")
        setPrimitiveValue([] as NSArray, forKey: "dislikedIngredients")
    }
    
    override public func willSave() {
        super.willSave()
        
        if hasChanges {
            setPrimitiveValue(Date(), forKey: "lastUpdated")
        }
    }
    
    // Computed properties for easier access
    public var restrictionsList: [String] {
        return (restrictions as? [String]) ?? []
    }
    
    public var preferredCuisinesList: [String] {
        return (preferredCuisines as? [String]) ?? []
    }
    
    public var dislikedIngredientsList: [String] {
        return (dislikedIngredients as? [String]) ?? []
    }
    
    // Helper methods
    public func addRestriction(_ restriction: String) {
        var current = restrictionsList
        if !current.contains(restriction) {
            current.append(restriction)
            restrictions = current as NSArray
        }
    }
    
    public func removeRestriction(_ restriction: String) {
        var current = restrictionsList
        current.removeAll { $0 == restriction }
        restrictions = current as NSArray
    }
    
    public func addPreferredCuisine(_ cuisine: String) {
        var current = preferredCuisinesList
        if !current.contains(cuisine) {
            current.append(cuisine)
            preferredCuisines = current as NSArray
        }
    }
    
    public func removePreferredCuisine(_ cuisine: String) {
        var current = preferredCuisinesList
        current.removeAll { $0 == cuisine }
        preferredCuisines = current as NSArray
    }
    
    public func addDislikedIngredient(_ ingredient: String) {
        var current = dislikedIngredientsList
        if !current.contains(ingredient) {
            current.append(ingredient)
            dislikedIngredients = current as NSArray
        }
    }
    
    public func removeDislikedIngredient(_ ingredient: String) {
        var current = dislikedIngredientsList
        current.removeAll { $0 == ingredient }
        dislikedIngredients = current as NSArray
    }
}