# Creating Transitional Blur Effects in iOS Recipe Apps

The image you've shared demonstrates Apple's elegant **transitional blur effect** (also known as **progressive blur** or **variable blur**), commonly seen in system apps like Photos, TV, and App Store. This effect creates a smooth gradient from sharp content at the top to a fully blurred area at the bottom, where recipe metadata and actions are overlaid. Below is a comprehensive guide to replicating this effect in your iOS app.

## Understanding the Effect

The transitional blur in your screenshot shows a **Tamarind-Peach Lassi** recipe image that gradually blurs from clear at the top to heavily blurred at the bottom. This technique improves **text readability** over images while maintaining visual context and creating an immersive, modern interface. The blur isn't simply a transparent overlay—it uses sophisticated Gaussian blur techniques that vary in intensity across the image.[1][2][3][4][5][6]

## Approach 1: SwiftUI with Material and Gradient Mask (Recommended for Production)

For iOS 15 and later, the most production-safe approach combines **Material backgrounds** with **gradient masking**. This method uses only public APIs and passes App Store review without issues.[7][8][9]

### Basic Implementation

```swift
import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main recipe image
            AsyncImage(url: URL(string: recipe.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray
            }
            .ignoresSafeArea()

            // Blurred overlay with gradient mask
            VStack(spacing: 0) {
                Spacer()

                // Recipe info section
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.source)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Text(recipe.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(recipe.author)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))

                    HStack {
                        Label("Yield: \(recipe.yield)", systemImage: "person.2")
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                    // Action buttons
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Label("Cook", systemImage: "flame")
                        }

                        Button(action: {}) {
                            Label("Saved", systemImage: "bookmark.fill")
                        }

                        Button(action: {}) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.3))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    // The key: blurred material with gradient mask
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black, location: 0.3),
                                    .init(color: .black, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }
}
```

This implementation creates a **Material layer** (`.ultraThinMaterial` or `.thinMaterial`) and applies a **LinearGradient mask** to control where the blur appears. The gradient transitions from clear (0% opacity) at the top to fully opaque (100%) at the bottom, creating the smooth fade effect.[5][8][10][11][1][7]

### Alternative: Layered Blur Approach

For even smoother transitions, you can layer a blurred version of the image itself:

```swift
ZStack(alignment: .bottom) {
    // Original image
    Image(recipe.imageName)
        .resizable()
        .aspectRatio(contentMode: .fill)

    // Blurred copy with gradient mask
    Image(recipe.imageName)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .blur(radius: 20)
        .mask(
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )

    // Content overlay with darkening gradient
    VStack {
        // ... your content here
    }
    .background(
        LinearGradient(
            colors: [.black.opacity(0.6), .clear],
            startPoint: .bottom,
            endPoint: .top
        )
    )
}
```

This technique, demonstrated in community solutions, applies the `.blur()` modifier to a duplicate image layer and masks it with a gradient to control where the blur appears.[4][1][5]

## Approach 2: Variable Blur with CAFilter (For Exact Apple Effect)

To achieve the **exact same effect** Apple uses internally, you can use the private `CAFilter` API with `variableBlur` type. However, this carries **App Store rejection risk** since it relies on private APIs.[2][12][13]

### Implementation

Create a `VariableBlur.swift` file:

```swift
import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import QuartzCore

public enum VariableBlurDirection {
    case blurredTopClearBottom
    case blurredBottomClearTop
}

public struct VariableBlurView: UIViewRepresentable {
    public var maxBlurRadius: CGFloat = 20
    public var direction: VariableBlurDirection = .blurredBottomClearTop
    public var startOffset: CGFloat = 0

    public func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(maxBlurRadius: maxBlurRadius, direction: direction, startOffset: startOffset)
    }

    public func updateUIView(_ uiView: VariableBlurUIView, context: Context) {}
}

open class VariableBlurUIView: UIVisualEffectView {
    public init(maxBlurRadius: CGFloat = 20, direction: VariableBlurDirection = .blurredBottomClearTop, startOffset: CGFloat = 0) {
        super.init(effect: UIBlurEffect(style: .regular))

        guard let CAFilter = NSClassFromString("CAFilter") as? NSObject.Type else {
            print("[VariableBlur] Error: Can't find CAFilter class")
            return
        }

        guard let variableBlur = CAFilter.self.perform(NSSelectorFromString("filterWithType:"), with: "variableBlur").takeUnretainedValue() as? NSObject else {
            print("[VariableBlur] Error: CAFilter can't create filterWithType: variableBlur")
            return
        }

        let gradientImage = makeGradientImage(startOffset: startOffset, direction: direction)
        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        let backdropLayer = subviews.first?.layer
        backdropLayer?.filters = [variableBlur]

        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func didMoveToWindow() {
        guard let window, let backdropLayer = subviews.first?.layer else { return }
        backdropLayer.setValue(window.screen.scale, forKey: "scale")
    }

    private func makeGradientImage(width: CGFloat = 100, height: CGFloat = 100, startOffset: CGFloat, direction: VariableBlurDirection) -> CGImage {
        let ciGradientFilter = CIFilter.linearGradient()
        ciGradientFilter.color0 = CIColor.black
        ciGradientFilter.color1 = CIColor.clear
        ciGradientFilter.point0 = CGPoint(x: 0, y: height)
        ciGradientFilter.point1 = CGPoint(x: 0, y: startOffset * height)

        if case .blurredBottomClearTop = direction {
            ciGradientFilter.point0.y = 0
            ciGradientFilter.point1.y = height - ciGradientFilter.point1.y
        }

        return CIContext().createCGImage(ciGradientFilter.outputImage!, from: CGRect(x: 0, y: 0, width: width, height: height))!
    }
}
```

