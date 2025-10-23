//
//  WindowAccessor.swift
//  balli
//
//  SwiftUI-native window access for iOS 26
//  Provides environment-based window access for APIs requiring UIWindow
//  Swift 6 strict concurrency compliant
//
//  JUSTIFICATION FOR UIKIT USAGE:
//  iOS 26 SwiftUI does not provide direct access to UIWindow, which is required
//  by certain Apple APIs like ASWebAuthenticationSession (OAuth flows).
//  This minimal UIViewRepresentable bridge captures the window and exposes it
//  through SwiftUI's environment system, following Apple's recommended pattern.
//
//  This is NOT legacy code - it's a necessary bridge for APIs that require
//  UIWindow as presentation anchor. Used exclusively for Dexcom OAuth authentication.
//

import SwiftUI
import UIKit
import OSLog

// MARK: - Window Environment Key

/// Environment key for accessing the current window
private struct WindowKey: EnvironmentKey {
    static let defaultValue: UIWindow? = nil
}

extension EnvironmentValues {
    /// Access the current window from the SwiftUI environment
    ///
    /// Usage:
    /// ```swift
    /// @Environment(\.window) private var window
    /// ```
    var window: UIWindow? {
        get { self[WindowKey.self] }
        set { self[WindowKey.self] = newValue }
    }
}

// MARK: - Window Accessor View Modifier

/// View modifier that captures the hosting window and injects it into the environment
///
/// This provides SwiftUI views with access to the UIWindow for APIs that require it,
/// such as ASWebAuthenticationSession, while keeping UIKit usage minimal and well-abstracted.
private struct WindowAccessorModifier: ViewModifier {
    @State private var window: UIWindow?

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessorView { capturedWindow in
                    // Only update if we actually got a window
                    if capturedWindow != nil {
                        self.window = capturedWindow
                        AppLoggers.UI.rendering.debug("✅ Window captured successfully: \(capturedWindow.debugDescription)")
                    } else {
                        AppLoggers.UI.rendering.warning("⚠️ WindowAccessorView called but window is nil")
                    }
                }
                .frame(width: 0, height: 0)
                .hidden()
            )
            .environment(\.window, window)
            .onAppear {
                if window == nil {
                    AppLoggers.UI.rendering.warning("⚠️ WindowAccessorModifier appeared but window is still nil")
                } else {
                    AppLoggers.UI.rendering.debug("✅ WindowAccessorModifier appeared with window: \(window.debugDescription)")
                }
            }
    }
}

/// Internal view that captures the window through UIKit bridge
private struct WindowAccessorView: UIViewRepresentable {
    let onWindowUpdate: (UIWindow?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = WindowCaptureView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.onWindowChange = onWindowUpdate
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Capture the window immediately if available
        if let window = uiView.window {
            onWindowUpdate(window)
        }
    }
}

/// Custom UIView that captures window changes
private class WindowCaptureView: UIView {
    var onWindowChange: ((UIWindow?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Immediately notify when added to a window
        onWindowChange?(window)
    }
}

// MARK: - View Extension

extension View {
    /// Captures the hosting window and makes it available in the SwiftUI environment
    ///
    /// Apply this modifier to your root view or navigation stack to enable window access
    /// throughout the view hierarchy.
    ///
    /// Example:
    /// ```swift
    /// NavigationStack {
    ///     MyView()
    /// }
    /// .captureWindow()
    /// ```
    ///
    /// Then access the window in child views:
    /// ```swift
    /// @Environment(\.window) private var window
    /// ```
    func captureWindow() -> some View {
        modifier(WindowAccessorModifier())
    }
}