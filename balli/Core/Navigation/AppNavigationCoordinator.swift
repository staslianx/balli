//
//  AppNavigationCoordinator.swift
//  balli
//
//  App navigation state coordination with deep linking support
//

import SwiftUI
import CoreData
import Combine

// MARK: - Navigation Destination
enum NavigationDestination: Hashable {
    case home
    case foodDetail(id: String)
    case glucoseEntry
    case mealEntry
    case scanResult(id: String)
    case profile
    case settings
    case onboarding
    
    var path: String {
        switch self {
        case .home:
            return "/home"
        case .foodDetail(let id):
            return "/food/\(id)"
        case .glucoseEntry:
            return "/glucose/new"
        case .mealEntry:
            return "/meal/new"
        case .scanResult(let id):
            return "/scan/\(id)"
        case .profile:
            return "/profile"
        case .settings:
            return "/settings"
        case .onboarding:
            return "/onboarding"
        }
    }
    
    static func from(path: String) -> NavigationDestination? {
        let components = path.split(separator: "/").map(String.init)
        
        guard !components.isEmpty else { return .home }
        
        switch components[0] {
        case "home":
            return .home
        case "food":
            if components.count > 1 {
                return .foodDetail(id: components[1])
            }
        case "glucose":
            if components.count > 1 && components[1] == "new" {
                return .glucoseEntry
            }
        case "meal":
            if components.count > 1 && components[1] == "new" {
                return .mealEntry
            }
        case "scan":
            if components.count > 1 {
                return .scanResult(id: components[1])
            }
        case "profile":
            return .profile
        case "settings":
            return .settings
        case "onboarding":
            return .onboarding
        default:
            break
        }
        
        return nil
    }
}

// MARK: - App Navigation Coordinator
@MainActor
final class AppNavigationCoordinator: ObservableObject {
    static let shared = AppNavigationCoordinator()
    
    @Published var navigationPath = NavigationPath()
    @Published var selectedTab: TabItem = .hosgeldin
    @Published var presentedSheet: SheetType?
    @Published var presentedAlert: AlertType?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupDeepLinking()
    }
    
    // MARK: - Navigation Methods
    
    func navigate(to destination: NavigationDestination) {
        navigationPath.append(destination)
    }
    
    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func popToRoot() {
        navigationPath = NavigationPath()
    }
    
    func present(sheet: SheetType) {
        presentedSheet = sheet
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    func show(alert: AlertType) {
        presentedAlert = alert
    }
    
    func dismissAlert() {
        presentedAlert = nil
    }
    
    func switchTab(to tab: TabItem) {
        selectedTab = tab
        popToRoot() // Clear navigation stack when switching tabs
    }
    
    // MARK: - Deep Linking
    
    private func setupDeepLinking() {
        NotificationCenter.default.publisher(for: .handleDeepLink)
            .compactMap { $0.object as? URL }
            .sink { [weak self] url in
                self?.handleDeepLink(url)
            }
            .store(in: &cancellables)
    }
    
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        // Expected format: balli://[path]
        // Examples:
        // balli://food/123
        // balli://glucose/new
        // balli://settings
        
        let path = components.path
        
        if let destination = NavigationDestination.from(path: path) {
            // Check if we need to switch tabs first
            switch destination {
            case .home, .foodDetail, .scanResult:
                switchTab(to: .hosgeldin)
            case .glucoseEntry, .mealEntry:
                switchTab(to: .hosgeldin)
                // These might open as sheets
                if destination == .glucoseEntry {
                    present(sheet: .manualEntry)
                } else if destination == .mealEntry {
                    present(sheet: .recipe)
                }
                return
            case .profile, .settings:
                present(sheet: destination == .profile ? .profile : .settings)
                return
            case .onboarding:
                // Special handling for onboarding
                break
            }
            
            // Navigate to the destination
            navigate(to: destination)
        }
        
        // Handle query parameters if needed
        if let queryItems = components.queryItems {
            handleQueryParameters(queryItems, for: path)
        }
    }
    
    private func handleQueryParameters(_ queryItems: [URLQueryItem], for path: String) {
        // Process any query parameters
        // Example: balli://food/123?action=edit
        for item in queryItems {
            switch item.name {
            case "action":
                if let value = item.value {
                    handleAction(value, for: path)
                }
            default:
                break
            }
        }
    }
    
    private func handleAction(_ action: String, for path: String) {
        // Handle specific actions
        switch action {
        case "edit":
            // Open in edit mode
            break
        case "share":
            // Open share sheet
            break
        default:
            break
        }
    }
    
    // MARK: - State Preservation
    
    func saveNavigationState() {
        // Save current navigation state for restoration
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(selectedTab.rawValue) {
            UserDefaults.standard.set(encoded, forKey: "selectedTab")
        }
        
        // Save navigation path if needed
        // This requires making NavigationDestination Codable
    }
    
    func restoreNavigationState() {
        // Restore saved navigation state
        if let data = UserDefaults.standard.data(forKey: "selectedTab"),
           let tabRawValue = try? JSONDecoder().decode(String.self, from: data),
           let tab = TabItem(rawValue: tabRawValue) {
            selectedTab = tab
        }
    }
}

// MARK: - Navigation Modifier
struct NavigationHandler: ViewModifier {
    @ObservedObject private var navigationManager = AppNavigationCoordinator.shared
    @Environment(\.managedObjectContext) private var viewContext

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
            .sheet(item: $navigationManager.presentedSheet) { sheet in
                sheetView(for: sheet)
            }
            .alert(item: $navigationManager.presentedAlert) { alert in
                alertView(for: alert)
            }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .home:
            UnifiedDashboardView(variant: .today, viewContext: viewContext)
        case .foodDetail(let id):
            // FoodDetailView(foodId: id)
            Text("Food Detail: \(id)")
        case .glucoseEntry:
            // GlucoseEntryView()
            Text("Glucose Entry")
        case .mealEntry:
            // MealEntryView()
            Text("Meal Entry")
        case .scanResult(let id):
            // ScanResultView(scanId: id)
            Text("Scan Result: \(id)")
        case .profile:
            // ProfileView()
            Text("Profile")
        case .settings:
            // SettingsView()
            Text("Settings")
        case .onboarding:
            // OnboardingView()
            Text("Onboarding")
        }
    }
    
    @ViewBuilder
    private func sheetView(for sheet: SheetType) -> some View {
        switch sheet {
        case .camera:
            CameraView()
        case .manualEntry:
            ManualEntryView()
        case .recipe:
            RecipePlaceholderView()
        case .foodDetail(let item):
            // FoodDetailView(food: item)
            Text("Food: \(item.name)")
        case .profile:
            // ProfileView()
            Text("Profile")
        case .settings:
            // SettingsView()
            Text("Settings")
        }
    }
    
    private func alertView(for alertType: AlertType) -> Alert {
        switch alertType {
        case .error(let error):
            return Alert(
                title: Text("Hata"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("Tamam"))
            )
        case .success(let message):
            return Alert(
                title: Text("Başarılı"),
                message: Text(message),
                dismissButton: .default(Text("Tamam"))
            )
        case .confirmation(let title, let message, let action):
            return Alert(
                title: Text(title),
                message: Text(message),
                primaryButton: .default(Text("Evet"), action: action),
                secondaryButton: .cancel(Text("İptal"))
            )
        case .custom(let title, let message):
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }
}

// MARK: - View Extension
extension View {
    func withNavigation() -> some View {
        modifier(NavigationHandler())
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let handleDeepLink = Notification.Name("handleDeepLink")
}