### Usage in SwiftUI

```swift
struct RecipeDetailView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Image("recipe-image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                // Your recipe content
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            VariableBlurView(maxBlurRadius: 20, direction: .blurredBottomClearTop)
                .frame(height: 300)
                .ignoresSafeArea()
        }
    }
}
```

The `VariableBlurView` uses a **gradient mask** where alpha values control blur intensity at each pixel—alpha of 1 results in maximum blur, while alpha of 0 is completely unblurred. This creates the smooth progressive effect identical to Apple's implementation.[12][2]

### Important Considerations

While developers have reported successful App Store approvals using this approach, **Apple does not guarantee private API stability**. Using `CAFilter` may result in:[14][12]

- App Store rejection during review[12][14]
- Breaking changes in future iOS updates[2]
- Unexpected behavior across different devices

For production apps, this approach should be used with caution and thorough testing.

## Approach 3: Metal Shader (Production-Safe Alternative)

For apps requiring the exact progressive blur effect without private API risks, implementing a **custom Metal shader** provides full control. The Variablur library demonstrates this approach using 100% public APIs.[15][16][14]

### Benefits

- **100% public API** - No rejection risk[15]
- **Full customization** - Control blur algorithm, gradient shape, and intensity
- **High performance** - GPU-accelerated rendering[15]
- **Future-proof** - Won't break with iOS updates

### Implementation Overview

```swift
// Using Variablur or custom Metal shader
import Variablur

struct RecipeDetailView: View {
    var body: some View {
        Image("recipe")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .variableBlur(mask: { context, size in
                // Draw gradient mask using GraphicsContext
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [.black, .clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }, maxSampleCount: 15)
    }
}
```

Metal shaders provide the smoothest blur with full control over the effect, making them ideal for production apps that need Apple-quality effects without the private API risks.[16][15]

## Approach 4: UIKit Implementation

If you're working with UIKit (for older iOS versions or existing codebases), you can combine `UIVisualEffectView` with `CAGradientLayer`.[17][18][19]

### UIKit Implementation

```swift
class RecipeDetailViewController: UIViewController {
    private let imageView = UIImageView()
    private let contentView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup image view
        imageView.image = UIImage(named: "recipe")
        imageView.contentMode = .scaleAspectFill
        view.addSubview(imageView)

        // Create blur view
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)

        // Add gradient mask
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

        blurView.layer.mask = gradientLayer
        view.addSubview(blurView)

        // Layout constraints
        // ... configure autolayout or frame-based layout
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let gradientLayer = blurView.layer.mask as? CAGradientLayer {
            gradientLayer.frame = blurView.bounds
        }
    }
}
```

This UIKit approach works across **all iOS versions** but produces less smooth transitions compared to the SwiftUI Material approach.[18][17]

## Comparison and Recommendations

| Approach | iOS Version | API Status | Smoothness | Complexity | App Store Risk |
|----------|-------------|------------|------------|------------|----------------|
| **Material + Gradient** | 15+ | Public | Good | Low | None |
| **CAFilter Variable Blur** | 13+ | Private | Excellent | Medium | High |
| **Metal Shader** | 13+ | Public | Excellent | High | None |
| **UIKit + Gradient** | All | Public | Fair | Medium | None |

### For Your Recipe Page App

Based on your use case, I recommend:

1. **Primary choice: SwiftUI Material + Gradient Mask** (Approach 1)
   - Best balance of simplicity, quality, and safety[8][10][7]
   - Perfect for recipe detail pages with text overlays[6]
   - Zero risk of App Store rejection
   - Easy to maintain and customize

2. **Advanced alternative: Metal Shader** (Approach 3)
   - If you need the absolute best quality matching Apple's effect[15]
   - Worth the extra implementation effort for polished apps
   - Still production-safe with public APIs

3. **Avoid: CAFilter approach** (Approach 2)
   - Only use for internal/prototype apps[14][12]
   - Not recommended for production App Store submissions

