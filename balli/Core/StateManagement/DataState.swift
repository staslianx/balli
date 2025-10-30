//
//  DataState.swift
//  balli
//
//  Food, meals, and glucose data state management
//

import SwiftUI
import Combine
import CoreData
import OSLog

// MARK: - Data State Manager
@MainActor
final class DataState: ObservableObject {
    static let shared = DataState()

    // MARK: - Published Properties
    @Published var recentFoodItems: [FoodItem] = []
    @Published var favoriteFoodItems: [FoodItem] = []
    @Published var todaysMeals: [MealEntry] = []
    @Published var glucoseReadings: [GlucoseReading] = []

    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
        loadInitialData()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Data update observer
        NotificationCenter.default.publisher(for: .balliDataUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    private func loadInitialData() {
        refreshData()
    }

    // MARK: - Data Methods

    func refreshData() {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadRecentFoodItems() }
                group.addTask { await self.loadFavoriteFoodItems() }
                group.addTask { await self.loadTodaysMeals() }
                group.addTask { await self.loadGlucoseReadings() }
            }
        }
    }

    @MainActor
    private func loadRecentFoodItems() async {
        do {
            let objectIDs = try await persistenceController.performBackgroundTask { context -> [NSManagedObjectID] in
                let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.lastUsed, ascending: false)]
                request.fetchLimit = 10
                let results = try context.fetch(request)
                return results.map { $0.objectID }
            }

            let viewContext = persistenceController.container.viewContext
            let items: [FoodItem] = await viewContext.perform {
                objectIDs.compactMap { objectID in
                    (try? viewContext.existingObject(with: objectID)) as? FoodItem
                }
            }

            recentFoodItems = items
        } catch {
            ErrorHandler.shared.handle(error)
        }
    }

    @MainActor
    private func loadFavoriteFoodItems() async {
        do {
            let objectIDs = try await persistenceController.performBackgroundTask { context -> [NSManagedObjectID] in
                let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
                request.predicate = NSPredicate(format: "isFavorite == YES")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \FoodItem.name, ascending: true)]
                let results = try context.fetch(request)
                return results.map { $0.objectID }
            }

            let viewContext = persistenceController.container.viewContext
            let items: [FoodItem] = await viewContext.perform {
                objectIDs.compactMap { objectID in
                    (try? viewContext.existingObject(with: objectID)) as? FoodItem
                }
            }

            favoriteFoodItems = items
        } catch {
            ErrorHandler.shared.handle(error)
        }
    }

    @MainActor
    private func loadTodaysMeals() async {
        do {
            let objectIDs = try await persistenceController.performBackgroundTask { context -> [NSManagedObjectID] in
                let request: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: Date())
                guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                    return []
                }

                request.predicate = NSPredicate(
                    format: "timestamp >= %@ AND timestamp < %@",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                )
                request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntry.timestamp, ascending: true)]
                let results = try context.fetch(request)
                return results.map { $0.objectID }
            }

            let viewContext = persistenceController.container.viewContext
            let items: [MealEntry] = await viewContext.perform {
                objectIDs.compactMap { objectID in
                    (try? viewContext.existingObject(with: objectID)) as? MealEntry
                }
            }

            todaysMeals = items
        } catch {
            ErrorHandler.shared.handle(error)
        }
    }

    @MainActor
    private func loadGlucoseReadings() async {
        do {
            let objectIDs = try await persistenceController.performBackgroundTask { context -> [NSManagedObjectID] in
                let request: NSFetchRequest<GlucoseReading> = GlucoseReading.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \GlucoseReading.timestamp, ascending: false)]
                request.fetchLimit = 50
                let results = try context.fetch(request)
                return results.map { $0.objectID }
            }

            let viewContext = persistenceController.container.viewContext
            let readings: [GlucoseReading] = await viewContext.perform {
                objectIDs.compactMap { objectID in
                    (try? viewContext.existingObject(with: objectID)) as? GlucoseReading
                }
            }

            glucoseReadings = readings
        } catch {
            ErrorHandler.shared.handle(error)
        }
    }
}

// MARK: - Environment Key
private struct DataStateKey: EnvironmentKey {
    static let defaultValue: DataState? = nil
}

extension EnvironmentValues {
    var dataState: DataState {
        get {
            if let state = self[DataStateKey.self] {
                return state
            }
            return MainActor.assumeIsolated {
                DataState.shared
            }
        }
        set { self[DataStateKey.self] = newValue }
    }
}
