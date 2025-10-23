//
//  RecipeImageColorExtractor.swift
//  balli
//
//  Extracts dominant colors from recipe images for gradient backgrounds
//

import SwiftUI
import UIKit
import CoreImage

@MainActor
public class RecipeImageColorExtractor: ObservableObject {
    @Published public var extractedColors: [Color] = []
    @Published public var gradientColors: [Color] = []
    @Published public var isProcessing: Bool = false
    
    private let context = CIContext()
    
    public init() {}
    
    /// Extract dominant colors from image data
    public func extractColors(from imageData: Data?) {
        guard let imageData = imageData,
              let uiImage = UIImage(data: imageData) else {
            // If no image, return default colors
            self.gradientColors = defaultGradient()
            return
        }
        
        isProcessing = true
        
        Task {
            let colors = await processImage(uiImage)
            await MainActor.run {
                self.extractedColors = colors
                self.gradientColors = createGradient(from: colors)
                self.isProcessing = false
            }
        }
    }
    
    /// Process image to extract colors
    private func processImage(_ image: UIImage) async -> [Color] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Resize image for faster processing
        let targetSize = CGSize(width: 100, height: 100)
        guard let resizedImage = resizeImage(cgImage, to: targetSize) else { return [] }
        
        // Extract colors using different methods
        var colors: [Color] = []
        
        // Skip average color - it tends to create muddy neutrals
        // Instead, focus on getting distinct vibrant colors
        
        // Method 1: Get vibrant colors (prioritize this)
        let vibrantColors = getVibrantColors(from: resizedImage)
        colors.append(contentsOf: vibrantColors)
        
        // Method 2: Get dominant colors from different regions
        let regionColors = getRegionColors(from: resizedImage)
        // Filter out only very neutral colors, but keep pastels
        let filteredRegionColors = regionColors.filter { color in
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            // Check if it's too close to gray (all channels similar)
            let maxDiff = max(abs(r - g), abs(g - b), abs(r - b))
            
            // Keep colors that have some color variation (not pure gray)
            // or have reasonable saturation for food colors
            if let hsb = color.toHSB() {
                return maxDiff > 0.05 || hsb.saturation > 0.1
            }
            return true
        }
        colors.append(contentsOf: filteredRegionColors)
        
