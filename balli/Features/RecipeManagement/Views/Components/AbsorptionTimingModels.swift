//
//  AbsorptionTimingModels.swift
//  balli
//
//  Data models for absorption timing visualization
//

import Foundation

/// Represents a single point on an absorption curve
struct TimePoint: Identifiable, Sendable {
    let id = UUID()
    let timeHours: Double     // 0.0 to 6.0 hours
    let intensity: Double     // 0.0 to 1.0 (normalized)

    init(timeHours: Double, intensity: Double) {
        self.timeHours = timeHours
        self.intensity = intensity
    }
}

/// Complete absorption profile containing insulin and meal curves
struct AbsorptionProfile: Sendable {
    let insulinCurve: [TimePoint]
    let mealCurve: [TimePoint]
    let peakDifferenceHours: Double
    let insulinPeakTime: Double
    let mealPeakTime: Double

    init(
        insulinCurve: [TimePoint],
        mealCurve: [TimePoint],
        peakDifferenceHours: Double,
        insulinPeakTime: Double,
        mealPeakTime: Double
    ) {
        self.insulinCurve = insulinCurve
        self.mealCurve = mealCurve
        self.peakDifferenceHours = peakDifferenceHours
        self.insulinPeakTime = insulinPeakTime
        self.mealPeakTime = mealPeakTime
    }
}
