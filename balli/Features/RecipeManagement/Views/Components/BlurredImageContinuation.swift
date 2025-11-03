//
//  BlurredImageContinuation.swift
//  balli
//
//  Blurred image continuation effect that extends below hero images
//  Creates smooth transition from hero image to background
//

import SwiftUI

/// Blurred continuation of an image that fades out vertically
/// Used to create seamless transition from hero image to background
///
/// **How it works:**
/// 1. Takes the same image as the hero image above it
/// 2. Applies heavy blur to the image
/// 3. Applies a vertical linear gradient mask:
///    - Top: Fully opaque (blurred image completely visible)
///    - Middle: Gradual fade
///    - Bottom: Fully transparent (background shows through)
///
/// **Usage Example:**
/// ```swift
/// BlurredImageContinuation(
///     image: heroImage,
///     height: 180,        // How tall the blurred area is
///     blurRadius: 60,     // How blurred the image is
///     fadeStart: 0.0,     // Start fade at top (0.0)
///     fadeEnd: 1.0        // Complete fade at bottom (1.0)
/// )
/// ```
struct BlurredImageContinuation: View {
    @Environment(\.colorScheme) private var colorScheme
    let image: UIImage?
    let height: CGFloat
    let blurRadius: CGFloat
    let fadeStart: CGFloat  // Where fade begins (0.0 = top, 1.0 = bottom)
    let fadeEnd: CGFloat    // Where fade completes (0.0 = top, 1.0 = bottom)

    /// Create blurred image continuation with configurable parameters
    /// - Parameters:
    ///   - image: The same image shown in the hero image above
    ///   - height: Height of the blurred continuation area (default: 200pt)
    ///   - blurRadius: How blurred the image should be (default: 50pt)
    ///   - fadeStart: Where vertical fade begins, 0.0-1.0 (default: 0.0 = top)
    ///   - fadeEnd: Where vertical fade completes, 0.0-1.0 (default: 1.0 = bottom)
    init(
        image: UIImage?,
        height: CGFloat = 200,
        blurRadius: CGFloat = 50,
        fadeStart: CGFloat = 0.0,
        fadeEnd: CGFloat = 1.0
    ) {
        self.image = image
        self.height = height
        self.blurRadius = blurRadius
        self.fadeStart = fadeStart
        self.fadeEnd = fadeEnd
    }

    var body: some View {
        if let image = image {
            ZStack {
                // Heavily blurred image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .blur(radius: blurRadius)

                // Warm color overlay to blend with background
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.8, opacity: 0.3),
                        Color(red: 0.95, green: 0.90, blue: 0.75, opacity: 0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.overlay)
            }
            .mask(
                // Aggressive vertical gradient mask for seamless fade
                LinearGradient(
                    stops: [
                        // Start with some transparency to blend better
                        .init(color: .white.opacity(0.6), location: fadeStart),
                        .init(color: .white.opacity(0.5), location: fadeStart + (fadeEnd - fadeStart) * 0.1),

                        // Rapid fade through middle
                        .init(color: .white.opacity(0.35), location: fadeStart + (fadeEnd - fadeStart) * 0.25),
                        .init(color: .white.opacity(0.2), location: fadeStart + (fadeEnd - fadeStart) * 0.4),
                        .init(color: .white.opacity(0.1), location: fadeStart + (fadeEnd - fadeStart) * 0.6),
                        .init(color: .white.opacity(0.03), location: fadeStart + (fadeEnd - fadeStart) * 0.8),

                        // Fully transparent at bottom
                        .init(color: .clear, location: fadeEnd)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipped()
        }
    }
}

// MARK: - Data Extension

extension BlurredImageContinuation {
    /// Initialize with Data (imageData from Core Data)
    init(
        imageData: Data?,
        height: CGFloat = 200,
        blurRadius: CGFloat = 50,
        fadeStart: CGFloat = 0.0,
        fadeEnd: CGFloat = 1.0
    ) {
        if let imageData = imageData,
           let uiImage = UIImage(data: imageData) {
            self.init(
                image: uiImage,
                height: height,
                blurRadius: blurRadius,
                fadeStart: fadeStart,
                fadeEnd: fadeEnd
            )
        } else {
            self.init(
                image: nil,
                height: height,
                blurRadius: blurRadius,
                fadeStart: fadeStart,
                fadeEnd: fadeEnd
            )
        }
    }

    /// Initialize with URL (async loaded images)
    init(
        imageURL: String?,
        height: CGFloat = 200,
        blurRadius: CGFloat = 50,
        fadeStart: CGFloat = 0.0,
        fadeEnd: CGFloat = 1.0
    ) {
        // For URL-based images, we can't easily get the UIImage synchronously
        // This initializer is here for API completeness but will show nothing
        // Use the UIImage initializer after async loading in the parent view
        self.init(
            image: nil,
            height: height,
            blurRadius: blurRadius,
            fadeStart: fadeStart,
            fadeEnd: fadeEnd
        )
    }
}

// MARK: - Preview

#Preview("Blurred Continuation") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack(spacing: 0) {
            // Simulated hero image
            Image(systemName: "photo.fill")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 400)
                .background(Color.orange)
                .clipped()