        // Remove duplicates and limit colors for readability
        let uniqueColors = removeSimilarColors(colors, threshold: 0.35) // Higher threshold to merge similar colors
        return Array(uniqueColors.prefix(4)) // Limit to 4 main colors for better readability
    }
    
    /// Get average color from image
    private func getAverageColor(from cgImage: CGImage) -> Color? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalRed = 0
        var totalGreen = 0
        var totalBlue = 0
        let pixelCount = width * height
        
        for y in 0..<height {
            for x in 0..<width {
                let index = ((width * y) + x) * bytesPerPixel
                totalRed += Int(pixelData[index])
                totalGreen += Int(pixelData[index + 1])
                totalBlue += Int(pixelData[index + 2])
            }
        }
        
        return Color(
            red: Double(totalRed) / (Double(pixelCount) * 255.0),
            green: Double(totalGreen) / (Double(pixelCount) * 255.0),
            blue: Double(totalBlue) / (Double(pixelCount) * 255.0)
        )
    }
    
    /// Get colors from different regions of the image
    private func getRegionColors(from cgImage: CGImage) -> [Color] {
        var colors: [Color] = []
        // Create a 3x3 grid for more accurate color sampling
        let gridSize = 3
        let regionSize = 1.0 / Double(gridSize)
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let region = CGRect(
                    x: Double(col) * regionSize,
                    y: Double(row) * regionSize,
                    width: regionSize,
                    height: regionSize
                )
                
                if let croppedImage = cropImage(cgImage, to: region),
                   let color = getAverageColor(from: croppedImage) {
                    // Store color with its position for later gradient reconstruction
                    colors.append(color)
                }
            }
        }
        
        return colors
    }
    
    /// Get vibrant colors by finding high saturation pixels
    private func getVibrantColors(from cgImage: CGImage) -> [Color] {
        var colorBuckets: [String: [Color]] = [:]
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Sample every 5th pixel for better color detection
        for y in stride(from: 0, to: height, by: 5) {
            for x in stride(from: 0, to: width, by: 5) {
                let index = ((width * y) + x) * bytesPerPixel
                let r = Double(pixelData[index]) / 255.0
                let g = Double(pixelData[index + 1]) / 255.0
                let b = Double(pixelData[index + 2]) / 255.0
                
                // Convert to HSB to check saturation and categorize by hue
                let color = Color(red: r, green: g, blue: b)
                if let hsb = color.toHSB() {
                    // Lower thresholds for food colors (pastels, creams, etc.)
                    // Also check if it's a distinct color (not gray/beige)
                    let isDistinctColor = abs(r - g) > 0.08 || abs(g - b) > 0.08 || abs(r - b) > 0.08
                    
                    if (hsb.saturation > 0.15 && hsb.brightness > 0.2) || isDistinctColor {
                        // Categorize by hue range to preserve distinct colors
                        let hueCategory = getHueCategory(hue: hsb.hue)
                        if colorBuckets[hueCategory] == nil {
                            colorBuckets[hueCategory] = []
                        }
                        colorBuckets[hueCategory]?.append(color)
                    }
                }
            }
        }
        
        // Get the most vibrant color from each hue category
        var distinctColors: [Color] = []
        for (_, colors) in colorBuckets {
            if let mostVibrant = colors.max(by: { c1, c2 in
                let hsb1 = c1.toHSB() ?? (0, 0, 0)
                let hsb2 = c2.toHSB() ?? (0, 0, 0)
                return hsb1.saturation < hsb2.saturation
            }) {
                distinctColors.append(mostVibrant)
            }
        }
        
        return distinctColors
    }
    
    /// Categorize hue into distinct color ranges
    private func getHueCategory(hue: Double) -> String {
        switch hue {
        case 0..<0.05, 0.95...1.0: return "red"
        case 0.05..<0.11: return "orange"
        case 0.11..<0.18: return "yellow"
        case 0.18..<0.42: return "green"
        case 0.42..<0.65: return "blue"
        case 0.65..<0.85: return "purple"
        case 0.85..<0.95: return "pink"
        default: return "other"
        }
    }
    
    /// Remove similar colors
    private func removeSimilarColors(_ colors: [Color], threshold: Double = 0.2) -> [Color] {
        var uniqueColors: [Color] = []
        
        for color in colors {
            var isDuplicate = false
            for uniqueColor in uniqueColors {
                if colorDistance(color, uniqueColor) < threshold {
                    isDuplicate = true
                    break
                }
            }
            if !isDuplicate {
                uniqueColors.append(color)
            }
        }
        
        return uniqueColors
    }
    
    /// Calculate distance between two colors
    private func colorDistance(_ color1: Color, _ color2: Color) -> Double {
        let c1 = UIColor(color1)
        let c2 = UIColor(color2)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2
        
        return sqrt(dr*dr + dg*dg + db*db)
    }
    
    /// Cluster similar colors
    private func clusterColors(_ colors: [Color], maxClusters: Int) -> [Color] {
        guard !colors.isEmpty else { return [] }
        
        // Simple clustering - just take evenly spaced colors
        let step = max(1, colors.count / maxClusters)
        var clustered: [Color] = []
        
        for i in stride(from: 0, to: colors.count, by: step) {
            clustered.append(colors[i])
        }
        
        return clustered
    }
    
    /// Create a smooth gradient from extracted colors
    private func createGradient(from colors: [Color]) -> [Color] {
        guard !colors.isEmpty else { return defaultGradient() }
        
        // Don't sort - keep colors in their natural positions
        // Create subtle gradient for text readability
        if colors.count >= 3 {
            // Use colors with reduced saturation and opacity for readability
            return colors.map { color in
                if let hsb = color.toHSB() {
                    // Reduce saturation for subtlety
                    let reducedSaturation = hsb.saturation * 0.6
                    // Increase brightness slightly to keep it light
                    let adjustedBrightness = min(1.0, hsb.brightness + 0.2)
                    return Color(hue: hsb.hue, saturation: reducedSaturation, brightness: adjustedBrightness).opacity(0.4)
                }
                return color.opacity(0.4)
            }
        } else if colors.count == 2 {
            // For 2 colors, use both with reduced intensity
            return colors.map { color in
                if let hsb = color.toHSB() {
                    let reducedSaturation = hsb.saturation * 0.5
                    let adjustedBrightness = min(1.0, hsb.brightness + 0.25)
                    return Color(hue: hsb.hue, saturation: reducedSaturation, brightness: adjustedBrightness).opacity(0.35)
                }
                return color.opacity(0.35)
            }
        } else {
            // Single color - make it very subtle
            let baseColor = colors[0]
            if let hsb = baseColor.toHSB() {
                let reducedSaturation = hsb.saturation * 0.4
                let adjustedBrightness = min(1.0, hsb.brightness + 0.3)
                return [Color(hue: hsb.hue, saturation: reducedSaturation, brightness: adjustedBrightness).opacity(0.3)]
            }
            return [baseColor.opacity(0.3)]
        }
    }
    
    /// Default gradient when no image is available
    private func defaultGradient() -> [Color] {
        return [
            Color(.systemGray5).opacity(0.5),
            Color(.systemGray6).opacity(0.4),
            Color(.systemBackground).opacity(0.3)
        ]
    }
    
    /// Resize image for processing
    private func resizeImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    /// Crop image to region (normalized coordinates 0-1)
    private func cropImage(_ image: CGImage, to normalizedRect: CGRect) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        
        let cropRect = CGRect(
            x: normalizedRect.origin.x * width,
            y: normalizedRect.origin.y * height,
            width: normalizedRect.width * width,
            height: normalizedRect.height * height
        )
        
        return image.cropping(to: cropRect)
    }
}

// MARK: - Color Extensions
extension Color {
    /// Convert to HSB values
    func toHSB() -> (hue: Double, saturation: Double, brightness: Double)? {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        
        if uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return (hue: Double(h), saturation: Double(s), brightness: Double(b))
        }
        return nil
    }
    
    /// Desaturate color by percentage (0-1)
    func desaturated(by amount: Double) -> Color {
        guard let hsb = toHSB() else { return self }
        let newSaturation = max(0, hsb.saturation * (1 - amount))
        return Color(hue: hsb.hue, saturation: newSaturation, brightness: hsb.brightness)
    }
    
    /// Adjust brightness
    func brightness(_ amount: Double) -> Color {
        guard let hsb = toHSB() else { return self }
        let newBrightness = max(0, min(1, hsb.brightness * amount))
        return Color(hue: hsb.hue, saturation: hsb.saturation, brightness: newBrightness)
    }
    
    /// Blend two colors together
    static func blend(_ color1: Color, with color2: Color, ratio: Double) -> Color {
        let c1 = UIColor(color1)
        let c2 = UIColor(color2)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = r1 * (1 - ratio) + r2 * ratio
        let g = g1 * (1 - ratio) + g2 * ratio
        let b = b1 * (1 - ratio) + b2 * ratio
        let a = a1 * (1 - ratio) + a2 * ratio
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

extension UIColor {
    /// Get brightness value
    var brightness: CGFloat {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return b
    }
}