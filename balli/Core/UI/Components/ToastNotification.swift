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
            return .green
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
                .font(.title3)
                .foregroundStyle(type.color)

            Text(type.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after duration
            Task {
                try? await Task.sleep(nanoseconds: UInt64(displayDuration * 1_000_000_000))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        ZStack(alignment: .top) {
            content

            if let toast = toast, isShowing {
                ToastNotification(type: toast, isShowing: $isShowing)
                    .padding(.top, 8)
                    .zIndex(1000)
                    .onChange(of: isShowing) { oldValue, newValue in
                        if !newValue {
                            // Clear toast when dismissed
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 300_000_000) // Wait for animation
                                self.toast = nil
                            }
                        }
                    }
            }
        }
        .onChange(of: toast) { oldValue, newValue in
            if newValue != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                toast.wrappedValue = .error(error.localizedDescription ?? "Kaydetme hatası")
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
