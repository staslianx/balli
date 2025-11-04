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
    // Core Services
    var persistenceController: PersistenceController { get }
    var appConfigurationManager: AppConfigurationManager { get }
    var appStateManager: AppLifecycleCoordinator { get }

    // Permission Managers
    var cameraPermissionManager: CameraPermissionHandler { get }

    // Camera Services
    var captureFlowManager: CaptureFlowManager { get }

    // Health Services
    var healthKitService: HealthKitServiceProtocol { get }
    var dexcomService: DexcomService { get }

    // Memory Services
    var memoryService: MemoryService { get }

    // PHASE 0 - New Protocol-Based Services
    var mealReminderManager: MealReminderManagerProtocol { get }
    var localAuthenticationManager: LocalAuthenticationManagerProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var keychainStorageService: KeychainStorageServiceProtocol { get }

    // PHASE 1 - Recipe Services
    var recipeGenerationService: RecipeGenerationServiceProtocol { get }
    var recipeSyncCoordinator: RecipeSyncCoordinatorProtocol { get }
    var mealSyncCoordinator: MealSyncCoordinatorProtocol { get }
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
        DexcomService.shared
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

    // MARK: - PHASE 0: Protocol-Based Services

    /// Meal reminder notification manager
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var mealReminderManager: MealReminderManagerProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to: MealReminderManager()
        MealReminderManager.shared
    }()

    /// Local authentication manager for user sign-in
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var localAuthenticationManager: LocalAuthenticationManagerProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to: LocalAuthenticationManager()
        LocalAuthenticationManager.shared
    }()

    /// Analytics service for tracking events and metrics
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var analyticsService: AnalyticsServiceProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to creating new instance with dependencies
        AnalyticsService.shared
    }()

    /// Keychain storage service for secure data persistence
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var keychainStorageService: KeychainStorageServiceProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to: KeychainStorageService()
        KeychainStorageService.shared
    }()

    // MARK: - PHASE 1: Recipe Services

    /// Recipe generation service for AI-powered recipe creation
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var recipeGenerationService: RecipeGenerationServiceProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to creating new instance when all usages are updated
        RecipeGenerationService.shared
    }()

    /// Recipe synchronization coordinator for CoreData ↔ Firestore sync
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var recipeSyncCoordinator: RecipeSyncCoordinatorProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to creating new instance when all usages are updated
        RecipeSyncCoordinator.shared
    }()

    /// Meal synchronization coordinator for CoreData ↔ Firestore sync
    /// - Note: Returns protocol type to enable dependency injection and testing
    lazy var mealSyncCoordinator: MealSyncCoordinatorProtocol = {
        // TEMPORARY: Still uses singleton for backward compatibility
        // Phase 1 will convert this to creating new instance when all usages are updated
        MealSyncCoordinator.shared
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

// MARK: - Testing and Preview Support
@MainActor
extension DependencyContainer {
    /// Create a preview container with mock services for SwiftUI previews
    /// - Returns: DependencyContainer configured for preview/testing
    static func preview() -> DependencyContainer {
        let container = DependencyContainer()
        // Services are lazily initialized with real implementations by default
        // Tests can override by creating a new container and replacing properties
        return container
    }

    /// Create a test container with all mock services
    /// - Returns: DependencyContainer configured with mocks for testing
    static func test() -> DependencyContainer {
        let container = DependencyContainer()
        // Note: Individual test files should create their own mocks
        // This is just a convenience for getting a fresh container
        return container
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