//
//  ScanImage+Extensions.swift
//  balli
//
//  Created for Business Logic and Convenience Methods
//

import Foundation
import CoreData
import UIKit

// MARK: - Image Type Enum
public enum ScanImageType: String, CaseIterable {
    case nutritionLabel = "nutrition_label"
    case productFront = "product_front"
    case barcode = "barcode"
    
    var displayName: String {
        switch self {
        case .nutritionLabel: return NSLocalizedString("scan.type.nutritionLabel", comment: "Nutrition Label")
        case .productFront: return NSLocalizedString("scan.type.productFront", comment: "Product Front")
        case .barcode: return NSLocalizedString("scan.type.barcode", comment: "Barcode")
        }
    }
    
    var icon: String {
        switch self {
        case .nutritionLabel: return "doc.text.viewfinder"
        case .productFront: return "camera.viewfinder"
        case .barcode: return "barcode.viewfinder"
        }
    }
}

// MARK: - ScanImage Business Logic
extension ScanImage {
    
    /// Image type as enum
    var imageTypeEnum: ScanImageType? {
        return ScanImageType(rawValue: imageType)
    }
    
    /// UIImage representation
    var uiImage: UIImage? {
        return UIImage(data: imageData)
    }
    
    /// Thumbnail UIImage
    var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
    
    /// Generate thumbnail if not exists
    func generateThumbnail(maxSize: CGFloat = 150) {
        guard thumbnailData == nil,
              let image = uiImage else { return }
        
        let size = CGSize(width: maxSize, height: maxSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let thumbnail = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        thumbnailData = thumbnail.jpegData(compressionQuality: 0.7)
    }
    
    /// Formatted scan date
    var formattedScanDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scanDate)
    }
    
    /// Processing status description
    var processingStatus: String {
        if aiProcessed {
            if let model = aiModel {
                return String(format: NSLocalizedString("scan.processed.withModel", comment: "Processed with %@"), model)
            }
            return NSLocalizedString("scan.processed", comment: "Processed")
        } else {
            return NSLocalizedString("scan.pending", comment: "Pending Processing")
        }
    }
    
    /// Processing time description
    var processingTimeDescription: String? {
        guard aiProcessed && processingTime > 0 else { return nil }
        
        if processingTime < 1 {
            let ms = Int(processingTime * 1000)
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", processingTime)
        }
    }
    
    /// Parse AI response as dictionary
    var aiResponseDictionary: [String: Any]? {
        guard let response = aiResponse,
              let data = response.data(using: .utf8) else { return nil }
        
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
    
    /// Extracted nutrition data from AI response
    var extractedNutrition: [String: Double]? {
        guard let dict = aiResponseDictionary,
              let nutrition = dict["nutrition"] as? [String: Any] else { return nil }
        
        var result: [String: Double] = [:]
        
        // Extract numeric values
        for (key, value) in nutrition {
            if let number = value as? Double {
                result[key] = number
            } else if let number = value as? Int {
                result[key] = Double(number)
            } else if let string = value as? String,
                      let number = Double(string) {
                result[key] = number
            }
        }
        
        return result.isEmpty ? nil : result
    }
    
    /// Confidence scores from AI response
    var confidenceScores: [String: Double]? {
        guard let dict = aiResponseDictionary,
              let confidence = dict["confidence"] as? [String: Any] else { return nil }
        
        var result: [String: Double] = [:]
        
        for (key, value) in confidence {
            if let number = value as? Double {
                result[key] = number
            }
        }
        
        return result.isEmpty ? nil : result
    }
}

// MARK: - Fetch Requests
extension ScanImage {
    
    /// Fetch unprocessed scans
    @nonobjc public class func unprocessedScans() -> NSFetchRequest<ScanImage> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "aiProcessed == false")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ScanImage.scanDate, ascending: true)
        ]
        
        return request
    }
    
    /// Fetch scans by type
    @nonobjc public class func scansByType(_ type: ScanImageType) -> NSFetchRequest<ScanImage> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "imageType == %@", type.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ScanImage.scanDate, ascending: false)
        ]
        
        return request
    }
    
    /// Fetch recent scans
    @nonobjc public class func recentScans(limit: Int = 20) -> NSFetchRequest<ScanImage> {
        let request = fetchRequest()
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ScanImage.scanDate, ascending: false)
        ]
        request.fetchLimit = limit
        
        return request
    }
    
    /// Fetch scans for food item
    @nonobjc public class func scansForFoodItem(_ foodItem: FoodItem) -> NSFetchRequest<ScanImage> {
        let request = fetchRequest()
        
        request.predicate = NSPredicate(format: "foodItem == %@", foodItem)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ScanImage.scanDate, ascending: false)
        ]
        
        return request
    }
}