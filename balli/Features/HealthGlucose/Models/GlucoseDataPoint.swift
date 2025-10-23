//
//  GlucoseDataPoint.swift
//  balli
//
//  Glucose reading data point for chart visualization
//

import Foundation

/// Represents a single glucose reading for chart display
struct GlucoseDataPoint: Identifiable, Sendable {
    let id = UUID()
    let time: Date
    let value: Double // mg/dL

    init(time: Date, value: Double) {
        self.time = time
        self.value = value
    }
}
