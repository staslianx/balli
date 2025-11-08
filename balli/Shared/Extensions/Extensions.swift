//
//  Extensions.swift
//  balli
//
//  SwiftUI and Foundation extensions for common functionality
//

import SwiftUI
import Foundation

// MARK: - View Extensions
extension View {
    /// Hides the view based on a condition
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
    
    /// Makes the view visible based on a condition
    @ViewBuilder
    func visible(_ shouldShow: Bool) -> some View {
        if shouldShow {
            self
        } else {
            self.hidden()
        }
    }
    
    /// Embeds the view in a navigation stack
    func embedInNavigationStack() -> some View {
        NavigationStack {
            self
        }
    }
    
    /// Adds a border with rounded corners
    func roundedBorder(
        _ color: Color = AppTheme.primaryPurple,
        width: CGFloat = 1,
        cornerRadius: CGFloat = ResponsiveDesign.CornerRadius.medium
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color, lineWidth: width)
        )
    }
    
    /// Measures the size of the view
    func measureSize(perform action: @escaping (CGSize) -> Void) -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SizePreferenceKey.self,
                    value: geometry.size
                )
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: action)
    }
    
    /// Adds a tap gesture with haptic feedback
    func onTapWithFeedback(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        perform action: @escaping () -> Void
    ) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
            action()
        }
    }

    /// Conditionally applies a view modifier
    @ViewBuilder
    func conditionalModifier<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Animates view appearance
    func animateAppearance(
        duration: Double = 0.3,
        delay: Double = 0,
        animation: Animation = .easeInOut
    ) -> some View {
        self.modifier(AnimateAppearanceModifier(duration: duration, delay: delay, animation: animation))
    }
}

struct AnimateAppearanceModifier: ViewModifier {
    let duration: Double
    let delay: Double
    let animation: Animation
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(animation.delay(delay)) {
                    opacity = 1
                }
            }
    }
}

// MARK: - Color Extensions
extension Color {
    
    /// Returns a darker version of the color
    func darker(by percentage: Double = 0.3) -> Color {
        return self.adjust(by: -abs(percentage))
    }
    
    /// Returns a lighter version of the color
    func lighter(by percentage: Double = 0.3) -> Color {
        return self.adjust(by: abs(percentage))
    }
    
    private func adjust(by percentage: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: min(max(r + percentage, 0), 1),
            green: min(max(g + percentage, 0), 1),
            blue: min(max(b + percentage, 0), 1),
            opacity: Double(a)
        )
    }
}

// MARK: - String Extensions
extension String {
    /// Localizes the string
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// Checks if string is a valid email
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
    
    /// Trims whitespace and newlines
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Returns nil if string is empty
    var nilIfEmpty: String? {
        self.trimmed.isEmpty ? nil : self
    }
}

// MARK: - Date Extensions
extension Date {
    /// Formats date to string
    func formatted(as format: String = "dd/MM/yyyy") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: self)
    }
    
    /// Returns time ago string (e.g., "2 saat önce")
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Checks if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Checks if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Start of day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// End of day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}

// MARK: - Double Extensions
extension Double {
    /// Rounds to specified decimal places
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    /// Formats as currency
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "₺0.00"
    }
    
    /// Formats as percentage
    var asPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
}

// MARK: - Array Extensions
extension Array {
    /// Safe subscript
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// Chunks array into smaller arrays
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Binding Extensions
extension Binding {
    /// Creates a binding with a custom getter and setter
    /// Note: Closures must be @Sendable for Swift 6 strict concurrency
    init(get: @escaping @Sendable () -> Value, set: @escaping @Sendable (Value) -> Void) {
        self.init(
            get: get,
            set: { newValue, transaction in
                set(newValue)
            }
        )
    }

    // Note: Binding.map() removed due to Swift 6 Sendable issues
    // Binding itself is not @Sendable, making it impossible to create a conforming map function
    // If needed in the future, use SwiftUI's projectedValue or create custom Sendable wrapper types
}

// MARK: - Image Extensions
extension Image {
    /// Resizes image to fit or fill
    func resized(to size: CGSize, contentMode: ContentMode = .fit) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: size.width, height: size.height)
    }
    
    /// Makes image circular
    func circular(size: CGFloat) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

// MARK: - PreferenceKey for Size
struct SizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Environment Values
extension EnvironmentValues {
    /// Custom dismiss action  
    var customDismiss: @Sendable () -> Void {
        get { self[CustomDismissKey.self] }
        set { self[CustomDismissKey.self] = newValue }
    }
}

private struct CustomDismissKey: EnvironmentKey {
    static let defaultValue: @Sendable () -> Void = { }
}

// MARK: - Animation Extensions
extension Animation {
    static let balliSpring = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2)
    static let balliEaseIn = Animation.easeIn(duration: 0.3)
    static let balliEaseOut = Animation.easeOut(duration: 0.3)
    static let balliBounce = Animation.interpolatingSpring(stiffness: 300, damping: 15)
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let balliUserLoggedIn = Notification.Name("balliUserLoggedIn")
    static let balliUserLoggedOut = Notification.Name("balliUserLoggedOut")
    static let balliDataUpdated = Notification.Name("balliDataUpdated")
    static let balliNetworkStatusChanged = Notification.Name("balliNetworkStatusChanged")
}