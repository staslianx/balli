//
//  RecipeImageService.swift
//  balli
//
//  Service responsible for recipe image operations including generation, upload, and loading
//  Swift 6 strict concurrency compliant
//

import SwiftUI
import CoreData
import Foundation
import OSLog

// MARK: - Image Service Protocol

@MainActor
protocol RecipeImageServiceProtocol {
    var recipeImageURL: String? { get set }
    var recipeImageData: Data? { get set }
    var isUploadingImage: Bool { get }
    var isLoadingImageFromStorage: Bool { get }
    var isImageFromLocalData: Bool { get }
    
    func loadImageFromStorage(_ urlString: String) async
    func uploadImageToStorage(imageData: Data) async
    func uploadImageToStorageInBackground(imageData: Data, recipe: Recipe) async
    func clearImageError()
}

// MARK: - Recipe Image Service Implementation

@MainActor
final class RecipeImageService: RecipeImageServiceProtocol {

    // MARK: - Logging
    private let logger = AppLoggers.Recipe.generation

    // MARK: - Properties
    var recipeImageURL: String? = nil
    var recipeImageData: Data? = nil
    var isUploadingImage = false
    var isLoadingImageFromStorage = false

    // MARK: - Computed Properties

    /// Track if image is from local Core Data (not being loaded from storage)
    var isImageFromLocalData: Bool {
        // Image is from local data if we have image data but are NOT loading from storage
        return recipeImageData != nil && !isLoadingImageFromStorage
    }

    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    
    // MARK: - Image Loading
    
    func loadImageFromStorage(_ urlString: String) async {
        isLoadingImageFromStorage = true

        // Note: Image loading requires storage backend integration
        logger.debug("Image loading not yet implemented - URL: \(urlString)")
        isLoadingImageFromStorage = false
    }

    // MARK: - Image Upload

    func uploadImageToStorage(imageData: Data) async {
        isUploadingImage = true

        // Note: Image upload requires storage backend integration
        logger.debug("Image upload not yet implemented - size: \(imageData.count) bytes")
        isUploadingImage = false
    }

    func uploadImageToStorageInBackground(imageData: Data, recipe: Recipe) async {
        // Note: Background image upload requires storage backend integration
        _ = recipe.id
        logger.debug("Background image upload scheduled - imageSize: \(imageData.count) bytes")
    }
    
    func clearImageError() {
        // No-op since image generation errors were removed
    }
}

