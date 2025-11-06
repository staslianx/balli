//
//  ImageCacheManager.swift
//  balli
//
//  High-performance image caching system for smooth scrolling
//

import SwiftUI
import UIKit

// MARK: - Image Cache Manager
@MainActor
final class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSString, UIImage>()

    // Pending decode operations to prevent duplicate work
    private var pendingDecodes: [String: Task<UIImage?, Never>] = [:]

    init() {
        cache.countLimit = 100  // Maximum number of images
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB

        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        // CLEANUP: Remove observer to prevent memory leaks
        NotificationCenter.default.removeObserver(self)

        // Cancel any pending decode operations
        for (_, task) in pendingDecodes {
            task.cancel()
        }
        pendingDecodes.removeAll()
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
            // Decode off main thread using Task.detached with high priority
            let decodedImage = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let image = UIImage(data: data) else {
                    return nil
                }

                // Force decompression by drawing (improves scroll performance)
                UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
                defer { UIGraphicsEndImageContext() }
                image.draw(at: .zero)
                let decompressedImage = UIGraphicsGetImageFromCurrentImageContext()

                return decompressedImage ?? image
            }.value

            // Cache the result on main actor
            if let image = decodedImage {
                self.cache.setObject(image, forKey: key as NSString, cost: data.count)
            }

            // Remove from pending
            self.pendingDecodes.removeValue(forKey: key)

            return decodedImage
        }

        pendingDecodes[key] = task
        return await task.value
    }

    // Get image from cache synchronously (for already loaded images)
    func getCachedImage(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    @objc private func clearCache() {
        cache.removeAllObjects()
        pendingDecodes.removeAll()
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
