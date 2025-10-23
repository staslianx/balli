//
//  DependencyContainer.swift
//  balli
//
//  Dependency injection container for managing app dependencies
//
//  ARCHITECTURE DECISION (2025-10-11):
//  This uses a Service Locator pattern with singleton access, which is APPROPRIATE for a 2-user personal app.
//  For enterprise apps with teams, full DI via constructors would be preferred.
//  For this app, simplicity and maintainability trump "textbook" dependency injection.
//
//  USAGE PATTERNS:
//  1. Environment Injection (Preferred for Views):
//     @Environment(\.dependencies) private var dependencies
//     let service = dependencies.healthKitService
//
//  2. EnvironmentObject (For Observable State):
//     @EnvironmentObject private var dependencies: DependencyContainer
//
//  3. Direct Singleton Access (For Services):
//     let service = DependencyContainer.shared.healthKitService
//
//  CONCURRENCY SAFETY:
//  - Container is @MainActor isolated for thread safety
//  - Services using actors (MemoryService) provide their own isolation
//  - No data race risks for 2-user app with proper actor boundaries
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Dependency Container Protocol
@MainActor
protocol DependencyContainerProtocol {
    var persistenceController: PersistenceController { get }
    var appConfigurationManager: AppConfigurationManager { get }
    var appStateManager: AppLifecycleCoordinator { get }
    var cameraPermissionManager: CameraPermissionHandler { get }
    var captureFlowManager: CaptureFlowManager { get }
    var healthKitService: HealthKitServiceProtocol { get }
    var dexcomService: DexcomService { get }
    var memoryService: MemoryService { get }
}

// MARK: - Main Dependency Container
@MainActor
final class DependencyContainer: ObservableObject, DependencyContainerProtocol {
    static let shared = DependencyContainer()
    
    // Core Services
    lazy var persistenceController: PersistenceController = {
        PersistenceController.shared
    }()
    
    lazy var appConfigurationManager: AppConfigurationManager = {
        AppConfigurationManager.shared
    }()
    
    lazy var appStateManager: AppLifecycleCoordinator = {
        AppLifecycleCoordinator.shared
    }()
    
    // Permission Managers
    lazy var cameraPermissionManager: CameraPermissionHandler = {
        CameraPermissionHandler()
    }()
    
    
    // Health Services
    lazy var healthKitService: HealthKitServiceProtocol = {
        HealthKitService()
    }()

    lazy var dexcomService: DexcomService = {
        DexcomService()
    }()

    // Memory Services
    lazy var memoryService: MemoryService = {
        MemoryService(healthKitService: healthKitService)
    }()

    // Camera Services
    lazy var captureFlowManager: CaptureFlowManager = {
        let cameraManager = CameraManager()
        return CaptureFlowManager(cameraManager: cameraManager)
    }()
    
    // ARCHITECTURAL NOTE: Navigation state should ideally be in AppLifecycleCoordinator or a dedicated NavigationCoordinator
    // Kept here for backward compatibility with existing views
    // Future consideration: Move to NavigationCoordinator when refactoring navigation architecture
    @Published var navigationPath = NavigationPath()
    @Published var selectedTab: TabItem = .hosgeldin
    @Published var showingSheet: SheetType?
    @Published var showingAlert: AlertType?

    // App State - Currently unused for 2-user app (no authentication flow)
    // Kept for future extensibility if auth becomes needed
    @Published var isAuthenticated = false
    @Published var isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    @Published var currentUser: User?
    
    private init() {
        setupDependencies()
    }
    
    private func setupDependencies() {
        // Services are initialized lazily when accessed
    }
}

// MARK: - Navigation Types
enum TabItem: String, CaseIterable {
    case ardiye = "ardiye"
    case hosgeldin = "hosgeldin"
    
    var title: String {
        switch self {
        case .ardiye:
            return "Ardiye"
        case .hosgeldin:
            return "Hoşgeldin"
        }
    }
    
    var icon: String {
        switch self {
        case .ardiye:
            return "archivebox.fill"
        case .hosgeldin:
            return "house.fill"
        }
    }
}

enum SheetType: Identifiable {
    case camera
    case manualEntry
    case recipe
    case foodDetail(FoodItem)
    case profile
    case settings
    
    var id: String {
        switch self {
        case .camera:
            return "camera"
        case .manualEntry:
            return "manualEntry"
        case .recipe:
            return "recipe"
        case .foodDetail(let item):
            return "foodDetail_\(item.objectID)"
        case .profile:
            return "profile"
        case .settings:
            return "settings"
        }
    }
}

enum AlertType: Identifiable {
    case error(Error)
    case success(String)
    case confirmation(title: String, message: String, action: () -> Void)
    case custom(title: String, message: String)
    
    var id: String {
        switch self {
        case .error(let error):
            return "error_\(error.localizedDescription)"
        case .success(let message):
            return "success_\(message)"
        case .confirmation(let title, _, _):
            return "confirmation_\(title)"
        case .custom(let title, _):
            return "custom_\(title)"
        }
    }
}

// MARK: - User Model (Placeholder)
struct User: Identifiable, Codable {
    let id: UUID
    let name: String
    let email: String
    let diabetesType: String
    let createdAt: Date
}

// MARK: - Environment Key
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer? = nil
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { 
            if let container = self[DependencyContainerKey.self] {
                return container
            }
            return MainActor.assumeIsolated {
                DependencyContainer.shared
            }
        }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Modifier for Injection
struct InjectDependencies: ViewModifier {
    // Use ObservedObject (not StateObject) since container is a singleton with external lifecycle
    @ObservedObject private var container = DependencyContainer.shared

    func body(content: Content) -> some View {
        content
            // Provide both access patterns for flexibility
            .environmentObject(container)  // For @EnvironmentObject access
            .environment(\.dependencies, container)  // For @Environment(\.dependencies) access
            .environment(\.managedObjectContext, container.persistenceController.viewContext)
    }
}

extension View {
    func injectDependencies() -> some View {
        modifier(InjectDependencies())
    }
}

// MARK: - Alternative Service Locator (Generic Pattern)
// This is provided as an alternative pattern but NOT CURRENTLY USED
// DependencyContainer (above) is the primary DI mechanism for this app
// Kept for reference if dynamic service registration becomes needed
@globalActor actor ServiceLocatorActor {
    static let shared = ServiceLocatorActor()
}

final class ServiceLocator: @unchecked Sendable {
    static let shared = ServiceLocator()

    private var services: [String: Any] = [:]

    private init() {}

    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }

    func resolve<T>(_ type: T.Type, default defaultValue: T) -> T {
        resolve(type) ?? defaultValue
    }
}

// MARK: - Factory Pattern for ViewModels
@MainActor
protocol ViewModelFactory {
    associatedtype ViewModel
    static func create(with dependencies: DependencyContainer) -> ViewModel
}

// Example ViewModel Factory
@MainActor
struct HomeViewModelFactory: ViewModelFactory {
    static func create(with dependencies: DependencyContainer) -> HomeViewModel {
        HomeViewModel(
            persistenceController: dependencies.persistenceController
        )
    }
}

// MARK: - Example ViewModel
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var glucoseReadings: [GlucoseReading] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    func loadData() {
        // Implementation
    }
}