            // Blurred continuation
            BlurredImageContinuation(
                image: UIImage(systemName: "photo.fill"),
                height: 200,
                blurRadius: 50
            )

            Spacer()
        }
        .ignoresSafeArea()
    }
}

#Preview("Smooth Fade Transition") {
    @Previewable @State var colorScheme: ColorScheme = .light

    ZStack {
        // Warm background (what shows through the fade)
        Color(red: 0.95, green: 0.90, blue: 0.75)
            .ignoresSafeArea()

        VStack(spacing: 0) {
            // Hero image
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.7),
                            Color(red: 1.0, green: 0.85, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Simulate photo content
                    Image(systemName: "fork.knife")
                        .font(.system(size: 100))
                        .foregroundColor(AppTheme.foregroundOnColor(for: colorScheme).opacity(0.3))
                )
                .frame(height: 400)

            // Blurred continuation with gradient mask
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.85, blue: 0.5),
                            Color(red: 1.0, green: 0.80, blue: 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 50)
                .frame(height: 180)
                .mask(
                    // Same gradient as component
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white.opacity(0.95), location: 0.15),
                            .init(color: .white.opacity(0.8), location: 0.3),
                            .init(color: .white.opacity(0.6), location: 0.5),
                            .init(color: .white.opacity(0.35), location: 0.7),
                            .init(color: .white.opacity(0.15), location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Content area (visible through fade)
            VStack(alignment: .leading, spacing: 16) {
                Text("Recipe Title")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("This text appears through the smooth gradient fade. Notice how the blurred image seamlessly transitions from fully visible at the top to completely transparent at the bottom.")
                    .font(.system(size: 17, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

#Preview("Different Fade Ranges") {
    ScrollView {
        VStack(spacing: 40) {
            // Full fade (0.0 → 1.0)
            VStack(spacing: 8) {
                Text("Full Fade (0.0 → 1.0)")
                    .font(.headline)

                ZStack {
                    Color.gray.opacity(0.1)

                    Rectangle()
                        .fill(Color.orange)
                        .blur(radius: 30)
                        .frame(height: 150)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0.8), location: 0.3),
                                    .init(color: .white.opacity(0.35), location: 0.7),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 150)
            }

            // Delayed start (0.2 → 1.0)
            VStack(spacing: 8) {
                Text("Delayed Start (0.2 → 1.0)")
                    .font(.headline)

                ZStack {
                    Color.gray.opacity(0.1)

                    Rectangle()
                        .fill(Color.blue)
                        .blur(radius: 30)
                        .frame(height: 150)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.2),
                                    .init(color: .white.opacity(0.8), location: 0.4),
                                    .init(color: .white.opacity(0.35), location: 0.7),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 150)
            }

            // Early end (0.0 → 0.8)
            VStack(spacing: 8) {
                Text("Early End (0.0 → 0.8)")
                    .font(.headline)

                ZStack {
                    Color.gray.opacity(0.1)

                    Rectangle()
                        .fill(Color.green)
                        .blur(radius: 30)
                        .frame(height: 150)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white.opacity(0.8), location: 0.3),
                                    .init(color: .white.opacity(0.35), location: 0.6),
                                    .init(color: .clear, location: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 150)
            }
        }
        .padding()
    }
}
