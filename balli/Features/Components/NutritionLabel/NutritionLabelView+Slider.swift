//
//  NutritionLabelView+Slider.swift
//  balli
//
//  Logarithmic slider logic and conversions
//  Extracted from NutritionLabelView.swift
//  Swift 6 strict concurrency compliant
//

import SwiftUI

extension NutritionLabelView {

    // MARK: - Slider Configuration

    enum SliderConfig {
        static let minGrams = 5.0
        static let maxGrams = 300.0
        static let logGamma = 0.55
    }

    // MARK: - Slider Position Binding

    /// Computed binding that converts between grams and slider position (0-1)
    nonisolated var sliderPosition: Binding<Double> {
        Binding<Double>(
            get: {
                self.sliderPositionFromGrams(self.portionGrams)
            },
            set: { newPosition in
                // Update the binding value directly
                // This should trigger SwiftUI to re-render the view
                self.portionGrams = self.gramsFromSliderPosition(newPosition)
            }
        )
    }

    // MARK: - Conversion Helpers

    /// Convert grams to slider position using a tunable logarithmic curve
    nonisolated func sliderPositionFromGrams(_ grams: Double) -> Double {
        let clamped = max(SliderConfig.minGrams, min(SliderConfig.maxGrams, grams))
        let normalized = (clamped - SliderConfig.minGrams) / (SliderConfig.maxGrams - SliderConfig.minGrams)
        return pow(normalized, SliderConfig.logGamma)
    }

    /// Convert slider position back to grams using the inverse curve
    nonisolated func gramsFromSliderPosition(_ position: Double) -> Double {
        let clamped = max(0, min(1, position))
        let normalized = pow(clamped, 1 / SliderConfig.logGamma)
        let grams = SliderConfig.minGrams + normalized * (SliderConfig.maxGrams - SliderConfig.minGrams)

        if grams < 80 {
            return round(grams)
        }
        return round(grams / 5) * 5
    }
}