## Enhancing the Effect

To match the screenshot exactly, combine the blur with additional enhancements:

### Add Darkening Gradient

```swift
.background(
    ZStack {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(gradientMask)

        // Additional darkening for text contrast
        LinearGradient(
            colors: [.black.opacity(0.5), .clear],
            startPoint: .bottom,
            endPoint: .top
        )
    }
)
```

### Adjust Blur Intensity

Experiment with different Material types:[7][8]
- `.ultraThinMaterial` - Lightest blur
- `.thinMaterial` - Light blur
- `.regularMaterial` - Medium blur (good default)
- `.thickMaterial` - Heavy blur
- `.ultraThickMaterial` - Heaviest blur

### Fine-tune Gradient Stops

Control exactly where the blur transition occurs:[11][1]

```swift
LinearGradient(
    gradient: Gradient(stops: [
        .init(color: .clear, location: 0.0),      // No blur at top
        .init(color: .black, location: 0.2),      // Start blur 20% down
        .init(color: .black, location: 1.0)       // Full blur at bottom
    ]),
    startPoint: .top,
    endPoint: .bottom
)
```

## Implementation Best Practices

1. **Test on multiple devices** - Blur effects can vary across iPhone models and screen sizes[2]
2. **Consider performance** - Blur is GPU-intensive; test scrolling and animations[15]
3. **Ensure text contrast** - Add darkening gradients if needed for readability[1][6]
4. **Support Dark Mode** - Materials automatically adapt, but test your content colors[8][7]
5. **Handle dynamic content** - Ensure blur adjusts properly when rotating or resizing[18]

The transitional blur effect significantly enhances recipe presentation by maintaining visual context while ensuring text legibility. Using the recommended SwiftUI Material + Gradient Mask approach provides the best balance of quality, maintainability, and App Store safety for your iOS recipe app.

