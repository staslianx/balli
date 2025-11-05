//
//  GlucoseResponse.swift
//  balli
//
//  Post-meal glucose trajectory model
//  Swift 6 strict concurrency compliant
//

import Foundation

/// Complete glucose response to a meal event
/// Captures baseline, peak, and time-series data for correlation analysis
struct GlucoseResponse: Codable, Sendable {
    // MARK: - Response Metrics

    let baseline: Double // mg/dL reading before meal (or earliest reading)
    let peak: Double // Highest glucose value in response window
    let peakTime: Date // When peak occurred
    let peakMinutesFromMeal: Int // Minutes from meal to peak

    // MARK: - Time-Point Changes

    let change1h: Double? // mg/dL change at 1 hour post-meal
    let change2h: Double? // mg/dL change at 2 hours post-meal
    let change3h: Double? // mg/dL change at 3 hours post-meal

    // MARK: - Time Series Data

    let readings: [GlucosePoint] // Complete glucose trajectory

    // MARK: - Response Metrics

    let auc: Double? // Area under the curve (glucose exposure)
    let timeToBaseline: Int? // Minutes until return to baseline ±10 mg/dL

    // MARK: - Computed Properties

    /// Peak change from baseline
    var peakChange: Double {
        peak - baseline
    }

    /// Percentage increase at peak
    var peakPercentIncrease: Double {
        guard baseline > 0 else { return 0 }
        return ((peak - baseline) / baseline) * 100
    }

    /// Time in range (70-180 mg/dL) during response window
    func timeInRange(targetRange: ClosedRange<Double> = 70...180) -> Double {
        let inRangeCount = readings.filter { targetRange.contains($0.value) }.count
        let totalCount = readings.count
        guard totalCount > 0 else { return 0 }
        return (Double(inRangeCount) / Double(totalCount)) * 100
    }

    /// Time above range (>180 mg/dL)
    func timeAboveRange(threshold: Double = 180) -> Double {
        let aboveCount = readings.filter { $0.value > threshold }.count
        let totalCount = readings.count
        guard totalCount > 0 else { return 0 }
        return (Double(aboveCount) / Double(totalCount)) * 100
    }

    /// Average glucose during response window
    var averageGlucose: Double {
        guard !readings.isEmpty else { return baseline }
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }

