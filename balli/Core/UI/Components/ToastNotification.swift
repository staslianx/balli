//
//  ToastNotification.swift
//  balli
//
//  Reusable toast notification for success/error feedback
//

import SwiftUI

/// Toast notification types
enum ToastType: Equatable {
    case success(String)
    case error(String)

    var message: String {
        switch self {
        case .success(let msg), .error(let msg):
            return msg
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success:
            return ThemeColors.primaryPurple
        case .error:
            return .red
        }
    }
}

/// Toast notification view with auto-dismiss
struct ToastNotification: View {
    let type: ToastType
    @Binding var isShowing: Bool

    private let displayDuration: TimeInterval = 1.5

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20))
                .foregroundColor(type.color)

            Text(type.message)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .recipeGlass(tint: .warm, cornerRadius: 100)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        )
        .onAppear {
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            switch type {
            case .success:
                generator.notificationOccurred(.success)
            case .error:
                generator.notificationOccurred(.error)
            }

            // Auto-dismiss after duration
            Task {
                try? await Task.sleep(nanoseconds: UInt64(displayDuration * 1_000_000_000))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) {
                    isShowing = false
                }
            }
        }
    }
}

/// View modifier for easy toast integration
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastType?

    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast, isShowing {
                    ToastNotification(type: toast, isShowing: $isShowing)
                        .padding(.top, 8) // Small padding below Dynamic Island
                        .onChange(of: isShowing) { oldValue, newValue in
                            if !newValue {
                                // Clear toast when dismissed
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 350_000_000) // Wait for animation
                                    self.toast = nil
                                }
                            }
                        }
                }
            }
            .onChange(of: toast) { oldValue, newValue in
                if newValue != nil {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) {
                        isShowing = true
                    }
                }
            }
    }
}

extension View {
    /// Add toast notification capability to any view
    /// - Parameter toast: Binding to optional ToastType
    /// - Returns: View with toast overlay
    func toast(_ toast: Binding<ToastType?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Show success toast with "Kaydedildi" message
    func showSavedToast(_ toast: Binding<ToastType?>) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .persistenceSaveSuccess)) { _ in
            toast.wrappedValue = .success("Kaydedildi")
        }
    }

    /// Show error toast on save failure
    func showSaveErrorToast(_ toast: Binding<ToastType?>) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .persistenceSaveFailure)) { notification in
            if let error = notification.userInfo?["error"] as? PersistenceError {
                toast.wrappedValue = .error(error.localizedDescription)
            } else {
                toast.wrappedValue = .error("Kaydetme hatası")
            }
        }
    }
}

// MARK: - Previews

#Preview("Success Toast") {
    @Previewable @State var toast: ToastType? = .success("Kaydedildi")

    VStack {
        Spacer()
        Button("Show Toast") {
            toast = .success("Kaydedildi")
        }
        Spacer()
    }
    .toast($toast)
}

#Preview("Error Toast") {
    @Previewable @State var toast: ToastType? = .error("Kaydetme başarısız oldu")

    VStack {
        Spacer()
        Button("Show Error") {
            toast = .error("Kaydetme başarısız oldu")
        }
        Spacer()
    }
    .toast($toast)
}
