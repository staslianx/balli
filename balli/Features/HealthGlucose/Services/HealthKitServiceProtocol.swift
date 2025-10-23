//
//  HealthKitServiceProtocol.swift
//  balli
//
//  HealthKit service interface for future implementation
//  Swift 6 strict concurrency compliant
//

import Foundation
@preconcurrency import HealthKit

// MARK: - HealthKit Service Protocol

protocol HealthKitServiceProtocol: Actor {
    /// Request authorization for HealthKit data types
    func requestAuthorization() async throws -> Bool
    
    /// Check if HealthKit is available and authorized for a specific type (defaults to glucose)
    func isAuthorized(for type: HKQuantityType?) async -> Bool
    
    /// Retrieve glucose readings for a specific time range
    func getGlucoseReadings(from startDate: Date, to endDate: Date, limit: Int) async throws -> [HealthGlucoseReading]
    
    /// Save a glucose reading to HealthKit
    func saveGlucoseReading(_ reading: HealthGlucoseReading) async throws
    
    /// Get nutrition data from HealthKit
    func getNutritionData(from startDate: Date, to endDate: Date) async throws -> [HealthNutritionEntry]
    
    /// Save nutrition data to HealthKit
    func saveNutritionData(_ nutrition: HealthNutritionEntry) async throws
    
    /// Get workout data related to blood glucose impact
    func getWorkoutData(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutEntry]

    /// Get activity data (steps and calories) for a time range
    func getActivityData(from startDate: Date, to endDate: Date) async throws -> (steps: Double, calories: Double)

    /// Get steps for a specific time range
    func getSteps(from startDate: Date, to endDate: Date) async throws -> Double

    /// Get active calories for a specific time range
    func getActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double
}

// MARK: - Health Data Models

struct HealthGlucoseReading: Sendable {
    let id: UUID
    let value: Double
    let unit: HKUnit
    let timestamp: Date
    let device: String?
    let source: String?
    let metadata: [String: String]? // Simplified for Sendable compliance
    
    init(id: UUID = UUID(),
         value: Double,
         unit: HKUnit = HKUnit(from: "mg/dL"),
         timestamp: Date = Date(),
         device: String? = nil,
         source: String? = nil,
         metadata: [String: String]? = nil) {
        self.id = id
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.device = device
        self.source = source
        self.metadata = metadata
    }
}

struct HealthNutritionEntry: Sendable {
    let id: UUID
    let timestamp: Date
    let calories: Double?
    let carbohydrates: Double?
    let protein: Double?
    let totalFat: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let mealType: String?
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         calories: Double? = nil,
         carbohydrates: Double? = nil,
         protein: Double? = nil,
         totalFat: Double? = nil,
         fiber: Double? = nil,
         sugar: Double? = nil,
         sodium: Double? = nil,
         mealType: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.calories = calories
        self.carbohydrates = carbohydrates
        self.protein = protein
        self.totalFat = totalFat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.mealType = mealType
    }
}

struct HealthWorkoutEntry: Sendable {
    let id: UUID
    let workoutType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalEnergyBurned: Double?
    let distance: Double?
    let metadata: [String: String]? // Simplified for Sendable compliance
    
    init(id: UUID = UUID(),
         workoutType: HKWorkoutActivityType,
         startDate: Date,
         endDate: Date,
         duration: TimeInterval,
         totalEnergyBurned: Double? = nil,
         distance: Double? = nil,
         metadata: [String: String]? = nil) {
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.totalEnergyBurned = totalEnergyBurned
        self.distance = distance
        self.metadata = metadata
    }
}

// MARK: - Mock HealthKit Service

/// Mock implementation for testing and development
/// Will be replaced with actual HealthKit implementation later
actor MockHealthKitService: HealthKitServiceProtocol {
    private var isAuth = false
    private var mockGlucoseReadings: [HealthGlucoseReading] = []
    private var mockNutritionEntries: [HealthNutritionEntry] = []
    
    init() {
        // Generate some mock data
        Task {
            await generateMockData()
        }
    }
    
    func requestAuthorization() async throws -> Bool {
        // Simulate authorization delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isAuth = true
        return true
    }
    
    func isAuthorized(for type: HKQuantityType? = nil) async -> Bool {
        return isAuth
    }
    
    func getGlucoseReadings(from startDate: Date, to endDate: Date, limit: Int) async throws -> [HealthGlucoseReading] {
        // Filter mock readings by date range
        let filtered = mockGlucoseReadings.filter { reading in
            reading.timestamp >= startDate && reading.timestamp <= endDate
        }
        
        return Array(filtered.prefix(limit))
    }
    
    func saveGlucoseReading(_ reading: HealthGlucoseReading) async throws {
        mockGlucoseReadings.append(reading)
        mockGlucoseReadings.sort { $0.timestamp > $1.timestamp }
    }
    
    func getNutritionData(from startDate: Date, to endDate: Date) async throws -> [HealthNutritionEntry] {
        let filtered = mockNutritionEntries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
        
        return filtered
    }
    
    func saveNutritionData(_ nutrition: HealthNutritionEntry) async throws {
        mockNutritionEntries.append(nutrition)
        mockNutritionEntries.sort { $0.timestamp > $1.timestamp }
    }
    
    func getWorkoutData(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutEntry] {
        // Return empty array for now - can be implemented later
        return []
    }

    func getActivityData(from startDate: Date, to endDate: Date) async throws -> (steps: Double, calories: Double) {
        // Return mock activity data
        let steps = Double.random(in: 5000...15000)
        let calories = Double.random(in: 200...800)
        return (steps, calories)
    }

    func getSteps(from startDate: Date, to endDate: Date) async throws -> Double {
        return Double.random(in: 5000...15000)
    }

    func getActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        return Double.random(in: 200...800)
    }

    private func generateMockData() {
        let calendar = Calendar.current
        let now = Date()
        
        // Generate mock glucose readings for the past week
        for i in 0..<20 {
            let date = calendar.date(byAdding: .hour, value: -i * 2, to: now) ?? now
            let baseValue: Double = 100 + Double.random(in: -20...40)
            
            let reading = HealthGlucoseReading(
                value: baseValue,
                timestamp: date,
                device: "Mock CGM",
                source: "Balli Test Data"
            )
            
            mockGlucoseReadings.append(reading)
        }
        
        // Generate mock nutrition entries
        for i in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            
            let nutrition = HealthNutritionEntry(
                timestamp: date,
                calories: Double.random(in: 300...800),
                carbohydrates: Double.random(in: 30...100),
                protein: Double.random(in: 15...40),
                totalFat: Double.random(in: 10...30),
                fiber: Double.random(in: 5...15),
                mealType: ["breakfast", "lunch", "dinner", "snack"].randomElement()
            )
            
            mockNutritionEntries.append(nutrition)
        }
    }
}