    /// Standard deviation of glucose readings
    var glucoseVariability: Double {
        guard readings.count > 1 else { return 0 }

        let mean = averageGlucose
        let squaredDiffs = readings.map { pow($0.value - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(readings.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Glucose Point

/// Single glucose reading with time context relative to meal
struct GlucosePoint: Codable, Sendable {
    let timestamp: Date
    let value: Double // mg/dL
    let minutesFromMeal: Int // Negative = before meal, positive = after meal

    // MARK: - Time Classification

    var timeCategory: String {
        switch minutesFromMeal {
        case ..<0:
            return "pre_meal"
        case 0..<60:
            return "0-1h_post"
        case 60..<120:
            return "1-2h_post"
        case 120..<180:
            return "2-3h_post"
        default:
            return "3h+_post"
        }
    }

    var isPreMeal: Bool { minutesFromMeal < 0 }
    var isPostMeal: Bool { minutesFromMeal >= 0 }
}

// MARK: - Response Builder Helper

extension GlucoseResponse {
    /// Create response from sorted glucose readings
    /// - Parameters:
    ///   - mealTimestamp: Time of meal
    ///   - readings: Array of (timestamp, value) tuples sorted by time
    ///   - windowMinutes: Analysis window after meal (default 180 = 3 hours)
    /// - Returns: GlucoseResponse or nil if insufficient data
    static func build(
        mealTimestamp: Date,
        readings glucoseReadings: [(timestamp: Date, value: Double)],
        windowMinutes: Int = 180
    ) -> GlucoseResponse? {
        // Need at least 2 readings (baseline + peak)
        guard glucoseReadings.count >= 2 else { return nil }

        // Find baseline (reading closest to meal time, before or at meal)
        let preOrAtMealReadings = glucoseReadings.filter { $0.timestamp <= mealTimestamp }
        guard let baselineReading = preOrAtMealReadings.last else { return nil }
        let baseline = baselineReading.value

        // Filter readings within analysis window
        let windowEnd = mealTimestamp.addingTimeInterval(TimeInterval(windowMinutes * 60))
        let windowReadings = glucoseReadings.filter {
            $0.timestamp >= mealTimestamp && $0.timestamp <= windowEnd
        }

        guard !windowReadings.isEmpty else { return nil }

        // Find peak - use guard to safely unwrap instead of force unwrap
        guard let peakReading = windowReadings.max(by: { $0.value < $1.value }) else {
            // This should be impossible given the isEmpty guard above, but handle defensively
            // Return nil to indicate invalid glucose response data
            return nil
        }

        let peak = peakReading.value
        let peakTime = peakReading.timestamp
        let peakMinutes = Int(peakTime.timeIntervalSince(mealTimestamp) / 60)

        // Calculate time-point changes
        let change1h = changeAt(minutes: 60, from: mealTimestamp, in: windowReadings, baseline: baseline)
        let change2h = changeAt(minutes: 120, from: mealTimestamp, in: windowReadings, baseline: baseline)
        let change3h = changeAt(minutes: 180, from: mealTimestamp, in: windowReadings, baseline: baseline)

        // Build glucose points
        let points = windowReadings.map { reading in
            let minutesFrom = Int(reading.timestamp.timeIntervalSince(mealTimestamp) / 60)
            return GlucosePoint(timestamp: reading.timestamp, value: reading.value, minutesFromMeal: minutesFrom)
        }

        // Calculate AUC (trapezoidal rule)
        let auc = calculateAUC(points: points, baseline: baseline)

        // Find time to return to baseline (within ±10 mg/dL)
        let timeToBaseline = findTimeToBaseline(points: points, baseline: baseline, tolerance: 10.0)

        return GlucoseResponse(
            baseline: baseline,
            peak: peak,
            peakTime: peakTime,
            peakMinutesFromMeal: peakMinutes,
            change1h: change1h,
            change2h: change2h,
            change3h: change3h,
            readings: points,
            auc: auc,
            timeToBaseline: timeToBaseline
        )
    }

    /// Find glucose change at specific time point
    private static func changeAt(
        minutes: Int,
        from mealTime: Date,
        in readings: [(timestamp: Date, value: Double)],
        baseline: Double
    ) -> Double? {
        let targetTime = mealTime.addingTimeInterval(TimeInterval(minutes * 60))

        // Find closest reading within ±5 minutes
        let tolerance: TimeInterval = 5 * 60
        let nearbyReadings = readings.filter {
            abs($0.timestamp.timeIntervalSince(targetTime)) <= tolerance
        }

        guard let closest = nearbyReadings.min(by: {
            abs($0.timestamp.timeIntervalSince(targetTime)) < abs($1.timestamp.timeIntervalSince(targetTime))
        }) else {
            return nil
        }

        return closest.value - baseline
    }

    /// Calculate area under curve using trapezoidal rule
    private static func calculateAUC(points: [GlucosePoint], baseline: Double) -> Double? {
        guard points.count >= 2 else { return nil }

        var auc: Double = 0.0

        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]

            // Height = average glucose above baseline
            let h1 = max(0, p1.value - baseline)
            let h2 = max(0, p2.value - baseline)
            let avgHeight = (h1 + h2) / 2.0

            // Width = time difference in hours
            let widthMinutes = Double(p2.minutesFromMeal - p1.minutesFromMeal)
            let widthHours = widthMinutes / 60.0

            auc += avgHeight * widthHours
        }

        return auc
    }

    /// Find time when glucose returns to baseline
    private static func findTimeToBaseline(points: [GlucosePoint], baseline: Double, tolerance: Double) -> Int? {
        // Find peak index
        guard let peakIndex = points.firstIndex(where: { $0.value == points.max(by: { $0.value < $1.value })?.value }) else {
            return nil
        }

        // Look for return to baseline after peak
        let postPeakPoints = points.suffix(from: peakIndex + 1)

        for point in postPeakPoints {
            if abs(point.value - baseline) <= tolerance {
                return point.minutesFromMeal
            }
        }

        return nil // Never returned to baseline within window
    }
}
