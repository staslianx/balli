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
    var hasGapBefore: Bool // Indicates >15 min gap before this reading

    init(time: Date, value: Double, hasGapBefore: Bool = false) {
        self.time = time
        self.value = value
        self.hasGapBefore = hasGapBefore
    }
}
