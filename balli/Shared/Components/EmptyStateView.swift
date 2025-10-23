//
//  EmptyStateView.swift
//  balli
//
//  Standardized empty state view component
//

import SwiftUI

struct EmptyStateView: View {
    let type: EmptyStateType
    let customTitle: String?
    let customMessage: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    enum EmptyStateType: Equatable {
        case noData
        case noResults
        case noFavorites
        case noHistory
        case noNetwork
        case comingSoon
        case custom(icon: String, color: Color)
        
        static func == (lhs: EmptyStateType, rhs: EmptyStateType) -> Bool {
            switch (lhs, rhs) {
            case (.noData, .noData), (.noResults, .noResults), 
                 (.noFavorites, .noFavorites), (.noHistory, .noHistory),
                 (.noNetwork, .noNetwork), (.comingSoon, .comingSoon):
                return true
            case let (.custom(icon1, color1), .custom(icon2, color2)):
                return icon1 == icon2 && color1 == color2
            default:
                return false
            }
        }
        
        var icon: String {
            switch self {
            case .noData:
                return "doc.text.magnifyingglass"
            case .noResults:
                return "magnifyingglass"
            case .noFavorites:
                return "star.slash"
            case .noHistory:
                return "clock.arrow.circlepath"
            case .noNetwork:
                return "wifi.slash"
            case .comingSoon:
                return "sparkles"
            case .custom(let icon, _):
                return icon
            }
        }
        
        var color: Color {
            switch self {
            case .noData, .noResults:
                return AppTheme.primaryPurple
            case .noFavorites:
                return .yellow
            case .noHistory:
                return .blue
            case .noNetwork:
                return .orange
            case .comingSoon:
                return AppTheme.accentColor
            case .custom(_, let color):
                return color
            }
        }
        
        var defaultTitle: String {
            switch self {
            case .noData:
                return "Henüz Veri Yok"
            case .noResults:
                return "Sonuç Bulunamadı"
            case .noFavorites:
                return "Favori Yok"
            case .noHistory:
                return "Geçmiş Boş"
            case .noNetwork:
                return "Bağlantı Yok"
            case .comingSoon:
                return "Yakında"
            case .custom:
                return "Boş"
            }
        }
        
        var defaultMessage: String {
            switch self {
            case .noData:
                return "Henüz hiç veri eklenmemiş. Yeni veri ekleyerek başlayabilirsiniz."
            case .noResults:
                return "Arama kriterlerinize uygun sonuç bulunamadı. Farklı bir arama yapmayı deneyin."
            case .noFavorites:
                return "Henüz favori eklenmemiş. Beğendiğiniz öğeleri favorilere ekleyin."
            case .noHistory:
                return "Geçmiş kayıtlarınız bulunmuyor. Kullandıkça geçmişiniz oluşacak."
            case .noNetwork:
                return "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
            case .comingSoon:
                return "Bu özellik üzerinde çalışıyoruz. Yakında sizlerle!"
            case .custom:
                return "İçerik bulunmuyor."
            }
        }
    }
    
    init(
        type: EmptyStateType,
        title: String? = nil,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.type = type
        self.customTitle = title
        self.customMessage = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            Spacer()
            
            // Animated Icon
            ZStack {
                // Background circle
                Circle()
                    .fill(type.color.opacity(0.1))
                    .frame(width: ResponsiveDesign.width(120), height: ResponsiveDesign.width(120))
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: ResponsiveDesign.height(50)))
                    .foregroundColor(type.color)
                    .rotationEffect(type == .noHistory ? Angle(degrees: isAnimating ? 360 : 0) : .zero)
                    .animation(
                        type == .noHistory ?
                        .linear(duration: 3).repeatForever(autoreverses: false) :
                        .none,
                        value: isAnimating
                    )
            }
            
            // Title
            Text(customTitle ?? type.defaultTitle)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Message
            Text(customMessage ?? type.defaultMessage)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ResponsiveDesign.Spacing.large)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, ResponsiveDesign.Spacing.large)
                    .padding(.vertical, ResponsiveDesign.Spacing.medium)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primaryPurple, AppTheme.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, ResponsiveDesign.Spacing.small)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Compact Empty State
struct CompactEmptyStateView: View {
    let icon: String
    let message: String
    let color: Color
    
    init(
        icon: String = "info.circle",
        message: String,
        color: Color = AppTheme.primaryPurple
    ) {
        self.icon = icon
        self.message = message
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(color)
            
            Text(message)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(ResponsiveDesign.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.small, style: .continuous))
    }
}

// MARK: - List Empty State
struct ListEmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        icon: String = "list.bullet",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: ResponsiveDesign.height(40)))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.primaryPurple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ResponsiveDesign.Spacing.large)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview("No Data") {
    EmptyStateView(
        type: .noData,
        actionTitle: "Veri Ekle",
        action: { }
    )
}

#Preview("No Favorites") {
    EmptyStateView(
        type: .noFavorites,
        title: "Favori Yemek Yok",
        message: "Sevdiğiniz yemekleri favorilere ekleyerek hızlıca erişebilirsiniz."
    )
}

#Preview("Coming Soon") {
    EmptyStateView(
        type: .comingSoon
    )
}

#Preview("Compact Empty") {
    CompactEmptyStateView(
        icon: "info.circle",
        message: "Henüz kayıt bulunmuyor"
    )
    .padding()
}

#Preview("List Empty") {
    ListEmptyStateView(
        title: "Liste Boş",
        message: "Henüz öğe eklenmemiş",
        actionTitle: "Ekle",
        action: { }
    )
}