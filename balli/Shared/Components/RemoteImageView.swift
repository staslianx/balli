//
//  RemoteImageView.swift
//  balli
//
//  SwiftUI view for displaying images from remote storage or local data
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct RemoteImageView: View {
    let imageURL: String?
    let imageData: Data?
    let contentMode: ContentMode
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var imageOpacity: Double = 0  // For fade-in animation
    @State private var imageScale: CGFloat = 0.95  // For scale animation
    
    init(imageURL: String? = nil, imageData: Data? = nil, contentMode: ContentMode = .fit) {
        self.imageURL = imageURL
        self.imageData = imageData
        self.contentMode = contentMode
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                // Display loaded image with fade-in and scale animation
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(imageOpacity)
                    .scaleEffect(imageScale)
                    .onAppear {
                        // Smooth fade-in and scale animation when image appears
                        withAnimation(.easeOut(duration: 0.6)) {
                            imageOpacity = 1.0
                            imageScale = 1.0
                        }
                    }
            } else if isLoading {
                // Loading state
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            } else if loadError != nil {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Görüntü yüklenemedi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            } else {
                // Placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: imageURL) { _, newURL in
            loadImage()
        }
        .onChange(of: imageData) { _, newData in
            loadImage()
        }
    }
    
    private func loadImage() {
        // Reset state
        loadedImage = nil
        loadError = nil
        imageOpacity = 0  // Reset opacity for new image
        imageScale = 0.95  // Reset scale for new image
        
        // First try to load from local data
        if let imageData = imageData,
           let image = UIImage(data: imageData) {
            loadedImage = image
            return
        }
        
        // Then try to load from remote URL
        if let urlString = imageURL, !urlString.isEmpty {
            isLoading = true

            Task {
                // Note: Remote image loading requires storage backend integration
                await MainActor.run {
                    self.loadError = "Remote image loading temporarily unavailable"
                    self.isLoading = false
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    VStack {
        // With local data
        RemoteImageView(
            imageData: UIImage(systemName: "photo")?.pngData()
        )
        .frame(height: 200)
        
        // With remote URL (placeholder)
        RemoteImageView(
            imageURL: "https://example.com/image.jpg"
        )
        .frame(height: 200)
        
        // Loading state
        RemoteImageView()
        .frame(height: 200)
    }
    .padding()
}