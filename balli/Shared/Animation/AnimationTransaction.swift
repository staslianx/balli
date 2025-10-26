//
//  AnimationTransaction.swift
//  balli
//
//  Transaction-based animation management for preventing conflicts
//

import SwiftUI
import Combine
import CoreData
import OSLog

/// Manages animation transactions to prevent conflicts and races
@MainActor
public final class AnimationTransaction: ObservableObject {

    // MARK: - Constants

    private enum Constants {
        static let animationCompletionDelaySeconds: TimeInterval = 0.5
        static let dataUpdateDebounceMilliseconds: Int = 50
    }

    // MARK: - Transaction State
    public enum TransactionState {
        case idle
        case preparing
        case animating
        case completing
    }
    
    // MARK: - Transaction Type
    public enum TransactionType {
        case ui           // Pure UI animations
        case dataUpdate   // Core Data driven animations
        case navigation   // Navigation transitions
        case compound     // Multiple coordinated animations
    }
    
    // MARK: - Properties
    @Published public private(set) var state: TransactionState = .idle
    @Published public private(set) var activeTransactions: Set<UUID> = []
    
    private let logger = AppLoggers.Performance.animation
    private let controller = AnimationController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Core Data integration
    private var pendingDataUpdates: [UUID: () -> Void] = [:]
    private var dataUpdateDebouncer: AnyCancellable?
    
    // MARK: - Singleton
    public static let shared = AnimationTransaction()
    
    private init() {
        setupCoreDataObservers()
    }
    
    // MARK: - Core Data Observers
    private func setupCoreDataObservers() {
        // Observe Core Data save notifications
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCoreDataSave(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleCoreDataSave(_ notification: Notification) {
        // Debounce Core Data updates to batch animations
        dataUpdateDebouncer?.cancel()
        dataUpdateDebouncer = Just(())
            .delay(for: .milliseconds(Constants.dataUpdateDebounceMilliseconds), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.processPendingDataUpdates()
            }
    }
    
    // MARK: - Transaction Management
    
    /// Begin a new animation transaction
    @discardableResult
    public func begin(
        type: TransactionType,
        priority: AnimationController.AnimationPriority = .normal,
        animations: @escaping () -> Void
    ) -> TransactionHandle {
        let id = UUID()
        let handle = TransactionHandle(id: id, transaction: self)
        
        activeTransactions.insert(id)
        state = .preparing
        
        let animationID = AnimationController.AnimationID(
            "transaction-\(id.uuidString)",
            priority: priority
        )
        
        // Register with controller
        controller.beginAnimation(animationID)
        
        // Execute based on type
        switch type {
        case .dataUpdate:
            // Delay for Core Data sync
            pendingDataUpdates[id] = animations
        case .compound:
            // Use transaction for compound animations
            executeCompoundAnimation(animations, id: animationID)
        default:
            // Execute immediately for UI animations
            executeAnimation(animations, id: animationID)
        }
        
        logger.debug("Started transaction: \(id)")
        return handle
    }
    
    /// Execute animation with proper timing
    private func executeAnimation(
        _ animations: @escaping () -> Void,
        id: AnimationController.AnimationID
    ) {
        state = .animating

        withAnimation(controller.animation(for: AnimationPresets.smoothTransition)) {
            animations()
        }

        // Schedule completion
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Constants.animationCompletionDelaySeconds * 1_000_000_000))
            self?.completeAnimation(id: id)
        }
    }
    
    /// Execute compound animations with coordination
    private func executeCompoundAnimation(
        _ animations: @escaping () -> Void,
        id: AnimationController.AnimationID
    ) {
        state = .animating

        // Use SwiftUI transaction for better coordination
        withTransaction(SwiftUI.Transaction(animation: controller.animation(for: AnimationPresets.smoothTransition))) {
            animations()
        }

        // Schedule completion
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Constants.animationCompletionDelaySeconds * 1_000_000_000))
            self?.completeAnimation(id: id)
        }
    }

    /// Complete animation and cleanup
    private func completeAnimation(id: AnimationController.AnimationID) {
        controller.endAnimation(id)
        
        // Extract UUID from animation ID
        let uuidString = id.id.replacingOccurrences(of: "transaction-", with: "")
        if let uuid = UUID(uuidString: uuidString) {
            activeTransactions.remove(uuid)
        }
        
        if activeTransactions.isEmpty {
            state = .idle
        }
        
        logger.debug("Completed animation: \(id.id)")
    }
    
    // MARK: - Data Update Processing
    private func processPendingDataUpdates() {
        guard !pendingDataUpdates.isEmpty else { return }

        logger.debug("Processing \(self.pendingDataUpdates.count) pending data updates")

        // Execute all pending updates together
        withAnimation(controller.animation(for: AnimationPresets.dataUpdate)) {
            self.pendingDataUpdates.values.forEach { update in
                update()
            }
        }
        
        // Clear pending updates
        pendingDataUpdates.removeAll()
    }
    
    // MARK: - Transaction Handle
    public struct TransactionHandle {
        let id: UUID
        weak var transaction: AnimationTransaction?
        
        /// Cancel this transaction
        @MainActor
        public func cancel() {
            transaction?.cancel(id: id)
        }
    }
    
    /// Cancel a transaction
    public func cancel(id: UUID) {
        activeTransactions.remove(id)
        pendingDataUpdates.removeValue(forKey: id)
        
        if activeTransactions.isEmpty {
            state = .idle
        }
        
        logger.debug("Cancelled transaction: \(id)")
    }
    
    // MARK: - Batch Operations
    
    /// Perform multiple animations in a single transaction
    public func batch(
        priority: AnimationController.AnimationPriority = .normal,
        _ animations: @escaping () -> Void
    ) {
        begin(type: .compound, priority: priority, animations: animations)
    }
    
    /// Perform animation only if no other animations are active
    public func performIfIdle(_ animations: @escaping () -> Void) {
        guard activeTransactions.isEmpty else {
            logger.debug("Skipping animation - transactions active")
            return
        }
        
        begin(type: .ui, animations: animations)
    }
    
    /// Delay animation until current transactions complete
    public func performAfterCurrent(_ animations: @escaping () -> Void) {
        if activeTransactions.isEmpty {
            begin(type: .ui, animations: animations)
        } else {
            // Wait for current transactions
            $activeTransactions
                .filter { $0.isEmpty }
                .first()
                .sink { [weak self] _ in
                    self?.begin(type: .ui, animations: animations)
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - SwiftUI Extensions
public extension View {
    /// Animate view changes within a transaction
    func animateWithTransaction<V>(
        _ value: V,
        type: AnimationTransaction.TransactionType = .ui,
        priority: AnimationController.AnimationPriority = .normal,
        animation: Animation? = nil
    ) -> some View where V: Equatable {
        onChange(of: value) { _, _ in
            AnimationTransaction.shared.begin(type: type, priority: priority) {
                // Animation will be applied by transaction
            }
        }
    }
    
    /// Conditionally apply animation based on transaction state
    func animateIfNotBusy<V>(_ value: V) -> some View where V: Equatable {
        animation(
            AnimationTransaction.shared.activeTransactions.isEmpty ? .smoothTransition : nil,
            value: value
        )
    }
}
