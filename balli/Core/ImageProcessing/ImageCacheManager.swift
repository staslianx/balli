//
//  ImageCacheManager.swift
//  balli
//
//  High-performance image caching system for smooth scrolling
//

import SwiftUI
import UIKit
import OSLog

// MARK: - Image Cache Manager
@MainActor
final class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSString, UIImage>()

    // Pending decode operations to prevent duplicate work
    private var pendingDecodes: [String: Task<UIImage?, Never>] = [:]

    // Task for memory warning observation
    private var memoryWarningTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.balli",
        category: "ImageCache"
    )

    init() {
        cache.countLimit = 100  // Maximum number of images
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB

        // MODERN FIX: Use Task-based observation instead of @objc
        memoryWarningTask = Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.didReceiveMemoryWarningNotification
            ) {
                logger.warning("⚠️ [MEMORY] Memory warning received - clearing cache")
                clearCache()
            }
        }
    }

    deinit {
        memoryWarningTask?.cancel()
    }

    // Async image decoding from Data using modern Swift 6 concurrency
    func decodeImage(from data: Data, key: String) async -> UIImage? {
        // Check if already cached
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }

        // Check if already decoding
        if let pendingTask = pendingDecodes[key] {
            return await pendingTask.value
        }

        // Create new decode task using Task.detached for background work
        let task = Task<UIImage?, Never> { @MainActor in
            // CRITICAL FIX: Use defer to ensure cleanup happens even on error/cancellation
            defer {
                self.pendingDecodes.removeValue(forKey: key)
            }

            // PERFORMANCE FIX: Use CGContext-based decompression (truly thread-safe, off main thread)
            let decodedImage = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let image = UIImage(data: data) else {
                    return nil
                }

                // Use CGImage-based decompression instead of UIGraphics (thread-safe)
                guard let cgImage = image.cgImage else {
                    return image
                }

                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)

                guard let context = CGContext(
                    data: nil,
                    width: cgImage.width,
                    height: cgImage.height,
                    bitsPerComponent: 8,
                    bytesPerRow: cgImage.width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) else {
                    return image
                }

                let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
                context.draw(cgImage, in: rect)

                guard let decompressedCGImage = context.makeImage() else {
                    return image
                }

                // Return UIImage with same scale and orientation
                return UIImage(
                    cgImage: decompressedCGImage,
                    scale: image.scale,
                    orientation: image.imageOrientation
                )
            }.value

            // Cache the result on main actor
            if let image = decodedImage {
                self.cache.setObject(image, forKey: key as NSString, cost: data.count)
            }

            return decodedImage
        }

        pendingDecodes[key] = task
        return await task.value
    }

    // Get image from cache synchronously (for already loaded images)
    func getCachedImage(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    private func clearCache() {
        cache.removeAllObjects()
        pendingDecodes.removeAll()
        logger.info("🧹 [MEMORY] Cache cleared - freed ~50MB")
    }
}

// MARK: - Cached Image View
struct CachedImageView: View {
    let imageData: Data?
    let imageURL: String?
    let cacheKey: String

    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    @StateObject private var cacheManager = ImageCacheManager.shared

    var body: some View {
        GeometryReader { geometry in
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else if let imageData = imageData {
                // Local data - show placeholder while decoding
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                            .opacity(isLoading ? 1 : 0)
                    )
                    .onAppear {
                        loadImageFromData(imageData)
                    }
            } else if let imageURL = imageURL, let url = URL(string: imageURL) {
                // Remote URL - use AsyncImage
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
            } else {
                // No image
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
    }

    private func loadImageFromData(_ data: Data) {
        // Check cache first
        if let cached = cacheManager.getCachedImage(for: cacheKey) {
            cachedImage = cached
            return
        }

        // Decode async
        isLoading = true
        Task {
            let decodedImage = await cacheManager.decodeImage(from: data, key: cacheKey)
            await MainActor.run {
                self.cachedImage = decodedImage
                self.isLoading = false
            }
        }
    }
}
