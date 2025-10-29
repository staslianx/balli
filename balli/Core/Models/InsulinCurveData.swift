//
//  InsulinCurveData.swift
//  balli
//
//  Data structures for insulin and glucose absorption curves
//  Used for insulin-glucose mismatch warning system
//

import Foundation

/// Represents a point on the insulin action curve
struct InsulinCurvePoint: Identifiable, Sendable {
    let id = UUID()
    let timeMinutes: Int
    let intensity: Double  // 0.0 to 1.0 (normalized)

    init(timeMinutes: Int, intensity: Double) {
        self.timeMinutes = timeMinutes
        self.intensity = intensity
    }
}

/// Represents a point on the glucose absorption curve
struct GlucoseCurvePoint: Identifiable, Sendable {
    let id = UUID()
    let timeMinutes: Int
    let intensity: Double  // 0.0 to 1.0 (normalized)

    init(timeMinutes: Int, intensity: Double) {
        self.timeMinutes = timeMinutes
        self.intensity = intensity
    }
}

/// Static insulin curve data for different insulin types
enum InsulinCurveData {
    /// NovoRapid (insulin aspart) pharmacokinetic profile
    /// Onset: 10-15 minutes, Peak: 75 minutes, Duration: 4-5 hours (240-300 minutes)
    static let novorapidCurve: [InsulinCurvePoint] = [
        InsulinCurvePoint(timeMinutes: 0, intensity: 0.0),      // Injection
        InsulinCurvePoint(timeMinutes: 15, intensity: 0.2),     // Onset
        InsulinCurvePoint(timeMinutes: 30, intensity: 0.5),     // Rising
        InsulinCurvePoint(timeMinutes: 60, intensity: 0.85),    // Near peak
        InsulinCurvePoint(timeMinutes: 75, intensity: 1.0),     // PEAK
        InsulinCurvePoint(timeMinutes: 90, intensity: 0.9),     // Declining
        InsulinCurvePoint(timeMinutes: 120, intensity: 0.6),    // Half-life
        InsulinCurvePoint(timeMinutes: 180, intensity: 0.3),    // Tail
        InsulinCurvePoint(timeMinutes: 240, intensity: 0.1),    // End
        InsulinCurvePoint(timeMinutes: 300, intensity: 0.0)     // Complete
    ]

    /// Peak time for NovoRapid in minutes
    static let novorapidPeakTime: Int = 75

    // Future enhancement: Support other insulin types
    // static let humalogCurve: [InsulinCurvePoint] = [ ... ]  // Peak: 60 min
    // static let fiaspCurve: [InsulinCurvePoint] = [ ... ]    // Peak: 45 min (faster-acting)
    // static let apidraCurve: [InsulinCurvePoint] = [ ... ]   // Peak: 60 min
}