[1](https://www.reddit.com/r/SwiftUI/comments/o8d8ju/blur_with_gradient_edges/)
[2](https://designcode.io/swiftui-handbook-progressive-blur/)
[3](https://www.linkedin.com/posts/artem-mirzabekian_a-smooth-blurred-overlay-in-swiftui-when-activity-7364272492703612928-UL5I)
[4](https://www.youtube.com/watch?v=EFnUwG22fHk)
[5](https://stackoverflow.com/questions/68138347/swiftui-add-blur-linear-gradient)
[6](https://nilcoalescing.com/blog/BackgroundExtensionEffectInSwiftUI)
[7](https://swiftylion.com/articles/background-blur-with-materials-in-swiftui)
[8](https://swiftwithmajid.com/2021/10/28/blur-effect-and-materials-in-swiftui/)
[9](https://stackoverflow.com/questions/56610957/is-there-a-method-to-blur-a-background-in-swiftui)
[10](https://www.swiftbysundell.com/articles/backgrounds-and-overlays-in-swiftui)
[11](https://designcode.io/swiftui-handbook-mask-and-transparency/)
[12](https://github.com/jtrivedi/VariableBlurView)
[13](https://github.com/nikstar/VariableBlur)
[14](https://www.reddit.com/r/iOSProgramming/comments/1er0xwo/in_ios_how_to_achieve_a_blur_over_a_tableview/)
[15](https://github.com/daprice/Variablur)
[16](https://mastodon.online/@dale_price/111451581231779243)
[17](https://betterprogramming.pub/how-to-present-a-view-controller-with-blurred-background-in-ios-4350017e6073)
[18](https://stackoverflow.com/questions/7506852/gradient-mask-on-uiview)
[19](https://stackoverflow.com/questions/37746877/blurred-or-transparent-bottom-of-image)
[20](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/images/80067365/983ead06-8912-4193-842c-136d7f5898d7/CleanShot-2025-10-21-at-22.12.31-2x.jpg?AWSAccessKeyId=ASIA2F3EMEYEYSWKGUXN&Signature=QNsYwHOU8pKP8ZPPJutcrhmWtwk%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEGMaCXVzLWVhc3QtMSJIMEYCIQCY5pvpMhd0zkdi2tcRmjMIxzgGMbGARHdlrNkdVwWCxwIhAN8fSbYlHko8gLqdzLr7bBqc2EeS05dC5j9hSl5RnKJyKvEECBwQARoMNjk5NzUzMzA5NzA1IgxAeOiFYfoupN2hWG8qzgR%2F9FmOrDXZX6bGK8I1c3J4%2BC0SUU7RO1Khivn6EyQ4f2Pb%2F2bN8V3UreZSYXc3qNQlb2nRohj2Bc5yoaTMEra5wBnyAw1dHRCDUWVRiofmjjpXrMBkTIbrCt6tJrIYHZE0NGl1YMXyTKN3%2Bgw4LZgXRUcKhrJMouI4XjfjXkPI%2FzHxysWE7eS30AueUP0ItyddxCXR5Tn45ndnq1gRJlxO54mUfanHHHN6PszvVOsx8NEdH9G29ajg0k%2FPNk1ELl%2BBaFyCoJtvWiQkWWz1uqTJBZuDzp044iHFawFsvdZcWMqeo0JrfTBK7BsNIQIq6NOwSNdjE2xivhbQPexjwrp9caxV7qfPh5wodtcOQpiG8N%2BitzTTwFqTb0s6KCr11D%2BY8fUN86DxDzl5MkrgjsEdfuuiCsLg6DjQ7YVxmS8WsliNSWZ8cCH8D5FIWbqDAR9vpre9SPN0b%2F2zGa81Ex77OQtQ5rAW94y7cb5TVb16UeDg6jFN0NeXby10AGPeuNSCjdaW1q3dIvCIU3Wkoacp3IzRmpVkOwGJLTh4LJAi%2FJrD6vYjpshQnfFyLXhQR%2Fb%2BUbD5qZg8TmkvdQUKeaAeU2FqOs5WS2uKY%2BnCzED8V%2BHZLC2ouu4l%2F%2B8TUGosHRCJR2aIKG%2F6fG3iCzq2AnVgBCduFZZadrPjKSMJRs0BEMKeWvfXUNnh1Jus49AwQNim1dT35hdSU8WISZPt5rYBRDY2Axou6OSFllo7%2B1ut2cFkoqDcIMRGgzjh7bZUWGEnQGTBHuQpZEcJjCeImDDaqd%2FHBjqZASGS9sQKALKrE7JCvGf52OaEuXdQrhlwXZuY%2FjXprxx2vcqhCuZGKYf3oGmk%2BAglMrN6JiRPIWx%2BFyh0giKiVsdyAYItNUuMqchDjv2ouEQygJl0Yb0MvhgJAtH5yEOZ%2B0tWuYM1gOLrtg5mcc3wrvYa7IFKNKaLMZbNmcD5I2f%2F7ArdbH1%2BQFtGx43wshfQ11EXklzZMkCUtA%3D%3D&Expires=1761074721)
[21](https://developer.apple.com/documentation/coreimage/customizing-image-transitions)
[22](https://support.apple.com/en-sa/guide/iphone/iph310a9a220/ios)
[23](https://stackoverflow.com/questions/63519312/how-to-present-a-blurred-version-of-an-image-in-nextjs-as-its-being-downloaded)
[24](https://developer.mozilla.org/en-US/docs/Web/CSS/filter-function/blur)
[25](https://www.youtube.com/watch?v=AoyU-jsFqmI)
[26](https://github.com/unitedadityaa/SwiftUIGradientBlur)
[27](https://www.youtube.com/watch?v=gnwKWzmVrjY)
[28](https://www.lemon8-app.com/@elyseekb/7396256198817071621?region=us)
[29](https://stackoverflow.com/questions/21354449/apply-a-blur-gradient)
[30](https://stackoverflow.com/questions/19601734/custom-uiviewcontroller-transition-with-blur)
[31](https://www.reddit.com/r/SideProject/comments/1hnwj24/i_created_a_ios_app_that_matches_recipes_by/)
[32](https://www.youtube.com/watch?v=Kca4tHyy_Ow)
[33](https://www.reddit.com/r/SwiftUI/comments/10if97c/any_way_to_achieve_this_gradient_blur_with/)
[34](https://appcircle.io/blog/wwdc25-build-a-uikit-app-with-the-new-liquid-glass-design)
[35](https://stackoverflow.com/questions/78877019/ios-how-to-make-variableblurs-cifilter-darker)
[36](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html)
[37](https://dev.to/nafeezahmed/visual-effects-blur-in-swiftui-4fm9)
[38](https://developer.apple.com/documentation/coreimage/blur-filters)
[39](https://www.threads.com/@nunosans/post/C-kHO62i8Ih?hl=en)
[40](https://developer.apple.com/documentation/swiftui/material/)
[41](https://www.reddit.com/r/SwiftUI/comments/1mriepv/how_to_create_a_gradient_from_an_images_main/)
[42](https://betterprogramming.pub/3-approaches-to-applying-blur-effects-in-ios-c1c941d862c3)
[43](https://www.tiktok.com/@estheruzodinma/video/7388265918494706949)
[44](https://www.youtube.com/watch?v=dUfb8PsC0Qg)
[45](https://tailwindcss.com/docs/mask-image)
[46](https://skylum.com/de/luminar-flex/user-guides/chapter-11-using-a-gradient-mask)
[47](https://livsycode.com/swiftui/creating-a-bottom-blurred-overlay-with-a-smooth-gradient-in-swiftui/)
