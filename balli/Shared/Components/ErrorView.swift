//
//  ErrorView.swift
//  balli
//
//  Standardized error view component
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    init(
        error: Error,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    private var errorIcon: String {
        if error is LocalNetworkError {
            return "wifi.exclamationmark"
        } else if error is UIValidationError {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var errorTitle: String {
        if error is LocalNetworkError {
            return "Bağlantı Hatası"
        } else if error is UIValidationError {
            return "Doğrulama Hatası"
        } else {
            return "Bir Hata Oluştu"
        }
    }
    
    private var errorColor: Color {
        if error is LocalNetworkError {
            return .orange
        } else if error is UIValidationError {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            // Error Icon
            Image(systemName: errorIcon)
                .font(.system(size: ResponsiveDesign.height(60)))
                .foregroundColor(errorColor)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Error Title
            Text(errorTitle)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Error Message
            Text(error.localizedDescription)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action Buttons
            VStack(spacing: ResponsiveDesign.Spacing.small) {
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Tekrar Dene")
                        }
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ResponsiveDesign.Spacing.medium)
                        .background(AppTheme.primaryPurple)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                if let dismissAction = dismissAction {
                    Button(action: dismissAction) {
                        Text("Kapat")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.primaryPurple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ResponsiveDesign.Spacing.medium)
                            .background(
                                Capsule()
                                    .stroke(AppTheme.primaryPurple, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
            .padding(.top, ResponsiveDesign.Spacing.medium)
        }
        .padding(.vertical, ResponsiveDesign.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Error Types
enum LocalNetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
        case .timeout:
            return "İstek zaman aşımına uğradı. Lütfen tekrar deneyin."
        case .serverError(let code):
            return "Sunucu hatası (\(code)). Lütfen daha sonra tekrar deneyin."
        case .unknown:
            return "Bilinmeyen bir ağ hatası oluştu."
        }
    }
}

enum UIValidationError: LocalizedError {
    case emptyField(String)
    case invalidFormat(String)
    case outOfRange(String, min: Double, max: Double)
    
    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field) alanı boş bırakılamaz."
        case .invalidFormat(let field):
            return "\(field) formatı geçersiz."
        case .outOfRange(let field, let min, let max):
            return "\(field) değeri \(Int(min)) ile \(Int(max)) arasında olmalıdır."
        }
    }
}

// MARK: - Compact Error View
struct CompactErrorView: View {
    let message: String
    let icon: String
    let color: Color
    let dismissAction: (() -> Void)?
    
    init(
        message: String,
        icon: String = "exclamationmark.circle.fill",
        color: Color = .red,
        dismissAction: (() -> Void)? = nil
    ) {
        self.message = message
        self.icon = icon
        self.color = color
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 17, weight: .regular, design: .rounded))
            
            Text(message)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            if let dismissAction = dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ResponsiveDesign.Spacing.small)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small, style: .continuous))
    }
}

// MARK: - Preview
#Preview("Error View") {
    ErrorView(
        error: LocalNetworkError.noConnection,
        retryAction: { },
        dismissAction: { }
    )
}

#Preview("Compact Error") {
    CompactErrorView(
        message: "Bir hata oluştu",
        dismissAction: { }
    )
    .padding()
}